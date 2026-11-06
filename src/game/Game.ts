import * as THREE from 'three';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { Grid } from './Grid';
import { findPath } from './findPath';

// Kameranın dikeyde kaç dünya birimi gördüğü. Küçültürsen yakınlaşır.
const VIEW_HEIGHT = 18;

// Karakterin yürüme hızı: saniyede kaç dünya birimi (≈ metre).
// Yürüme animasyonu bu hıza göre hızlandırılır; çok artırırsan bacaklar koşar gibi döner.
const MOVE_SPEED = 3;

// Kameranın karaktere göre konumu. Üç eksende eşit = izometrik açı.
// Kamera hep bu kadar ötede durur; sadece kayar, hiç dönmez.
const CAMERA_OFFSET = new THREE.Vector3(20, 20, 20);

// Kameranın karaktere ne kadar sıkı yapıştığı. Büyütürsen daha hızlı yetişir,
// küçültürsen daha yumuşak ve gecikmeli gelir.
const CAMERA_FOLLOW = 5;

// Zoom sınırları (1 = normal; büyüdükçe yakınlaşır) ve tekerleğin hassasiyeti
const MIN_ZOOM = 0.6;
const MAX_ZOOM = 3;
const ZOOM_SENSITIVITY = 0.0015;
// Zoom'un hedef değere ne kadar hızlı yumuşakça ulaştığı
const ZOOM_SMOOTH = 12;

// Klavye ile yürüme: tuş → dünyadaki yön (x, z). Kamera izometrik olduğu için yönler
// ekrana göre: ekranda "yukarı" dünyada (-x, -z) yönüne, "sağ" (+x, -z) yönüne denk gelir.
// event.code klavyedeki fiziksel yeri verir; Türkçe klavyede de W-A-S-D aynı yerdedir.
const KEY_DIRECTIONS: Record<string, [number, number]> = {
  KeyW: [-1, -1], ArrowUp: [-1, -1],
  KeyS: [1, 1], ArrowDown: [1, 1],
  KeyA: [-1, 1], ArrowLeft: [-1, 1],
  KeyD: [1, -1], ArrowRight: [1, -1],
};

// Mixamo'dan indirilen karakter (public/models içinde) ve oyundaki boyu (≈ metre)
const CHARACTER_URL = '/models/nightshade.fbx';
const CHARACTER_HEIGHT = 2;

// Meshy'den indirilen kılıç ve oyundaki boyu (uçtan kabzaya, metre)
const SWORD_URL = '/models/sword.glb';
const SWORD_LENGTH = 1.1;
// Bu modelde bıçak -y yönüne, kabza +y yönüne bakıyor (model ölçülerek bulundu).
// Elin tuttuğu yer: alttan (bıçak ucundan) üste doğru uzunluğun %89'u, kabzanın ortası.
const SWORD_GRIP = 0.89;
// Kılıcın ne kadar parlak yansıtacağı (0 = simsiyah metal, 1 = tam yansıma)
const SWORD_SHINE = 0.8;

// Mixamo animasyonları (karakterin iskeletiyle aynı kemik isimlerini kullanırlar)
type AnimationName = 'idle' | 'walk' | 'attack';
const ANIMATION_URLS: Record<AnimationName, string> = {
  idle: '/models/idle.fbx',
  walk: '/models/walk.fbx',
  attack: '/models/attack.fbx',
};
// Yürüme animasyonunun kendi hızı: ayak yerdeyken geriye kayma hızı (Mixamo birimi, cm/sn).
// Animasyon ölçülerek bulundu. Yürüme animasyonu MOVE_SPEED'e uysun diye buna göre hızlandırılır,
// böylece ayaklar zeminde kaymaz.
const WALK_CLIP_SPEED = 219;
// Vuruş animasyonu: kaç kat hızlı oynatılacağı ve darbenin animasyonun hangi anında (0..1) indiği.
// Elin en hızlı aşağı indiği an ölçüldü: 1.73 sn'lik animasyonun 0.78. saniyesi ≈ %45.
const ATTACK_TIME_SCALE = 1.3;
const ATTACK_HIT_MOMENT = 0.45;
// İki animasyon arasında yumuşak geçiş süresi (saniye)
const ANIMATION_FADE = 0.2;

// Kapsülün yarıçapı. Engeller bu kadar şişirilir ki kapsülün kenarı taşa sürtmesin.
const PLAYER_RADIUS = 0.4;

// Zemin boyutu ve ızgara karesi (dünya birimi)
const GROUND_SIZE = 30;
const CELL_SIZE = 1;

// true iken engelli kareler kırmızı, bulunan yol yeşil çizgi olarak görünür
const SHOW_DEBUG = true;
// Debug karolarının ortak şekli (yere yatırılmış kare) ve malzemesi
const DEBUG_TILE_GEOMETRY = new THREE.PlaneGeometry(CELL_SIZE * 0.9, CELL_SIZE * 0.9).rotateX(-Math.PI / 2);
const DEBUG_TILE_MATERIAL = new THREE.MeshBasicMaterial({ color: 0xff4d6d, transparent: true, opacity: 0.35 });

// Saldırı: karakter merkezi ile taş merkezi arasında en fazla bu mesafe varken vurabilir
const ATTACK_RANGE = 2;
// Bir savurmanın toplam süresi (saniye) ve darbenin savurmanın hangi anında (0..1) indiği
const SWING_DURATION = 0.45;
const HIT_MOMENT = 0.55;
// Tırpanın açıları (radyan): duruş, geriye kaldırma, öne indirme
const WEAPON_REST = 0.25;
const WEAPON_WINDUP = -0.9;
const WEAPON_STRIKE = 1.7;
// Vurulan taşın sarsılıp parladığı süre (saniye)
const HIT_FEEDBACK = 0.3;
// Bir taşın canı: kaç vuruşta kırıldığı
const GRAVE_HEALTH = 3;
// Kırılan taşın toprağa gömülme süresi (saniye)
const BREAK_DURATION = 0.5;

