import * as THREE from 'three';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { Grid } from './Grid';
import { findPath } from './findPath';
import { Minion } from './Minion';
import { createSkeleton, loadSkeletonModel, setGlow, type GlowMaterial } from './Skeleton';
import { createFlesh, loadFleshModel } from './Flesh';
import { createVampire, loadVampireModel } from './Vampire';
import { Enemy } from './Enemy';

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

// Zemin boyutu ve ızgara karesi (dünya birimi)
const GROUND_SIZE = 30;
const CELL_SIZE = 1;

// true iken engelli kareler kırmızı, bulunan yol yeşil çizgi olarak görünür
const SHOW_DEBUG = true;
// true iken tıklayınca bulunan yol zeminde yeşil çizgi olarak görünür (SHOW_DEBUG'dan ayrı)
const SHOW_PATH_LINE = false;
// Debug karolarının ortak şekli (yere yatırılmış kare) ve malzemesi
const DEBUG_TILE_GEOMETRY = new THREE.PlaneGeometry(CELL_SIZE * 0.9, CELL_SIZE * 0.9).rotateX(-Math.PI / 2);
const DEBUG_TILE_MATERIAL = new THREE.MeshBasicMaterial({ color: 0xff4d6d, transparent: true, opacity: 0.35 });

// Saldırı: karakter merkezi ile düşman merkezi arasında en fazla bu mesafe varken vurabilir
const ATTACK_RANGE = 2;
// Bir savurmanın toplam süresi (saniye) ve darbenin savurmanın hangi anında (0..1) indiği
const SWING_DURATION = 0.45;
const HIT_MOMENT = 0.55;
// Tırpanın açıları (radyan): duruş, geriye kaldırma, öne indirme
const WEAPON_REST = 0.25;
const WEAPON_WINDUP = -0.9;
const WEAPON_STRIKE = 1.7;
// Darbe anında düşman bu kadar uzaklaşmış olsa da vuruş sayılır (yürüyen hedefe biraz tolerans)
const HIT_REACH = ATTACK_RANGE + 0.5;
// Kovalarken yolun kaç saniyede bir yenilendiği (hedef yürüdükçe yeri değişir)
const CHASE_REPATH = 0.3;
// Düşmanların başladığı yerler (eski mezar taşlarının yerleri)
const ENEMY_SPOTS: [number, number][] = [[-4, -3], [-2, -5], [3, -4], [5, 2], [-5, 3]];

// Ölü diriltme
// Ölen her düşmandan düşen ceset sayısı (en az, en çok) ve ne kadar uzağa düştükleri
const CORPSES_MIN = 1;
const CORPSES_MAX = 2;
const CORPSE_SCATTER = 1.2;
// Diriltme tuşu: üst sıradaki 1 ve sayı tuş takımındaki 1
const RAISE_KEYS = ['Digit1', 'Numpad1'];
// Karakterden en fazla bu uzaklıktaki ceset diriltilebilir (en yakını seçilir)
const RAISE_RANGE = 8;
// Diriltirken rastgele biri seçilen büyü animasyonları (Mixamo "Magic Spell Pack")
const SPELL_NAMES = [
  'Standing 1H Magic Attack 01',
  'Standing 1H Magic Attack 02',
  'Standing 1H Magic Attack 03',
  'standing 1H cast spell 01',
  'Standing 2H Cast Spell 01',
  'Standing 2H Magic Area Attack 01',
  'Standing 2H Magic Area Attack 02',
  'Standing 2H Magic Attack 01',
  'Standing 2H Magic Attack 02',
  'Standing 2H Magic Attack 03',
  'Standing 2H Magic Attack 04',
  'Standing 2H Magic Attack 05',
];
// Dosya adlarında boşluk var; encodeURI onları adrese uygun hale getirir (boşluk → %20)
const SPELL_URLS = SPELL_NAMES.map((name) => encodeURI(`/models/Magic Spell Pack/${name}.fbx`));
// Büyü animasyonları 2–4 sn sürüyor; oyunda kaç kat hızlı oynatılacakları
const SPELL_TIME_SCALE = 1.5;
// Cesedin büyünün hangi anında (0..1) dirildiği
const RAISE_MOMENT = 0.5;
// İskelet içinden çıkarken et yığınının toprağa gömülme süresi (saniye) ve derinliği (metre)
const CORPSE_SINK_DURATION = 1.2;
const CORPSE_SINK_DEPTH = 0.45;
// Büyü sırasında cesedin en fazla ne kadar parladığı (1 = düz yeşil, doku kaybolur)
const CORPSE_GLOW = 0.5;
// Model yüklenmeden (kapsüldeyken) bir büyünün süresi (saniye)
const CAST_DURATION = 1;
// Altın açı (≈137.5°): her yeni minion karakterin çevresinde bir öncekinden bu kadar
// dönük bir yere yerleşir. Böylece kaç minion olursa olsun çembere eşit dağılırlar.
const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));

