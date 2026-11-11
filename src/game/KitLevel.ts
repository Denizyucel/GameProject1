// Parça setinden kurulan bölge. Her parça (duvar, sütun, raf...) public/models/kit içinde ayrı bir
// .glb dosyası; bölgenin planı (src/game/levels/) hangi parçanın nereye konacağını söyler.
// Bir parça bir kez yüklenir, sonra kopyalanarak istenen kadar yere konur (kopyalar aynı şekli ve
// dokuyu paylaşır, bellek artmaz). Yüklenince:
//   - parça, plandaki genişliğine ölçeklenir ve zemine oturtulur
//   - kapladığı kareler ızgarada engel olur
//   - karakter bir parçanın arkasında kalınca sadece o parça yarı saydam olur

import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import type { Grid } from './Grid';
import { planToWorld, type LevelPlan } from './levels/yanikKutuphane';

const KIT_URL = '/models/kit/';

// Zemin dokuları (ambientCG). Bir doku karesi küçük bir görseldir; zemine yan yana dizilir (döşenir).
//   tile: bir doku karesinin dünyada kapladığı alan (metre; en x boy)
//   tint: dokunun rengiyle çarpılan renk; dokuyu koyulaştırıp sahnenin kül havasına uydurur
interface FloorStyle {
  url: string;
  tile: [number, number];
  tint: number;
}
const OUTSIDE_FLOOR: FloorStyle = { url: '/models/floor/disarisi/Ground048_1K-JPG', tile: [3, 3], tint: 0x8d8884 };
const HALL_FLOOR: FloorStyle = { url: '/models/floor/salonun-ici/Tiles130_1K-JPG', tile: [6, 3], tint: 0x74777f };
// İç zemin dış zeminin bu kadar (metre) üstünde durur, ki ikisi aynı yükseklikte çakışıp titremesin
const HALL_FLOOR_LIFT = 0.02;

// Parçanın ızgarayı nasıl engellediği:
//   box   = kapladığı dikdörtgenin tamamı
//   arch  = sadece iki ucu (ortası açık: kapı)
//   trunk = sadece ortası (ağacın gövdesi; dalların altından yürünür)
//   none  = engel değil (üstünden yürünür)
type Blocking = 'box' | 'arch' | 'trunk' | 'none';

// Her parçanın yerde kapladığı en uzun kenar (metre) ve engelleme biçimi.
// Modeller farklı boyutlarda geldiği için boyu buradan ayarlanır: en uzun yatay kenarı bu değere ölçeklenir.
// model: parça başka bir dosyanın şeklini kullanıyorsa o dosyanın adı.
// stretch: boyu kaç kat uzatılacağı (sadece yukarı doğru; genişlik aynı kalır).
const PARTS: Record<string, { size: number; blocking: Blocking; model?: string; stretch?: number }> = {
  'yikik-duvar': { size: 4, blocking: 'box' },
  'yuksek-duvar': { size: 4, blocking: 'box' },
  'duvar-rafi': { size: 3, blocking: 'box' },
  'cati-kemeri': { size: 4, blocking: 'arch' },
  'kemer-kapi': { size: 4, blocking: 'arch' },
  sutun: { size: 0.9, blocking: 'box' },
  'kirik-sutun': { size: 0.9, blocking: 'box' },
  'yanmis-raf': { size: 2, blocking: 'box' },
  'muhur-kaidesi': { size: 1.5, blocking: 'box' },
  'kitap-yigini': { size: 0.7, blocking: 'none' },
  moloz: { size: 2, blocking: 'box' },
  'kuru-agac': { size: 3, blocking: 'trunk' },
};