// Sahnedeki bir mezar taşı ve vuruş tepkisi için gereken bilgiler
interface Grave {
  mesh: THREE.Mesh;
  material: THREE.MeshStandardMaterial; // her taşın kendi malzemesi, ki sadece vurulan parlasın
  basePosition: THREE.Vector3; // sarsıntı bitince döneceği yer
  hitDirection: THREE.Vector3; // darbenin geldiği yön; taş o yöne sarsılır
  hitTime: number | null; // son darbenin zamanı (saniye)
  hits: number; // toplam kaç kez vuruldu
  footprint: THREE.Box3; // zemindeki izi (kapsül payı dahil); ızgarada engel olarak kullanılır
  breakTime: number | null; // kırılmaya başladığı zaman; null ise sağlam
}

export class Game {
  private readonly container: HTMLElement;
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera: THREE.OrthographicCamera;
  private readonly player: THREE.Group;
  // Model yüklenene kadar görünen mor kapsül (yer tutucu)
  private readonly placeholder = new THREE.Mesh(
    new THREE.CapsuleGeometry(0.4, 1.2, 8, 16),
    new THREE.MeshStandardMaterial({ color: 0x7b5ea7, roughness: 0.6 }),
  );
  private readonly ground: THREE.Mesh;
  private readonly resizeObserver: ResizeObserver;

  // Raycaster: kameradan fare yönüne görünmez bir ışın gönderip neye çarptığını bulur
  private readonly raycaster = new THREE.Raycaster();
  // Farenin ekrandaki konumu, -1..1 aralığında (sol alt -1,-1; sağ üst 1,1)
  private readonly pointer = new THREE.Vector2();

  // Mezar taşları; tıklama ışını ve vuruş tepkisi bunları kullanır
  private readonly graves: Grave[] = [];
  // Tırpanın omuzdaki dönme noktası. Savurmak = bu grubu döndürmek.
  private readonly weaponPivot = new THREE.Group();
  // Kendi çizdiğimiz tırpan; kılıç yüklenince gizlenir
  private readonly scythe = new THREE.Group();
  // Saldırılacak taş (yanına yürünüyor ya da vuruluyor); null ise saldırı yok
  private attackTarget: Grave | null = null;
  // Savurma başladıysa kaç saniyedir sürdüğü; null ise savurmuyor
  private swingTime: number | null = null;
  // Bu savurmanın darbesi taşa indi mi (her savurmada bir kez)
  private swingHasHit = false;
  // Savurma süresi ve darbe anı. Kapsülde sabit; model gelince vuruş animasyonuna göre ayarlanır.
  private swingDuration = SWING_DURATION;
  private hitMoment = HIT_MOMENT;

  // AnimationMixer: modelin animasyonlarını oynatan ve aralarında geçiş yapan Three.js parçası.
  // Model yüklenene kadar null.
  private mixer: THREE.AnimationMixer | null = null;
  private actions: Record<AnimationName, THREE.AnimationAction> | null = null;
  private currentAction: THREE.AnimationAction | null = null;

  // Hangi karelerin yürünebilir olduğunu bilen ızgara
  private readonly grid = new Grid(GROUND_SIZE, GROUND_SIZE, CELL_SIZE);
  // Sırayla gidilecek noktalar (A*'ın bulduğu yol). Boşsa karakter duruyor.
  private path: THREE.Vector3[] = [];
  // Debug: bulunan yolu zeminde gösteren çizgi
  private readonly pathLine = new THREE.Line(
    new THREE.BufferGeometry(),
    new THREE.LineBasicMaterial({ color: 0x9dffc8 }),
  );
  // Debug: engelli kareleri gösteren kırmızı karolar. Izgara değişince yeniden çizilir.
  private readonly debugTiles = new THREE.Group();
  // Her karede yeni vektör yaratmamak için tekrar kullanılan geçici vektör
  private readonly toTarget = new THREE.Vector3();
  // Bir önceki karenin zamanı (saniye); delta time bundan hesaplanır
  private lastTime: number | null = null;
  // Kameranın baktığı zemin noktası; karakteri yumuşakça takip eder
  private readonly cameraFocus = new THREE.Vector3();
  // Kameranın bu karede ulaşmak istediği nokta: karakterin ayağının altı
  private readonly cameraGoal = new THREE.Vector3();
  // Şu anki zoom ve tekerlekle istenen zoom; her karede birbirine yaklaşır
  private zoom = 1;
  private zoomTarget = 1;
  // Şu an basılı tutulan yön tuşları ve karakterin klavyeyle yürüyüp yürümediği
  private readonly pressedKeys = new Set<string>();
  private keyboardWalking = false;

  constructor(container: HTMLElement) {
    this.container = container;

    // Renderer: sahneyi canvas'a çizen motor
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFShadowMap; // kenarı yumuşatılmış gölge
    container.appendChild(this.renderer.domElement);

    // Kamera: üç eksende eşit uzaklık = izometrik bakış. Yönü burada bir kez
    // ayarlanır; sonra sadece konumu kaydırıldığı için açı hiç bozulmaz.
    this.camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 200);
    this.camera.position.copy(CAMERA_OFFSET);
    this.camera.lookAt(0, 0, 0);

    // Sahne içeriği
    this.scene.background = new THREE.Color(0x121018);
    this.addLights();
    this.ground = this.addGround();
    this.addGraves(); // mezar taşlarını hem sahneye hem ızgaraya engel olarak ekler
    this.player = this.createPlayer();
    this.loadCharacter().catch((error) => console.error('Karakter modeli yüklenemedi:', error));
    this.loadSword().catch((error) => console.error('Kılıç modeli yüklenemedi:', error));
    if (SHOW_DEBUG) this.addDebugView();