// Yerdeki ceset: et yığını (flesh.glb) ya da o yoksa yatan iskelet
interface Corpse {
  root: THREE.Object3D;
  materials: GlowMaterial[];
  baseY: number; // yerdeki yüksekliği; gömülürken buradan aşağı iner
  sinkTime: number | null; // iskelet içinden çıktıysa kaç saniyedir gömüldüğü; null ise yerinde duruyor
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

  // Düşmanlar (vampirler); tıklama ışını ve vuruş tepkisi bunları kullanır
  private readonly enemies: Enemy[] = [];
  // Tırpanın omuzdaki dönme noktası. Savurmak = bu grubu döndürmek.
  private readonly weaponPivot = new THREE.Group();
  // Kendi çizdiğimiz tırpan; kılıç yüklenince gizlenir
  private readonly scythe = new THREE.Group();
  // Saldırılacak düşman (yanına yürünüyor ya da vuruluyor); null ise saldırı yok
  private attackTarget: Enemy | null = null;
  // Şu anki savurmanın hedefi. Savurma başlayınca sabitlenir: oyuncu başka yere tıklasa da darbe ona iner.
  private swingTarget: Enemy | null = null;
  // Kovalarken yolun yenilenmesine kalan süre (saniye)
  private chaseTimer = 0;
  // Savurma başladıysa kaç saniyedir sürdüğü; null ise savurmuyor
  private swingTime: number | null = null;
  // Bu savurmanın darbesi düşmana indi mi (her savurmada bir kez)
  private swingHasHit = false;
  // Savurma süresi ve darbe anı. Kapsülde sabit; model gelince vuruş animasyonuna göre ayarlanır.
  private swingDuration = SWING_DURATION;
  private hitMoment = HIT_MOMENT;

  // Yerde diriltilmeyi bekleyen cesetler ve dirilmiş minionlar
  private readonly corpses: Corpse[] = [];
  private readonly minions: Minion[] = [];
  // Büyü başladıysa kaç saniyedir sürdüğü; null ise büyü yapmıyor
  private castTime: number | null = null;
  private castDuration = CAST_DURATION;
  // Bu büyüyle dirilecek ceset; dirilince null olur
  private castTarget: Corpse | null = null;
  // Bu büyüde oynayan animasyon ve yüklenen bütün büyü animasyonları
  private castAction: THREE.AnimationAction | null = null;
  private spellActions: THREE.AnimationAction[] = [];

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
    this.addEnemies(); // düşmanları hem sahneye hem ızgaraya engel olarak ekler
    this.player = this.createPlayer();
    this.loadCharacter().catch((error) => console.error('Karakter modeli yüklenemedi:', error));
    this.loadSword().catch((error) => console.error('Kılıç modeli yüklenemedi:', error));
    loadFleshModel().catch((error) => console.error('Et yığını modeli yüklenemedi:', error));
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
    this.updateCast(delta);
    this.updateCorpses(delta);
    this.updateEnemies(elapsed, delta);
    for (const minion of this.minions) minion.update(delta, this.player.position, this.grid);
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
    // Tuş yoksa (ya da W ile S gibi zıt tuşlar birbirini sıfırladıysa) ya da savuruyor/büyü yapıyorsa durur
    this.keyboardWalking = length > 0 && !this.isBusy();
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