// Engel dikdörtgeni her kenardan bu kadar (metre) daraltılır, ki kare sınırına hafifçe taşan
// bir duvar komşu kareyi de kapatıp geçitleri daraltmasın
const BLOCK_INSET = 0.2;
// Kemerin iki ucundaki ayakların, genişliğe oranı (kalan orta kısım kapı açıklığı)
const ARCH_PILLAR = 0.2;
// Ağaç gövdesinin yarı genişliği (metre)
const TRUNK_HALF = 0.3;
// Kamera hangi açıyla aşağı bakıyor: her 1 m yatay uzaklıkta görüş çizgisi bu kadar yükselir
// (kamera (20, 20, 20) uzakta: yatayda √800, dikeyde 20)
const SIGHT_SLOPE = 20 / Math.hypot(20, 20);
// Kameraya doğru yatay yön (kamera +x +z tarafında): (1, 1) / √2
const TOWARD_CAMERA = 1 / Math.SQRT2;
// Saydamlık kontrolünde karakterin hangi yüksekliğine bakıldığı (metre; gövdenin ortası)
const BODY_HEIGHT = 1;
// Karakteri kapatan parçanın saydamlığı (0 = görünmez, 1 = tam) ve saydamlaşma/geri gelme hızı
const HIDDEN_OPACITY = 0.3;
const FADE_SPEED = 8;

// Sahneye konmuş bir parça: kendi malzemeleri (ki tek başına saydamlaşabilsin) ve saydamlığı
interface PlacedPiece {
  materials: THREE.Material[];
  opacity: number;
  hiding: boolean; // bu karede karakteri kapatıyor mu
}

// Yüklenmiş bir parça: kopyalanacak model, ölçeği ve ölçeklenmiş boyutları
interface Template {
  model: THREE.Object3D;
  scale: number;
  stretch: number; // boyun kaç kat uzatıldığı
  box: THREE.Box3; // ölçeklenmemiş sınır kutusu
}

export class KitLevel {
  readonly object = new THREE.Group();
  private readonly grid: Grid;
  private readonly heights: Float32Array; // her karedeki parçanın yüksekliği (metre; boşsa 0)
  private readonly owners: Int16Array; // her karedeki parçanın pieces içindeki sırası (boşsa -1)
  private readonly pieces: PlacedPiece[] = [];

  private constructor(grid: Grid) {
    this.grid = grid;
    this.heights = new Float32Array(grid.cols * grid.rows);
    this.owners = new Int16Array(grid.cols * grid.rows).fill(-1);
  }

  /** Plandaki parçaları yükle, yerleştir ve ızgaradaki engelleri kur */
  static async load(plan: LevelPlan, grid: Grid): Promise<KitLevel> {
    const level = new KitLevel(grid);

    // Planda geçen her parçayı bir kez indir (hepsi aynı anda). Bulunamayan parça atlanır.
    const names = [...new Set(plan.pieces.map(([part]) => part))];
    const templates = new Map<string, Template>();
    await Promise.all(
      names.map(async (name) => {
        try {
          templates.set(name, await level.loadTemplate(name));
        } catch (error) {
          console.warn(`Kit parçası yüklenemedi: ${name}`, error);
        }
      }),
    );

    // Zemin: bütün haritaya toprak, salonun içine taş döşeme
    const mapSize = grid.cols * grid.cellSize;
    level.object.add(createFloor(OUTSIDE_FLOOR, mapSize, mapSize, 0, 0, 0));
    const [left, top, right, bottom] = plan.hall;
    const from = planToWorld(plan, left, top);
    const to = planToWorld(plan, right, bottom);
    level.object.add(
      createFloor(HALL_FLOOR, to.x - from.x, to.z - from.z, (from.x + to.x) / 2, (from.z + to.z) / 2, HALL_FLOOR_LIFT),
    );

    let placed = 0;
    for (const [part, px, py, degrees = 0] of plan.pieces) {
      const template = templates.get(part);
      if (!template) continue;
      const { x, z } = planToWorld(plan, px, py);
      level.place(part, template, x, z, degrees);
      placed++;
    }
    console.log(`Bölge kuruldu: ${placed} / ${plan.pieces.length} parça`);
    return level;
  }