    // Canvas'a tıklanınca dünyada nereye tıklandığını bul
    this.renderer.domElement.addEventListener('pointerdown', this.onPointerDown);
    // passive: false, ki preventDefault ile tarayıcının sayfayı kaydırması/büyütmesi engellensin
    this.renderer.domElement.addEventListener('wheel', this.onWheel, { passive: false });
    window.addEventListener('keydown', this.onKeyDown);
    window.addEventListener('keyup', this.onKeyUp);
    window.addEventListener('blur', this.onBlur);

    // Pencere boyutu değişince kamerayı ve canvas'ı güncelle
    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(container);
    this.resize();
  }

  start() {
    // Her ekran yenilemesinde (genelde saniyede 60 kez) çalışır
    this.renderer.setAnimationLoop((time) => {
      const elapsed = time / 1000; // milisaniyeyi saniyeye çevir
      // Delta time: önceki kareden bu yana geçen süre. Sekme arka plandayken
      // büyük bir boşluk oluşursa karakter ışınlanmasın diye 0.1 sn ile sınırlı.
      const delta = this.lastTime === null ? 0 : Math.min(elapsed - this.lastTime, 0.1);
      this.lastTime = elapsed;

      this.update(elapsed, delta);
      this.renderer.render(this.scene, this.camera);
    });
  }

  dispose() {
    // İleride menüye dönerken oyunu temizlemek için
    this.renderer.setAnimationLoop(null);
    this.renderer.domElement.removeEventListener('pointerdown', this.onPointerDown);
    this.renderer.domElement.removeEventListener('wheel', this.onWheel);
    window.removeEventListener('keydown', this.onKeyDown);
    window.removeEventListener('keyup', this.onKeyUp);
    window.removeEventListener('blur', this.onBlur);
    this.resizeObserver.disconnect();
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }

  private update(elapsed: number, delta: number) {
    this.updateKeyboardMovement(delta);
    this.updateMovement(delta);
    this.updateAttack(delta, elapsed);
    this.updateGraves(elapsed);
    this.updateAnimation(delta);
    this.updateZoom(delta);
    this.updateCamera(delta); // karakter yürüdükten sonra, ki kamera güncel konumu izlesin

    // Nefes alma: döngünün çalıştığını gösteren küçük hareket
    // (sadece kapsülde; model gelince yerini animasyonlar alacak)
    const breath = 1 + Math.sin(elapsed * 2) * 0.03;
    this.placeholder.scale.set(1, breath, 1);
  }

  // WASD / ok tuşlarıyla yürüme. Yol bulma kullanmaz: karakter tuşun yönüne düz gider,
  // engele çarparsa yanından kayar.
  private updateKeyboardMovement(delta: number) {
    // Basılı tuşların yönlerini topla (W + D birlikte = çapraz)
    let dx = 0;
    let dz = 0;
    for (const key of this.pressedKeys) {
      const direction = KEY_DIRECTIONS[key];
      if (!direction) continue;
      dx += direction[0];
      dz += direction[1];
    }

    const length = Math.hypot(dx, dz);
    // Tuş yoksa (ya da W ile S gibi zıt tuşlar birbirini sıfırladıysa) ya da savuruyorsa durur
    this.keyboardWalking = length > 0 && this.swingTime === null;
    if (!this.keyboardWalking) return;

    // Klavye devraldı: tıklamayla başlamış yürüme ve saldırı iptal
    this.path = [];
    this.attackTarget = null;

    const step = (MOVE_SPEED * delta) / length; // yönü 1 uzunluğa indirip adım boyuyla çarp
    const position = this.player.position;
    const nextX = position.x + dx * step;
    const nextZ = position.z + dz * step;

    // Çarpışma: gidilecek kare engelliyse önce sadece x'te, sonra sadece z'de dene.
    // Böylece karakter engele çapraz çarptığında durmak yerine yüzeyi boyunca kayar.
    if (this.canStand(nextX, nextZ)) {
      position.x = nextX;
      position.z = nextZ;
    } else if (this.canStand(nextX, position.z)) {
      position.x = nextX;
    } else if (this.canStand(position.x, nextZ)) {
      position.z = nextZ;
    }

    this.player.rotation.y = Math.atan2(dx, dz); // yüzü tuşun yönüne
  }

  // Karakter bu dünya noktasında durabilir mi (engelli kare ya da zeminin dışı değil mi)
  private canStand(x: number, z: number): boolean {
    const cell = this.grid.worldToCell(x, z);
    return this.grid.isWalkable(cell.col, cell.row);
  }

  private readonly onKeyDown = (event: KeyboardEvent) => {
    if (!Object.hasOwn(KEY_DIRECTIONS, event.code)) return;
    event.preventDefault(); // ok tuşları sayfayı kaydırmasın
    this.pressedKeys.add(event.code);
  };

  private readonly onKeyUp = (event: KeyboardEvent) => {
    this.pressedKeys.delete(event.code);
  };

  // Pencere odağını kaybederse (Cmd+Tab gibi) tuş bırakma olayı gelmez; karakter sonsuza
  // kadar yürümesin diye bütün tuşları bırakılmış say
  private readonly onBlur = () => {
    this.pressedKeys.clear();
  };

  // Fare tekerleği / trackpad sıkıştırma: zoom hedefini değiştir
  private readonly onWheel = (event: WheelEvent) => {
    event.preventDefault(); // sayfa kaymasın, tarayıcı kendi zoom'unu yapmasın
    // Üstel değişim: her tekerlek adımı zoom'u aynı oranda değiştirir (yakında da uzakta da eşit his)
    const next = this.zoomTarget * Math.exp(-event.deltaY * ZOOM_SENSITIVITY);
    this.zoomTarget = THREE.MathUtils.clamp(next, MIN_ZOOM, MAX_ZOOM);
  };

  // Zoom'u hedefe yumuşakça yaklaştır. Kamera karakteri ortaladığı için zoom hep karaktere doğru.
  private updateZoom(delta: number) {
    if (Math.abs(this.zoom - this.zoomTarget) < 0.0001) return;
    this.zoom = THREE.MathUtils.lerp(this.zoom, this.zoomTarget, 1 - Math.exp(-ZOOM_SMOOTH * delta));
    this.camera.zoom = this.zoom;
    this.camera.updateProjectionMatrix();
  }

  private updateMovement(delta: number) {
    if (this.swingTime !== null) return; // savururken yürümez; savurma bitince yola devam eder

    let step = MOVE_SPEED * delta; // bu karede atılacak adımın boyu

    // Adım bitene ya da yol bitene kadar sıradaki noktaya doğru ilerle.
    // Döngü olmasının sebebi: bir noktaya varınca adımın kalanı bir sonrakine harcanır,
    // böylece köşe dönüşlerinde karakter bir an duraklamaz.
    while (step > 0 && this.path.length > 0) {
      const next = this.path[0];

      // Karakterden sıradaki noktaya giden vektör: uzunluğu kalan mesafe, yönü gidilecek yön
      this.toTarget.subVectors(next, this.player.position);
      const distance = this.toTarget.length();

      if (distance <= step) {
        // Noktaya bu adımda varılıyor: üstüne koy, listeden çıkar, kalan adımla devam et
        this.player.position.copy(next);
        this.path.shift();
        step -= distance;
        continue;
      }

      // Yüzünü yürüdüğü yöne çevir. atan2, x ve z farkından açıyı (radyan) bulur.
      this.player.rotation.y = Math.atan2(this.toTarget.x, this.toTarget.z);

      // Yönü 1 birim uzunluğa indir (normalize), sonra adım boyu kadar ilerle
      this.player.position.addScaledVector(this.toTarget.normalize(), step);
      step = 0;
    }

    this.pathLine.visible = this.path.length > 0; // varınca yol çizgisini gizle
  }

  private updateAttack(delta: number, elapsed: number) {
    // 1. Hedef var, yürüme bitti, henüz savurmuyor: menzildeyse savurmaya başla
    if (this.attackTarget && this.swingTime === null && this.path.length === 0) {
      const target = this.attackTarget.basePosition;
      const dx = target.x - this.player.position.x;
      const dz = target.z - this.player.position.z;

      if (Math.hypot(dx, dz) <= ATTACK_RANGE) {
        this.player.rotation.y = Math.atan2(dx, dz); // yüzünü taşa çevir
        this.swingTime = 0;
        this.swingHasHit = false;
      } else {
        this.attackTarget = null; // taşa yaklaşamadık (yol yoktu), saldırıdan vazgeç
      }
    }

    if (this.swingTime === null) return;

    // 2. Savurmayı ilerlet. progress: 0 = başlangıç, 1 = bitiş.
    //    Model varsa kolu vuruş animasyonu sallar; yoksa (kapsülde) tırpanı biz döndürürüz.
    this.swingTime += delta;
    const progress = Math.min(this.swingTime / this.swingDuration, 1);
    if (!this.mixer) this.weaponPivot.rotation.x = swingAngle(progress);

    // 3. Darbe anı geldiyse taşa vur (her savurmada bir kez)
    if (!this.swingHasHit && progress >= this.hitMoment && this.attackTarget) {
      this.swingHasHit = true;
      this.hitGrave(this.attackTarget, elapsed);
    }

    // 4. Savurma bitti: silahı dinlenme açısına bırak, saldırıyı bitir
    if (progress >= 1) {
      this.swingTime = null;
      this.attackTarget = null;
      if (!this.mixer) this.weaponPivot.rotation.x = WEAPON_REST;
    }
  }

  // Karakterin o an ne yaptığına göre doğru animasyonu seç ve oynat
  private updateAnimation(delta: number) {
    if (!this.mixer || !this.actions) return;

    const wanted =
      this.swingTime !== null ? this.actions.attack
      : this.path.length > 0 || this.keyboardWalking ? this.actions.walk
      : this.actions.idle;

    if (wanted !== this.currentAction) {
      // Yumuşak geçiş: yeni animasyon başından başlayıp belirirken eskisi söner
      wanted.reset().fadeIn(ANIMATION_FADE).play();
      this.currentAction?.fadeOut(ANIMATION_FADE);
      this.currentAction = wanted;
    }

    this.mixer.update(delta); // animasyonları delta kadar ilerlet, kemikleri hareket ettir
  }

  private hitGrave(grave: Grave, elapsed: number) {
    if (grave.breakTime !== null) return; // zaten kırılıyor
    grave.hits += 1;
    grave.hitTime = elapsed;
    // Darbe yönü: karakterden taşa. Taş bu yöne doğru sarsılacak.
    grave.hitDirection
      .set(grave.basePosition.x - this.player.position.x, 0, grave.basePosition.z - this.player.position.z)
      .normalize();
    console.log(`Mezar taşına vuruldu (${grave.hits}/${GRAVE_HEALTH})`);

    if (grave.hits >= GRAVE_HEALTH) {
      grave.breakTime = elapsed;
      this.rebuildGrid(); // engel hemen kalksın, karakter oradan geçebilsin
      console.log('Mezar taşı kırıldı');
    }
  }

  // Izgarayı sağlam taşlardan baştan kur. Sadece kırılan taşın karelerini boşaltmak
  // yerine baştan kuruyoruz ki iki engel aynı kareyi paylaşsa bile doğru kalsın.
  private rebuildGrid() {
    this.grid.clear();
    for (const grave of this.graves) {
      if (grave.breakTime !== null) continue;
      const { min, max } = grave.footprint;
      this.grid.blockRect(min.x, min.z, max.x, max.z);
    }
    if (SHOW_DEBUG) this.refreshDebugTiles();
  }

  // Vurulan taşları sars ve parlat; kırılanları toprağa göm ve sahneden sil
  private updateGraves(elapsed: number) {
    // Sondan başa doğru dönüyoruz ki silinen taş, sıradaki taşların yerini kaydırmasın
    for (let i = this.graves.length - 1; i >= 0; i--) {
      const grave = this.graves[i];

      if (grave.breakTime !== null) {
        const t = (elapsed - grave.breakTime) / BREAK_DURATION; // 0 → 1
        if (t >= 1) {
          // Gömülme bitti: sahneden ve listeden tamamen çıkar, malzemenin belleğini boşalt
          this.scene.remove(grave.mesh);
          grave.material.dispose();
          this.graves.splice(i, 1);
          continue;
        }
        const eased = t * t; // yavaş başlayıp hızlanan gömülme
        grave.mesh.position.copy(grave.basePosition).addScaledVector(grave.hitDirection, eased * 0.3);
        grave.mesh.position.y = grave.basePosition.y - eased * 1.3; // taş 1.2 boyunda: tamamen girsin
        // Darbe yönüne doğru devril: yön vektörüne dik eksen etrafında döndür
        grave.mesh.rotation.x = grave.hitDirection.z * eased * 0.9;
        grave.mesh.rotation.z = -grave.hitDirection.x * eased * 0.9;
        grave.mesh.scale.setScalar(1 - eased * 0.3);
        grave.material.emissiveIntensity = 1 - t;
        continue;
      }

      if (grave.hitTime === null) continue;

      const t = (elapsed - grave.hitTime) / HIT_FEEDBACK; // 0 → 1 arası ilerleme
      if (t >= 1) {
        grave.mesh.position.copy(grave.basePosition);
        grave.material.emissiveIntensity = 0;
        grave.hitTime = null;
        continue;
      }

      const fade = 1 - t; // tepki zamanla sönümlenir
      const shake = Math.sin(t * Math.PI * 6) * 0.08 * fade; // ileri-geri titreşim
      grave.mesh.position.copy(grave.basePosition).addScaledVector(grave.hitDirection, shake);
      grave.material.emissiveIntensity = fade; // anlık parlama, sonra söner
    }
  }

  private updateCamera(delta: number) {
    // Hedef: karakterin tam altındaki zemin noktası (y = 0)
    this.cameraGoal.set(this.player.position.x, 0, this.player.position.z);

    // Lerp: aradaki mesafenin bir kısmını kapat. Oran delta'ya göre hesaplanıyor
    // ki takip hissi 60 Hz ve 120 Hz ekranda aynı olsun.
    const t = 1 - Math.exp(-CAMERA_FOLLOW * delta);
    this.cameraFocus.lerp(this.cameraGoal, t);

    // Kamerayı odak noktasından hep aynı uzaklığa koy
    this.camera.position.copy(this.cameraFocus).add(CAMERA_OFFSET);
  }

  // Ok fonksiyonu (=>) olarak yazıldı ki içindeki "this" her zaman Game'i göstersin
  private readonly onPointerDown = (event: PointerEvent) => {
    if (event.button !== 0) return; // sadece sol tık

    // 1. Fare konumunu piksel cinsinden -1..1 aralığına çevir
    const rect = this.renderer.domElement.getBoundingClientRect();
    this.pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    this.pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1; // ekranda y aşağı doğru artar, dünyada yukarı

    // 2. Kameradan bu noktaya doğru ışın gönder
    this.raycaster.setFromCamera(this.pointer, this.camera);

    // 2a. Önce mezar taşlarına bak: birine tıklandıysa ona saldır
    const standing = this.graves.filter((g) => g.breakTime === null); // kırılanlara tıklanmaz
    const graveHit = this.raycaster.intersectObjects(standing.map((g) => g.mesh), false)[0];
    const grave = graveHit && this.graves.find((g) => g.mesh === graveHit.object);
    if (grave) {
      this.attack(grave);
      return;
    }

    // 2b. Taş değilse zemine bak
    // Başka yere tıklandı: saldırıdan vazgeç. Ama savurma başladıysa darbe yine insin;
    // yeni yürüme savurma bitince başlar.
    if (this.swingTime === null) this.attackTarget = null;
    const hit = this.raycaster.intersectObject(this.ground)[0];
    if (!hit) return; // zeminin dışına tıklandı

    // 3. Tıklanan noktaya giden yolu bul ve yürümeye başla
    const { x, z } = hit.point;
    this.walkTo(x, z);
  };

  private attack(grave: Grave) {
    if (this.swingTime !== null) return; // zaten savuruyor; bitmeden yenisi başlamaz
    this.attackTarget = grave;

    const target = grave.basePosition;
    const player = this.player.position;
    const distance = Math.hypot(target.x - player.x, target.z - player.z);

    if (distance <= ATTACK_RANGE) {
      this.path = []; // zaten menzilde: olduğu yerde vur
      return;
    }

    // Taşın karaktere bakan tarafında, taştan 1 birim ötedeki noktaya yürü.
    // Orası engelli kareye düşerse walkTo en yakın boş kareyi seçer.
    const awayX = (player.x - target.x) / distance;
    const awayZ = (player.z - target.z) / distance;
    this.walkTo(target.x + awayX, target.z + awayZ);
  }

  private walkTo(x: number, z: number) {
    const grid = this.grid;
    const y = this.player.position.y; // yürürken yükseklik değişmez, sadece x ve z

    // Hedef kare: tıklanan kare boşsa o, mezar taşının üstüne tıklandıysa en yakın boş kare
    const clicked = grid.worldToCell(x, z);
    const clickedIsFree = grid.isWalkable(clicked.col, clicked.row);
    const goal = clickedIsFree ? clicked : grid.nearestWalkable(x, z);
    if (!goal) return;

    const start = grid.worldToCell(this.player.position.x, this.player.position.z);
    const cells = findPath(grid, start, goal);
    if (!cells) return; // oraya giden yol yok

    // Kareleri dünya noktalarına çevir. İlk kare karakterin zaten durduğu kare,
    // son kare de aşağıda tam tıklanan noktayla değiştiriliyor; ikisi de atlanıyor.
    const points = cells.slice(1, -1).map((cell) => {
      const center = grid.cellCenter(cell);
      return new THREE.Vector3(center.x, y, center.z);
    });

    // Son nokta: tıklanan yer boşsa tam orası, değilse en yakın boş karenin ortası
    const end = clickedIsFree ? { x, z } : grid.cellCenter(goal);
    points.push(new THREE.Vector3(end.x, y, end.z));

    this.path = points;
    if (SHOW_DEBUG) this.showPath();
  }

  private addLights() {
    // Gökyüzü ve zeminden gelen yumuşak genel ışık
    const ambient = new THREE.HemisphereLight(0x8f86b0, 0x1a1622, 0.8);
    this.scene.add(ambient);

    // Ay ışığı: yönlü ışık, gölge düşürür
    const moon = new THREE.DirectionalLight(0xc9d4ff, 2);
    moon.position.set(-8, 15, 6);
    moon.castShadow = true;
    moon.shadow.mapSize.set(2048, 2048);
    const area = 15; // gölgenin hesaplandığı alanın yarı genişliği
    moon.shadow.camera.left = -area;
    moon.shadow.camera.right = area;
    moon.shadow.camera.top = area;
    moon.shadow.camera.bottom = -area;
    moon.shadow.camera.far = 50;
    this.scene.add(moon);
  }

  private addGround(): THREE.Mesh {
    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(GROUND_SIZE, GROUND_SIZE),
      new THREE.MeshStandardMaterial({ color: 0x2a2433, roughness: 1 }),
    );
    ground.rotation.x = -Math.PI / 2; // dik duran düzlemi yere yatır
    ground.receiveShadow = true;
    this.scene.add(ground);

    const grid = new THREE.GridHelper(GROUND_SIZE, GROUND_SIZE / CELL_SIZE, 0x4a3f5c, 0x352e42);
    grid.position.y = 0.01; // zeminle çakışıp titremesin
    this.scene.add(grid);

    return ground; // tıklama ışını bu nesneye karşı test edilecek
  }

  private addGraves() {
    // Geometri beş taşta ortak. Malzeme her taşta ayrı (clone), ki vurulan tek taş parlasın.
    const geometry = new THREE.BoxGeometry(0.8, 1.2, 0.25);
    const baseMaterial = new THREE.MeshStandardMaterial({
      color: 0x5c5866,
      roughness: 0.9,
      emissive: 0x9b6bff, // vurulunca parlayacağı renk
      emissiveIntensity: 0, // normalde parlamaz
    });
    const spots: [number, number][] = [[-4, -3], [-2, -5], [3, -4], [5, 2], [-5, 3]];

    for (const [x, z] of spots) {
      const material = baseMaterial.clone();
      const grave = new THREE.Mesh(geometry, material);
      grave.position.set(x, 0.6, z);
      grave.rotation.y = Math.random() * 0.4 - 0.2;
      grave.castShadow = true;
      grave.receiveShadow = true;
      this.scene.add(grave);
      // Taşın zemindeki izi (dönük haliyle), kapsül yarıçapı kadar büyütülmüş.
      // Box3 = nesneyi saran kutu. Izgarada bu izin dokunduğu kareler engelli olur.
      const footprint = new THREE.Box3().setFromObject(grave).expandByScalar(PLAYER_RADIUS);

      this.graves.push({
        mesh: grave,
        material,
        basePosition: grave.position.clone(),
        hitDirection: new THREE.Vector3(),
        hitTime: null,
        hits: 0,
        footprint,
        breakTime: null,
      });
    }

    this.rebuildGrid(); // bütün taşları ızgaraya engel olarak işle
  }

  // Debug görünümünü sahneye ekle: engelli kareler ve yol çizgisi
  private addDebugView() {
    this.scene.add(this.debugTiles);
    this.refreshDebugTiles();
    this.pathLine.visible = false;
    this.scene.add(this.pathLine);
  }

  // Debug: engelli kareleri yarı saydam kırmızı karolarla göster (eskileri silip baştan çizer)
  private refreshDebugTiles() {
    this.debugTiles.clear(); // önceki karoları kaldır (geometri ve malzeme ortak, silinmiyor)
    for (let row = 0; row < this.grid.rows; row++) {
      for (let col = 0; col < this.grid.cols; col++) {
        if (this.grid.isWalkable(col, row)) continue;
        const center = this.grid.cellCenter({ col, row });
        const mesh = new THREE.Mesh(DEBUG_TILE_GEOMETRY, DEBUG_TILE_MATERIAL);
        mesh.position.set(center.x, 0.02, center.z); // ızgara çizgilerinin hemen üstü
        this.debugTiles.add(mesh);
      }
    }
  }

  // Debug: bulunan yolu karakterin ayağından başlayan bir çizgiyle çiz
  private showPath() {
    const feet = (p: THREE.Vector3) => new THREE.Vector3(p.x, 0.05, p.z);
    const points = [feet(this.player.position), ...this.path.map(feet)];
    this.pathLine.geometry.dispose(); // eski çizginin belleğini boşalt
    this.pathLine.geometry = new THREE.BufferGeometry().setFromPoints(points);
    this.pathLine.visible = true;
  }

  // Karakter: görünmez bir grup, ayakları zeminde (y = 0). Yürüme ve dönme bu grubu
  // hareket ettirir. İçinde model yüklenene kadar görünen kapsül ve tırpan var.
  private createPlayer(): THREE.Group {
    const player = new THREE.Group();

    const body = this.placeholder;
    body.position.y = 1; // kapsül 2 birim boyunda; yarısı kadar yukarı ki zemine bassın
    body.castShadow = true;
    player.add(body);

    // Yüz işareti: kapsül yuvarlak olduğu için dönüşü görünmez; bu küçük
    // parça karakterin baktığı yönü (yerel +z) gösterir. Kapsülün "çocuğu"
    // olduğu için kapsülle birlikte hareket eder ve döner.
    const face = new THREE.Mesh(
      new THREE.BoxGeometry(0.3, 0.12, 0.2),
      new THREE.MeshStandardMaterial({ color: 0xb6f0d0, emissive: 0x3a8f6a }),
    );
    face.position.set(0, 0.45, 0.38);
    body.add(face);

    // Tırpan: sap + bıçak. Sağ omuzdaki pivot grubuna bağlı; savurma pivotu döndürür.
    // Pivotun yerel ekseninde sap yukarı (+y), bıçak ileri (+z) bakıyor.
    // Pivot x ekseninde pozitif dönünce sapın tepesi öne (+z) ve aşağı iner.
    const weaponMaterial = new THREE.MeshStandardMaterial({ color: 0xb59d7a, roughness: 0.8 });
    const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.055, 0.055, 1.5, 8), weaponMaterial);
    shaft.position.y = 0.45; // sapın ortası; tutulan yerin biraz altından başlayıp yukarı uzanır
    // Not: metalness kullanılmıyor. Sahnede yansıtacak ortam görüntüsü olmadığı için
    // metal yüzey koyu görünür; bunun yerine hafif kendi ışığı (emissive) var.
    const blade = new THREE.Mesh(
      new THREE.BoxGeometry(0.06, 0.16, 0.8),
      new THREE.MeshStandardMaterial({ color: 0xe6e9f2, roughness: 0.4, emissive: 0x3c4660 }),
    );
    blade.position.set(0, 1.15, 0.3); // sapın tepesinden öne doğru
    blade.rotation.x = 0.35; // hafif aşağı kıvrık
    for (const part of [shaft, blade]) part.castShadow = true;

    this.weaponPivot.position.set(0.5, 1.1, 0.05); // sağ el hizası (ayaklara göre)
    this.weaponPivot.rotation.x = WEAPON_REST;
    this.scythe.add(shaft, blade);
    this.weaponPivot.add(this.scythe);
    player.add(this.weaponPivot);

    this.scene.add(player);
    return player;
  }

  // Mixamo karakterini arka planda yükle; hazır olunca kapsülün yerine koy.
  // Yüklenirken oyun kapsülle oynanabilir kalır.
  private async loadCharacter() {
    // Model ve üç animasyon dosyasını aynı anda indir (sırayla beklemekten hızlı)
    const loader = new FBXLoader();
    const [model, idleFile, walkFile, attackFile] = await Promise.all([
      loader.loadAsync(CHARACTER_URL),
      loader.loadAsync(ANIMATION_URLS.idle),
      loader.loadAsync(ANIMATION_URLS.walk),
      loader.loadAsync(ANIMATION_URLS.attack),
    ]);

    // Mixamo santimetre kullanır, biz metre. Boyu ölçüp CHARACTER_HEIGHT'a ölçekle.
    const box = new THREE.Box3().setFromObject(model);
    const scale = CHARACTER_HEIGHT / (box.max.y - box.min.y);
    model.scale.setScalar(scale);
    model.position.y = -box.min.y * scale; // ayak tabanı tam zemine otursun

    model.traverse((child) => {
      if (child instanceof THREE.Mesh) {
        child.castShadow = true;
        child.receiveShadow = true;
        // İskeletli modellerde Three.js'in "ekranda mı" hesabı T-pozuna göre yapılır
        // ve animasyonda yanlışlıkla gizleyebilir; o yüzden bu kontrolü kapatıyoruz.
        child.frustumCulled = false;
      }
    });

    this.player.add(model);
    this.placeholder.visible = false; // artık kapsüle gerek yok

    // Animasyonlar. Her dosyada tek bir animasyon klibi (clip) var.
    const idleClip = lockRootMotion(idleFile.animations[0]);
    const walkClip = lockRootMotion(walkFile.animations[0]);
    const attackClip = lockRootMotion(attackFile.animations[0]);

    const mixer = new THREE.AnimationMixer(model);
    const idle = mixer.clipAction(idleClip);
    const walk = mixer.clipAction(walkClip);
    const attack = mixer.clipAction(attackClip);

    // Yürüme animasyonunu karakterin gerçek hızına uydur: ayaklar zeminde kaymasın
    walk.timeScale = MOVE_SPEED / (WALK_CLIP_SPEED * scale);
    // Vuruş bir kez oynar ve son karesinde bekler (döngüye girmez)
    attack.setLoop(THREE.LoopOnce, 1);
    attack.clampWhenFinished = true;
    attack.timeScale = ATTACK_TIME_SCALE;

    // Savurmanın süresi ve darbe anı artık animasyondan geliyor
    this.swingDuration = attackClip.duration / ATTACK_TIME_SCALE;
    this.hitMoment = ATTACK_HIT_MOMENT;

    idle.play();
    this.mixer = mixer;
    this.actions = { idle, walk, attack };
    this.currentAction = idle;

    this.attachWeaponToHand(model);
  }

  // Kılıcı yükle ve tırpanın yerine silah pivotuna tak. Pivot ele bağlıysa kılıç da elde olur.
  private async loadSword() {
    const gltf = await new GLTFLoader().loadAsync(SWORD_URL);
    const model = gltf.scene;

    const box = new THREE.Box3().setFromObject(model);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());

    // İç grup: modeli, tutulan nokta (kabzanın ortası) tam orijine gelecek şekilde kaydır
    const grip = new THREE.Group();
    model.position.set(-center.x, -(box.min.y + size.y * SWORD_GRIP), -center.z);
    grip.add(model);

    // Dış grup: döndür ve ölçekle. Pivotun ekseni: y = elden öne (bıçak bu yöne),
    // z = savurma yönü (bıçağın keskin kenarı ve geniş balçak bu yöne).
    // Modelde bıçak -y'de, geniş taraf x'te: model x → pivot z, model -y → pivot y, model z → pivot x.
    const sword = new THREE.Group();
    sword.quaternion.setFromRotationMatrix(
      new THREE.Matrix4().makeBasis(
        new THREE.Vector3(0, 0, 1), // modelin x ekseni nereye gidecek
        new THREE.Vector3(0, -1, 0), // modelin y ekseni (bıçak ters dönsün)
        new THREE.Vector3(1, 0, 0), // modelin z ekseni
      ),
    );
    sword.scale.setScalar(SWORD_LENGTH / size.y);
    sword.add(grip);

    // Ortam haritası: metal yüzeyin yansıtacağı sanal bir oda. Sahnede yansıtacak bir şey
    // olmadığı için metal kılıç yoksa simsiyah görünür. Sadece kılıca veriliyor ki
    // sahnenin karanlık havası değişmesin.
    const pmrem = new THREE.PMREMGenerator(this.renderer);
    const environment = pmrem.fromScene(new RoomEnvironment()).texture;
    pmrem.dispose();

    model.traverse((child) => {
      if (!(child instanceof THREE.Mesh)) return;
      child.castShadow = true;
      if (child.material instanceof THREE.MeshStandardMaterial) {
        child.material.envMap = environment;
        child.material.envMapIntensity = SWORD_SHINE;
      }
    });

    this.weaponPivot.add(sword);
    this.scythe.visible = false; // tırpana artık gerek yok
  }

  // Tırpanı sağ el kemiğine bağla; artık el nereye giderse tırpan da oraya gider
  private attachWeaponToHand(model: THREE.Object3D) {
    const hand = model.getObjectByName('mixamorigRightHand');
    const index = model.getObjectByName('mixamorigRightHandIndex1'); // işaret parmağı dibi
    const pinky = model.getObjectByName('mixamorigRightHandPinky1'); // serçe parmak dibi
    if (!hand || !index || !pinky) return; // farklı bir iskelet: tırpan yanda kalsın

    // Yumruğun içinden geçen sap, serçe parmak dibinden işaret parmağı dibine doğru uzanır:
    // kılıç tutar gibi, uç öne bakar (seçilen animasyonlar kılıç tutuşuna göre yapılmış).
    // Parmak kemikleri elin "çocuğu" olduğu için konumları zaten elin kendi ekseninde.
    const shaftDirection = new THREE.Vector3().subVectors(index.position, pinky.position).normalize();
    // Bıçak sapa dik, elin sırtı yönünde (parmakların tersi, elin -y ekseni).
    // Kol aşağı sarkarken bıçak yukarı bakar; savururken tırpan gibi geriye kıvrık kalır.
    const bladeDirection = new THREE.Vector3(0, -1, 0)
      .addScaledVector(shaftDirection, shaftDirection.y) // sapa dik olsun diye sap yönünü çıkar
      .normalize();
    const side = new THREE.Vector3().crossVectors(shaftDirection, bladeDirection);

    // Pivotun ekseni: x = yan, y = sap, z = bıçak (tırpan bu eksenlerde çizildi)
    const basis = new THREE.Matrix4().makeBasis(side, shaftDirection, bladeDirection);
    this.weaponPivot.quaternion.setFromRotationMatrix(basis);
    // Tutulan yer: iki parmak dibinin ortası
    this.weaponPivot.position.addVectors(index.position, pinky.position).multiplyScalar(0.5);
    // Kemik santimetre ölçeğinde; tırpan metre ile çizildi, ölçeği geri al
    model.updateMatrixWorld(true);
    this.weaponPivot.scale.setScalar(1 / hand.getWorldScale(new THREE.Vector3()).x);

    hand.add(this.weaponPivot); // eski yerinden (karakter grubundan) alınıp ele takılır
  }

  private resize() {
    const width = this.container.clientWidth;
    const height = this.container.clientHeight;
    if (width === 0 || height === 0) return;

    const aspect = width / height;
    this.camera.left = (-VIEW_HEIGHT * aspect) / 2;
    this.camera.right = (VIEW_HEIGHT * aspect) / 2;
    this.camera.top = VIEW_HEIGHT / 2;
    this.camera.bottom = -VIEW_HEIGHT / 2;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height);
  }
}