  // Karakter şu an bir hareketin ortasında mı (vuruş ya da büyü). O sırada yürümez, yenisini başlatmaz.
  private isBusy(): boolean {
    return this.swingTime !== null || this.castTime !== null;
  }

  private readonly onKeyDown = (event: KeyboardEvent) => {
    if (RAISE_KEYS.includes(event.code)) {
      // event.repeat: tuş basılı tutulunca tarayıcının tekrar gönderdiği olay; onları sayma
      if (!event.repeat) this.raiseDead();
      return;
    }
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
    if (this.isBusy()) return; // savururken/büyü yaparken yürümez; bitince yola devam eder

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

    this.pathLine.visible = SHOW_PATH_LINE && this.path.length > 0; // varınca yol çizgisini gizle
  }

  // Saldırı: hedefi kovala, menzile girince vur, hedef ölene kadar vurmaya devam et
  private updateAttack(delta: number, elapsed: number) {
    // Hedef öldüyse saldırı biter
    if (this.attackTarget && !this.attackTarget.alive) this.attackTarget = null;

    // 1. Hedef var ve karakter boşta: menzildeyse savurmaya başla, değilse kovala
    if (this.attackTarget && !this.isBusy()) {
      const target = this.attackTarget.position;
      const dx = target.x - this.player.position.x;
      const dz = target.z - this.player.position.z;

      if (Math.hypot(dx, dz) <= ATTACK_RANGE) {
        this.path = []; // menzilde: dur ve vur
        this.player.rotation.y = Math.atan2(dx, dz); // yüzünü düşmana çevir
        this.swingTime = 0;
        this.swingHasHit = false;
        this.swingTarget = this.attackTarget;
      } else {
        // Hedef yürüyor: yolu belli aralıklarla (ya da yol bittiyse hemen) yenile
        this.chaseTimer -= delta;
        if (this.chaseTimer <= 0 || this.path.length === 0) {
          this.chaseTimer = CHASE_REPATH;
          if (!this.walkNear(target)) this.attackTarget = null; // yol yok: vazgeç
        }
      }
    }

    if (this.swingTime === null) return;

    // 2. Savurmayı ilerlet. progress: 0 = başlangıç, 1 = bitiş.
    //    Model varsa kolu vuruş animasyonu sallar; yoksa (kapsülde) tırpanı biz döndürürüz.
    this.swingTime += delta;
    const progress = Math.min(this.swingTime / this.swingDuration, 1);
    if (!this.mixer) this.weaponPivot.rotation.x = swingAngle(progress);

    // 3. Darbe anı geldiyse vur (her savurmada bir kez). Hedef bu arada uzaklaştıysa ıska.
    const target = this.swingTarget;
    if (!this.swingHasHit && progress >= this.hitMoment && target) {
      this.swingHasHit = true;
      const p = target.position;
      const inReach = Math.hypot(p.x - this.player.position.x, p.z - this.player.position.z) <= HIT_REACH;
      if (target.alive && inReach) {
        const died = target.hit(this.player.position, elapsed);
        console.log(died ? 'Vampir öldü' : 'Vampire vuruldu');
      } else {
        console.log('Iska');
      }
    }

    // 4. Savurma bitti. Hedef yaşıyorsa bir sonraki karede yeni savurma (ya da kovalama) başlar.
    if (progress >= 1) {
      this.swingTime = null;
      this.swingTarget = null;
      if (!this.mixer) this.weaponPivot.rotation.x = WEAPON_REST;
    }
  }

