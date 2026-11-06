// Savaş alanı: public/models/envoirement.glb (Meshy). Taş döşeli bir avlu ve ortasında gotik bir yapı.
// Model tek parça (zemin ve yapı aynı şekilde), kemiksiz ve hareketsiz. Yüklenince:
//   - haritayı kaplayacak şekilde ölçeklenir, zemini y = 0'a oturtulur
//   - yapının olduğu kareler ızgarada engel olur
//   - zemin ve yapı iki ayrı malzemeye ayrılır, ki karakter yapının arkasına geçince
//     sadece yapı yarı saydam olsun (Diablo'daki gibi), zemin olduğu gibi kalsın

import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import type { Grid } from './Grid';

const ENVIRONMENT_URL = '/models/envoirement.glb';
// Bir karedeki en yüksek nokta zeminden bu kadar (metre) yüksekse o kare engel sayılır.
// Zemindeki küçük taşlar, çatlaklar bunun altında kalır; duvarlar ve yapı üstünde.
const OBSTACLE_HEIGHT = 0.5;
// Bir üçgenin bir köşesi zeminden bu kadar yüksekse o üçgen "yapı"ya ait sayılır (saydamlaşır)
const BUILDING_HEIGHT = 0.3;
// Kamera hangi açıyla aşağı bakıyor: her 1 m yatay uzaklıkta görüş çizgisi bu kadar yükselir.
// Kamera (20, 20, 20) uzakta: yatayda √800 ≈ 28.3, dikeyde 20 → 20 / 28.3 ≈ 0.707.
const SIGHT_SLOPE = 20 / Math.hypot(20, 20);
// Kameraya doğru yatay yön (kamera +x +z tarafında): (1, 1) / √2
const TOWARD_CAMERA = 1 / Math.SQRT2;
// Saydamlık kontrolünde karakterin hangi yüksekliğine bakıldığı (metre; gövdenin ortası)
const BODY_HEIGHT = 1;

export class Environment {
  readonly object: THREE.Object3D;
  private readonly grid: Grid;
  private readonly heights: Float32Array; // her karedeki en yüksek nokta, zemine göre (metre)
  private readonly buildingMaterials: THREE.MeshStandardMaterial[];

  private constructor(object: THREE.Object3D, grid: Grid, heights: Float32Array, buildingMaterials: THREE.MeshStandardMaterial[]) {
    this.object = object;
    this.grid = grid;
    this.heights = heights;
    this.buildingMaterials = buildingMaterials;
  }

  /** Ortamı yükle ve hazırla (ızgaradaki engeller dahil) */
  static async load(grid: Grid): Promise<Environment> {
    const gltf = await new GLTFLoader().loadAsync(ENVIRONMENT_URL);
    const model = gltf.scene;

    // Zeminde kapladığı en uzun kenarı ızgaranın genişliğine ölçekle, ortasını (0, 0)'a koy
    const box = new THREE.Box3().setFromObject(model);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());
    const scale = (grid.cols * grid.cellSize) / Math.max(size.x, size.z);
    model.scale.setScalar(scale);
    model.position.set(-center.x * scale, 0, -center.z * scale);

    // Yükseklik haritası: her karedeki en yüksek nokta. Zemin yüksekliği = bu değerlerin ortancası
    // (karelerin çoğu düz zemin olduğu için ortadaki değer zemindir). Zemini y = 0'a indir.
    const heights = cellHeights(model, grid);
    const sorted = Array.from(heights).filter((h) => h > -Infinity).sort((a, b) => a - b);
    const floor = sorted[Math.floor(sorted.length / 2)] ?? 0;
    model.position.y -= floor;
    for (let i = 0; i < heights.length; i++) heights[i] -= floor;

    // Zeminden yeterince yüksek kareler engel: yapının duvarları, sütunlar
    let blocked = 0;
    for (let row = 0; row < grid.rows; row++) {
      for (let col = 0; col < grid.cols; col++) {
        if (heights[row * grid.cols + col] > OBSTACLE_HEIGHT) {
          grid.block(col, row);
          blocked++;
        }
      }
    }

    model.updateMatrixWorld(true);
    const buildingMaterials: THREE.MeshStandardMaterial[] = [];
    model.traverse((child) => {
      if (!(child instanceof THREE.Mesh)) return;
      child.castShadow = true;
      child.receiveShadow = true;
      const material = child.material as THREE.MeshStandardMaterial;
      // Model "metal" işaretli; yansıtacak ortam olmadığı için simsiyah görünürdü. Taş metal değil.
      material.metalness = 0;
      const building = splitBuilding(child, material);
      if (building) buildingMaterials.push(building);
    });