// Savurmanın ilerlemesine (0..1) göre tırpanın açısı:
// önce yavaşça geriye kaldırır, sonra hızla öne indirir, sonra dinlenmeye döner.
function swingAngle(progress: number): number {
  const { lerp, smoothstep } = THREE.MathUtils;
  const windupEnd = 0.35;
  if (progress < windupEnd) {
    return lerp(WEAPON_REST, WEAPON_WINDUP, smoothstep(progress / windupEnd, 0, 1));
  }
  if (progress < HIT_MOMENT) {
    return lerp(WEAPON_WINDUP, WEAPON_STRIKE, (progress - windupEnd) / (HIT_MOMENT - windupEnd));
  }
  return lerp(WEAPON_STRIKE, WEAPON_REST, smoothstep((progress - HIT_MOMENT) / (1 - HIT_MOMENT), 0, 1));
}

// Animasyonun karakteri kendiliğinden ileri taşımasını (root motion) kaldır.
// Örneğin vuruş animasyonu karakteri 3 metre öne atılıyor; biz konumu kendimiz yönetiyoruz.
// Kalçanın yatay (x, z) konumu ilk karedeki değerde sabitlenir; yukarı-aşağı (y) kalır.
function lockRootMotion(clip: THREE.AnimationClip): THREE.AnimationClip {
  const hips = clip.tracks.find((track) => track.name === 'mixamorigHips.position');
  if (!hips) return clip;
  const values = hips.values; // [x, y, z, x, y, z, ...] her kare için üç sayı
  const startX = values[0];
  const startZ = values[2];
  for (let i = 0; i < values.length; i += 3) {
    values[i] = startX;
    values[i + 2] = startZ;
  }
  return clip;
}