  // Karakterin o an ne yaptığına göre doğru animasyonu seç ve oynat
  private updateAnimation(delta: number) {
    if (!this.mixer || !this.actions) return;

    const wanted =
      this.castTime !== null ? (this.castAction ?? this.actions.idle)
      : this.swingTime !== null ? this.actions.attack
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

  // Düşmanları güncelle (dolaşma, vurulma, ölme); ölümü biten düşmanı silip yerine ceset bırak
  private updateEnemies(elapsed: number, delta: number) {
    // Sondan başa doğru dönüyoruz ki silinen düşman, sıradakilerin yerini kaydırmasın
    for (let i = this.enemies.length - 1; i >= 0; i--) {
      const enemy = this.enemies[i];
      enemy.update(delta, elapsed, this.grid);
      if (!enemy.finished) continue;
      this.dropCorpses(enemy.position);
      this.scene.remove(enemy.root);
      enemy.dispose();
      this.enemies.splice(i, 1);
    }
  }

  // Ölen düşmanın çevresine 1-2 ceset bırak
  private dropCorpses(around: THREE.Vector3) {
    const count = THREE.MathUtils.randInt(CORPSES_MIN, CORPSES_MAX);
    const startAngle = Math.random() * Math.PI * 2;
    for (let i = 0; i < count; i++) {
      // Cesetler düşmanın çevresine eşit aralıklı dağılsın (2 cesetse karşılıklı)
      const angle = startAngle + (i * Math.PI * 2) / count;
      let x = around.x + Math.sin(angle) * CORPSE_SCATTER;
      let z = around.z + Math.cos(angle) * CORPSE_SCATTER;
      if (!this.canStand(x, z)) {
        // Düşeceği yer başka bir düşmanın dibi ya da haritanın dışı: ölenin kendi yerine koy
        x = around.x;
        z = around.z;
      }

      const corpse = this.createCorpse();
      corpse.root.position.set(x, corpse.baseY, z);
      this.scene.add(corpse.root);
      this.corpses.push(corpse);
    }
  }

  // Et yığını; model yoksa (ya da henüz yüklenmediyse) sırtüstü yatan bir iskelet
  private createCorpse(): Corpse {
    const yaw = Math.random() * Math.PI * 2; // her ceset rastgele bir yöne dönük
    const flesh = createFlesh();
    if (flesh) {
      flesh.root.rotation.y = yaw;
      return { root: flesh.root, materials: flesh.materials, baseY: 0, sinkTime: null };
    }

    const skeleton = createSkeleton();
    const { root } = skeleton;
    // Sırtüstü yatır. Önce yere yatır (x), sonra rastgele bir yöne çevir (y);
    // "YXZ" sırası bu dönüşlerin hangi sırayla uygulanacağını söyler.
    root.rotation.order = 'YXZ';
    root.rotation.set(-Math.PI / 2, yaw, 0);
    // Çizilmiş iskelette kollar ve bacaklar iki yana açık, gözler sönük: ölü
    if (skeleton.limbs) {
      skeleton.limbs.leftArm.rotation.z = 0.5;
      skeleton.limbs.rightArm.rotation.z = -0.5;
      skeleton.limbs.leftLeg.rotation.z = 0.2;
      skeleton.limbs.rightLeg.rotation.z = -0.2;
    }
    if (skeleton.eyes) skeleton.eyes.visible = false;
    for (const material of skeleton.materials) material.color.multiplyScalar(0.75); // biraz daha soluk
    // lieHeight: kemikler toprağa gömülmesin diye biraz yukarıda
    return { root, materials: skeleton.materials, baseY: skeleton.lieHeight, sinkTime: null };
  }

  // İskeleti çıkmış cesetleri yavaşça toprağa göm, bitince sahneden sil
  private updateCorpses(delta: number) {
    for (let i = this.corpses.length - 1; i >= 0; i--) {
      const corpse = this.corpses[i];
      if (corpse.sinkTime === null) continue;
      corpse.sinkTime += delta;
      const t = Math.min(corpse.sinkTime / CORPSE_SINK_DURATION, 1);
      corpse.root.position.y = corpse.baseY - t * t * CORPSE_SINK_DEPTH; // yavaş başlayıp hızlanan gömülme
      setGlow(corpse, (1 - t) * CORPSE_GLOW);
      if (t >= 1) {
        this.scene.remove(corpse.root);
        for (const material of corpse.materials) material.dispose();
        this.corpses.splice(i, 1);
      }
    }
  }

  // 1 tuşu: en yakın cesedi dirilten büyüyü başlat
  private raiseDead() {
    if (this.isBusy()) return; // vuruş ya da önceki büyü bitmeden yenisi başlamaz
    const corpse = this.nearestCorpse();
    if (!corpse) {
      console.log('Yakında diriltilecek ceset yok');
      return;
    }

    // Yürümeyi ve saldırıyı bırak, yüzünü cesede çevir
    this.path = [];
    this.attackTarget = null;
    const target = corpse.root.position;
    const player = this.player.position;
    this.player.rotation.y = Math.atan2(target.x - player.x, target.z - player.z);

    this.castTarget = corpse;
    this.castTime = 0;
    // Yüklenen büyü animasyonlarından rastgele birini seç; süre o animasyondan gelir
    if (this.spellActions.length > 0) {
      const action = this.spellActions[Math.floor(Math.random() * this.spellActions.length)];
      this.castAction = action;
      this.castDuration = action.getClip().duration / SPELL_TIME_SCALE;
    } else {
      this.castAction = null;
      this.castDuration = CAST_DURATION;
    }
  }

  // Karaktere RAISE_RANGE içindeki en yakın ceset; yoksa null
  private nearestCorpse(): Corpse | null {
    let best: Corpse | null = null;
    let bestDistance = RAISE_RANGE;
    for (const corpse of this.corpses) {
      if (corpse.sinkTime !== null) continue; // iskeleti zaten çıktı, gömülüyor
      const p = corpse.root.position;
      const distance = Math.hypot(p.x - this.player.position.x, p.z - this.player.position.z);
      if (distance <= bestDistance) {
        best = corpse;
        bestDistance = distance;
      }
    }
    return best;
  }

  // Büyüyü ilerlet: ceset gittikçe yeşil parlar, dirilme anında minion olarak kalkar
  private updateCast(delta: number) {
    if (this.castTime === null) return;
    this.castTime += delta;
    const progress = Math.min(this.castTime / this.castDuration, 1);

    if (this.castTarget) {
      setGlow(this.castTarget, Math.min(progress / RAISE_MOMENT, 1) * CORPSE_GLOW);
      if (progress >= RAISE_MOMENT) {
        this.raiseCorpse(this.castTarget);
        this.castTarget = null;
      }
    }

    if (progress >= 1) {
      this.castTime = null;
      this.castAction = null;
    }
  }

  // Cesedin içinden topraktan yükselen bir minion çıkar; ceset de yavaşça toprağa gömülsün
  private raiseCorpse(corpse: Corpse) {
    corpse.sinkTime = 0;

    const { x, z } = corpse.root.position;
    const player = this.player.position;
    const facing = Math.atan2(player.x - x, player.z - z); // efendisine dönük kalksın
    const minion = new Minion(x, z, facing, this.minions.length * GOLDEN_ANGLE);
    this.scene.add(minion.object);
    this.minions.push(minion);
    console.log(`Ceset dirildi (${this.minions.length} minion)`);
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

    // 2a. Önce düşmanlara bak: birine tıklandıysa ona saldır
    const standing = this.enemies.filter((e) => e.alive); // ölenlere tıklanmaz
    const enemyHit = this.raycaster.intersectObjects(standing.map((e) => e.hitbox), false)[0];
    const enemy = enemyHit && this.enemies.find((e) => e.hitbox === enemyHit.object);
    if (enemy) {
      this.attack(enemy);
      return;
    }

    // 2b. Düşman değilse zemine bak
    // Başka yere tıklandı: saldırıdan vazgeç. Ama savurma başladıysa darbe yine insin
    // (swingTarget'a); yeni yürüme savurma bitince başlar.
    this.attackTarget = null;
    const hit = this.raycaster.intersectObject(this.ground)[0];
    if (!hit) return; // zeminin dışına tıklandı

    // 3. Tıklanan noktaya giden yolu bul ve yürümeye başla
    const { x, z } = hit.point;
    this.walkTo(x, z);
  };

  // Düşmana saldır: updateAttack kovalar, menzile girince vurur, ölene kadar vurmaya devam eder
  private attack(enemy: Enemy) {
    this.attackTarget = enemy;
    this.chaseTimer = 0; // yolu hemen hesapla
  }

  // Hedefin karaktere bakan tarafında, ondan 1 birim ötedeki noktaya yürü. Yol bulunamazsa false.
  private walkNear(target: THREE.Vector3): boolean {
    const player = this.player.position;
    const distance = Math.hypot(target.x - player.x, target.z - player.z);
    if (distance < 0.01) return true; // zaten üstünde
    const awayX = (player.x - target.x) / distance;
    const awayZ = (player.z - target.z) / distance;
    return this.walkTo(target.x + awayX, target.z + awayZ);
  }

  // (x, z) noktasına giden yolu bul ve yürümeye başla. Yol bulunamazsa false.
  private walkTo(x: number, z: number): boolean {
    const grid = this.grid;
    const y = this.player.position.y; // yürürken yükseklik değişmez, sadece x ve z

    // Hedef kare: tıklanan kare boşsa o, engelli kareye tıklandıysa en yakın boş kare
    const clicked = grid.worldToCell(x, z);
    const clickedIsFree = grid.isWalkable(clicked.col, clicked.row);
    const goal = clickedIsFree ? clicked : grid.nearestWalkable(x, z);
    if (!goal) return false;

    const start = grid.worldToCell(this.player.position.x, this.player.position.z);
    const cells = findPath(grid, start, goal);
    if (!cells) return false; // oraya giden yol yok

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
    if (SHOW_PATH_LINE) this.showPath();
    return true;
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

  // Düşmanları yerleştir. Önce yedek görünüm (mezar taşı) ile başlarlar; vampir modeli
  // yüklenince dressEnemies taşları gizleyip yerlerine vampirleri koyar.
  // Düşmanlar hareket ettiği için ızgarada engel değiller (ızgara sadece sabit engeller için).
  private addEnemies() {
    for (const [x, z] of ENEMY_SPOTS) {
      const enemy = new Enemy(x, z);
      this.scene.add(enemy.root);
      this.enemies.push(enemy);
    }
  }

  // Vampir modeli yüklendi: ayaktaki düşmanların taşını gizle, yerine vampir koy
  private dressEnemies() {
    for (const enemy of this.enemies) {
      if (!enemy.alive) continue; // ölmekte olan taş olarak kalsın
      const vampire = createVampire();
      if (!vampire) return;
      enemy.dress(vampire);
    }
  }

  // Debug görünümünü sahneye ekle: engelli kareler ve (açıksa) yol çizgisi
  private addDebugView() {
    this.scene.add(this.debugTiles);
    this.refreshDebugTiles();
    this.pathLine.visible = false;
    if (SHOW_PATH_LINE) this.scene.add(this.pathLine);
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

    // Vampir ve iskelet modelleri de aynı Mixamo kemiklerine sahip: karakterin bekleme ve yürüme
    // animasyonlarını onlara veriyoruz. Kalça yüksekliği, animasyonu onların boyuna uydurmak için.
    const hips = model.getObjectByName('mixamorigHips');
    const hipsHeight = hips ? hips.position.y : 100;
    loadVampireModel(idleClip, hipsHeight)
      .then(() => this.dressEnemies())
      .catch((error) => console.error('Vampir modeli yüklenemedi:', error));
    loadSkeletonModel({
      idle: idleClip,
      walk: walkClip,
      hipsHeight,
      walkClipSpeed: WALK_CLIP_SPEED,
    }).catch((error) => console.error('İskelet modeli yüklenemedi:', error));
    this.loadSpells(mixer).catch((error) => console.error('Büyü animasyonları yüklenemedi:', error));
  }

  // Büyü animasyonlarını yükle. Yüklenmezse diriltme yine çalışır, sadece animasyonsuz.
  private async loadSpells(mixer: THREE.AnimationMixer) {
    const loader = new FBXLoader();
    const files = await Promise.all(SPELL_URLS.map((url) => loader.loadAsync(url)));
    this.spellActions = files.map((file) => {
      const action = mixer.clipAction(lockRootMotion(file.animations[0]));
      // Vuruş gibi: bir kez oynar, son karesinde bekler
      action.setLoop(THREE.LoopOnce, 1);
      action.clampWhenFinished = true;
      action.timeScale = SPELL_TIME_SCALE;
      return action;
    });
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