  /**
   * Kameradan bakınca bu noktadaki karakteri kapatan parçaları yumuşakça saydamlaştır,
   * artık kapatmayanları geri getir. Her karede çağrılır.
   */
  updateFade(point: THREE.Vector3, delta: number) {
    for (const piece of this.pieces) piece.hiding = false;
    // Noktadan kameraya doğru zeminde adım adım ilerle; bir karedeki parça, oradan geçen
    // görüş çizgisinden yüksekse karakteri kapatıyordur
    for (let distance = 0.5; distance < 16; distance += 0.5) {
      const cell = this.grid.worldToCell(point.x + distance * TOWARD_CAMERA, point.z + distance * TOWARD_CAMERA);
      if (!this.grid.inBounds(cell.col, cell.row)) break; // haritanın dışına çıktık
      const index = cell.row * this.grid.cols + cell.col;
      const sightLine = BODY_HEIGHT + distance * SIGHT_SLOPE;
      if (this.heights[index] > sightLine) this.pieces[this.owners[index]].hiding = true;
    }
    const step = 1 - Math.exp(-FADE_SPEED * delta);
    for (const piece of this.pieces) {
      const target = piece.hiding ? HIDDEN_OPACITY : 1;
      if (Math.abs(piece.opacity - target) < 0.001) continue;
      piece.opacity = THREE.MathUtils.lerp(piece.opacity, target, step);
      for (const material of piece.materials) material.opacity = piece.opacity;
    }
  }

  private async loadTemplate(name: string): Promise<Template> {
    const gltf = await new GLTFLoader().loadAsync(`${KIT_URL}${PARTS[name]?.model ?? name}.glb`);
    const model = gltf.scene;
    const box = new THREE.Box3().setFromObject(model);
    const size = box.getSize(new THREE.Vector3());
    const scale = (PARTS[name]?.size ?? 1) / Math.max(size.x, size.z);

    model.traverse((child) => {
      if (!(child instanceof THREE.Mesh)) return;
      child.castShadow = true;
      child.receiveShadow = true;
      const material = child.material as THREE.MeshStandardMaterial;
      // Sahnede yansıtacak ortam olmadığı için metal yüzey simsiyah görünür; taş ve odun metal değil
      material.metalness = 0;
      // Baştan "saydam olabilir" işaretli: sonradan açıp kapamak shader'ı yeniden derletip takıltır
      material.transparent = true;
    });
    return { model, scale, stretch: PARTS[name]?.stretch ?? 1, box };
  }

  // Parçanın bir kopyasını (x, z) noktasına koy. degrees: plandaki saat yönünde dönüş.
  private place(part: string, template: Template, x: number, z: number, degrees: number) {
    const { model, scale, stretch, box } = template;
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3()).multiplyScalar(scale);
    size.y *= stretch;

    // Kopya, bir tutucu grubun içinde: kopya kendi ortasına ve zemine hizalanır,
    // tutucu ise haritadaki yerine konup döndürülür
    // Malzemeler de kopyalanır (dokular ortak kalır), ki bu parça ötekilerden bağımsız saydamlaşabilsin.
    const copy = model.clone();
    const materials: THREE.Material[] = [];
    copy.traverse((child) => {
      if (!(child instanceof THREE.Mesh)) return;
      child.material = (child.material as THREE.Material).clone();
      materials.push(child.material);
    });
    const owner = this.pieces.length;
    this.pieces.push({ materials, opacity: 1, hiding: false });
    copy.scale.set(scale, scale * stretch, scale);
    copy.position.set(-center.x * scale, -box.min.y * scale * stretch, -center.z * scale);
    const holder = new THREE.Group();
    holder.add(copy);
    holder.position.set(x, 0, z);
    // Plan yukarıdan bakıştır ve saat yönünde döner; Three.js'te y ekseninde artı yön tersidir
    const angle = -THREE.MathUtils.degToRad(degrees);
    holder.rotation.y = angle;
    this.object.add(holder);