    console.log(`Ortam yüklendi: ${blocked} kare engel`);
    return new Environment(model, grid, heights, buildingMaterials);
  }

  /**
   * Yapı, kameradan bakınca bu noktadaki birini kapatıyor mu? Noktadan kameraya doğru zeminde
   * adım adım ilerle; bir karedeki yapı, oradan geçen görüş çizgisinden yüksekse kapatıyordur.
   */
  hides(point: THREE.Vector3): boolean {
    for (let distance = 0.5; distance < 16; distance += 0.5) {
      const x = point.x + distance * TOWARD_CAMERA;
      const z = point.z + distance * TOWARD_CAMERA;
      const cell = this.grid.worldToCell(x, z);
      if (!this.grid.inBounds(cell.col, cell.row)) return false; // haritanın dışına çıktık
      const sightLine = BODY_HEIGHT + distance * SIGHT_SLOPE; // görüş çizgisinin o noktadaki yüksekliği
      if (this.heights[cell.row * this.grid.cols + cell.col] > sightLine) return true;
    }
    return false;
  }

  /** Yapının saydamlığı (1 = tam görünür, 0 = görünmez) */
  setBuildingOpacity(opacity: number) {
    for (const material of this.buildingMaterials) material.opacity = opacity;
  }
}

// Mesh'in üçgenlerini ikiye ayır: zemin (ilk grup, eski malzeme) ve yapı (ikinci grup, kopya malzeme).
// Şekil aynı kalır, sadece üçgenlerin sırası değişir ve iki "grup"a bölünür; Three.js her grubu kendi
// malzemesiyle çizer. Yapının malzemesini döndürür (yapı üçgeni yoksa null).
function splitBuilding(mesh: THREE.Mesh, material: THREE.MeshStandardMaterial): THREE.MeshStandardMaterial | null {
  const geometry = mesh.geometry;
  const index = geometry.index;
  if (!index) return null;
  const position = geometry.attributes.position;
  const point = new THREE.Vector3();

  // Her köşe noktası zeminden (y = 0) yüksek mi?
  const tall = new Uint8Array(position.count);
  for (let i = 0; i < position.count; i++) {
    point.fromBufferAttribute(position, i).applyMatrix4(mesh.matrixWorld);
    tall[i] = point.y > BUILDING_HEIGHT ? 1 : 0;
  }

  const floorIndices: number[] = [];
  const buildingIndices: number[] = [];
  for (let i = 0; i < index.count; i += 3) {
    const a = index.getX(i);
    const b = index.getX(i + 1);
    const c = index.getX(i + 2);
    (tall[a] || tall[b] || tall[c] ? buildingIndices : floorIndices).push(a, b, c);
  }
  if (buildingIndices.length === 0) return null;

  geometry.setIndex([...floorIndices, ...buildingIndices]);
  geometry.clearGroups();
  geometry.addGroup(0, floorIndices.length, 0);
  geometry.addGroup(floorIndices.length, buildingIndices.length, 1);

  // Yapı malzemesi baştan "saydam olabilir" işaretli (transparent). Sonradan açıp kapamak
  // shader'ın yeniden derlenmesine yol açar ve oyunu bir an takıltır; opaklık 1 iken zaten tam görünür.
  const building = material.clone();
  building.transparent = true;
  mesh.material = [material, building];
  return building;
}

// Her ızgara karesine düşen model noktalarının en yüksek y değeri (dünya koordinatında).
// Hiç nokta düşmeyen karede -Infinity kalır.
function cellHeights(model: THREE.Object3D, grid: Grid): Float32Array {
  const heights = new Float32Array(grid.cols * grid.rows).fill(-Infinity);
  const point = new THREE.Vector3();
  model.updateMatrixWorld(true);
  model.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    const position = child.geometry.attributes.position;
    for (let i = 0; i < position.count; i++) {
      point.fromBufferAttribute(position, i).applyMatrix4(child.matrixWorld);
      const cell = grid.worldToCell(point.x, point.z);
      if (!grid.inBounds(cell.col, cell.row)) continue;
      const index = cell.row * grid.cols + cell.col;
      if (point.y > heights[index]) heights[index] = point.y;
    }
  });
  return heights;
}