    // Izgara: parçanın yerde kapladığı alan (parçanın kendi ekseninde yarı genişlik ve yarı derinlik)
    const halfWidth = size.x / 2;
    const halfDepth = size.z / 2;
    const blocking = PARTS[part]?.blocking ?? 'box';
    if (blocking === 'box') {
      this.mark(owner, x, z, angle, 0, halfWidth, halfDepth, size.y);
    } else if (blocking === 'arch') {
      const pillar = halfWidth * ARCH_PILLAR; // bir ayağın yarı genişliği
      this.mark(owner, x, z, angle, -(halfWidth - pillar), pillar, halfDepth, size.y);
      this.mark(owner, x, z, angle, halfWidth - pillar, pillar, halfDepth, size.y);
    } else if (blocking === 'trunk') {
      this.mark(owner, x, z, angle, 0, TRUNK_HALF + BLOCK_INSET, TRUNK_HALF + BLOCK_INSET, size.y);
    }
  }

  // Dönmüş bir dikdörtgenin kapladığı kareleri engelli yap ve yüksekliğini kaydet.
  // offset: dikdörtgenin, parçanın ortasından kendi genişlik ekseni boyunca kayması.
  private mark(owner: number, x: number, z: number, angle: number, offset: number, halfWidth: number, halfDepth: number, height: number) {
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);
    const centerX = x + offset * cos;
    const centerZ = z - offset * sin;
    // Dönmüş dikdörtgeni saran, eksenlere paralel dikdörtgen (biraz daraltılmış)
    const extentX = Math.max(0.05, Math.abs(cos) * halfWidth + Math.abs(sin) * halfDepth - BLOCK_INSET);
    const extentZ = Math.max(0.05, Math.abs(sin) * halfWidth + Math.abs(cos) * halfDepth - BLOCK_INSET);
    const from = this.grid.worldToCell(centerX - extentX, centerZ - extentZ);
    const to = this.grid.worldToCell(centerX + extentX, centerZ + extentZ);
    for (let row = from.row; row <= to.row; row++) {
      for (let col = from.col; col <= to.col; col++) {
        if (!this.grid.inBounds(col, row)) continue;
        this.grid.block(col, row);
        const index = row * this.grid.cols + col;
        // Aynı kareye iki parça düşerse yüksek olan kazanır (karakteri kapatan odur)
        if (height > this.heights[index]) {
          this.heights[index] = height;
          this.owners[index] = owner;
        }
      }
    }
  }
}

// Dokulu, yatay bir zemin parçası: ortası (x, z), boyutu width x depth (metre).
// Dokular arka planda yüklenir; gelene kadar zemin düz renk görünür.
function createFloor(style: FloorStyle, width: number, depth: number, x: number, z: number, y: number): THREE.Mesh {
  const loader = new THREE.TextureLoader();
  const load = (suffix: string, isColor = false) => {
    const texture = loader.load(`${style.url}_${suffix}.jpg`);
    // Doku kenarına gelince baştan başlasın (döşeme), zemin boyunca kaç kez tekrar edeceği
    texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
    texture.repeat.set(width / style.tile[0], depth / style.tile[1]);
    texture.anisotropy = 8; // eğik bakışta dokunun bulanmasını azaltır
    if (isColor) texture.colorSpace = THREE.SRGBColorSpace;
    return texture;
  };
  const material = new THREE.MeshStandardMaterial({
    color: style.tint,
    map: load('Color', true),
    normalMap: load('NormalGL'), // yüzeydeki girinti çıkıntı hissi (şekli değiştirmeden ışığı kandırır)
    roughnessMap: load('Roughness'), // neresi mat, neresi parlak
  });
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(width, depth), material);
  floor.rotation.x = -Math.PI / 2; // dik duran düzlemi yere yatır
  floor.position.set(x, y, z);
  floor.receiveShadow = true;
  return floor;
}
