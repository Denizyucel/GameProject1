// Düşman: vampir (model yoksa yedek olarak hareketsiz mezar taşı).
// Evinin çevresinde rastgele dolaşır; vurulunca sarsılıp parlar, saldırana döner ve bir an durur.
// Canı bitince darbe yönünde devrilip toprağa gömülür. Henüz karşılık vermiyor.

import * as THREE from 'three';
import type { Grid } from './Grid';
import { findPath } from './findPath';
import type { GlowMaterial } from './Skeleton';
import type { VampireBody } from './Vampire';

// Canı: kaç vuruşta öldüğü
const HEALTH = 3;
// Vurulunca sarsılıp parladığı süre (saniye) ve sonrasında şaşkın durduğu süre
const HIT_FEEDBACK = 0.3;
const STUN_TIME = 1.6; // karakterin bir savurmasından (≈1.3 sn) uzun: saldırı altındayken kaçamasın
// Ölünce devrilip gömülme süresi (saniye), ne kadar devrildiği (radyan, ≈80°)
// ve ne kadar derine gömüldüğü (metre; vampir 2 m boyunda, tamamen girsin)
const DEATH_DURATION = 1.1;
const FALL_ANGLE = 1.4;
const SINK_DEPTH = 2.3;

// Dolaşma: yürüme hızı (karakterden yavaş, ki yakalanabilsin), evinden en fazla ne kadar
// uzaklaştığı ve iki yürüyüş arasında ne kadar beklediği (en az, en çok; saniye)
const WALK_SPEED = 1.2;
const WANDER_RADIUS = 5;
const WAIT_MIN = 1.5;
const WAIT_MAX = 4;
// Bekleme ile yürüme animasyonu arasındaki yumuşak geçiş süresi (saniye)
const ANIMATION_FADE = 0.25;

// Tıklamayı yakalayan görünmez kutu: genişlik, boy (metre). Ayrıntılı modele ışın atmak yavaş
// ve ince yerlerden ıskalanır; bu kutu hem hızlı hem tıklaması kolay.
const HITBOX_WIDTH = 1.2; // gövdeden biraz geniş: yürüyen vampire tıklamak kolay olsun
const HITBOX_HEIGHT = 2;
const HITBOX_GEOMETRY = new THREE.BoxGeometry(HITBOX_WIDTH, HITBOX_HEIGHT, HITBOX_WIDTH).translate(0, HITBOX_HEIGHT / 2, 0);
// visible: false → çizilmez ama ışın yine çarpar
const HITBOX_MATERIAL = new THREE.MeshBasicMaterial({ visible: false });

// Yedek görünüm: mezar taşı. Şekli bütün taşlarda ortak; malzeme her birinde ayrı (clone).
const STONE_GEOMETRY = new THREE.BoxGeometry(0.8, 1.2, 0.25);
const STONE_MATERIAL = new THREE.MeshStandardMaterial({
  color: 0x5c5866,
  roughness: 0.9,
  emissive: 0x9b6bff, // vurulunca parlayacağı renk
  emissiveIntensity: 0, // normalde parlamaz
});

export class Enemy {
  // Dış grup: zemindeki konum ve baktığı yön. Kökü ayak hizasında.
  readonly root = new THREE.Group();
  // Tıklama ışınının çarptığı görünmez kutu (dış gruba bağlı, onunla yürür)
  readonly hitbox = new THREE.Mesh(HITBOX_GEOMETRY, HITBOX_MATERIAL);
  // Ölüm bitti mi; bitince Game onu sahneden siler ve yerine ceset bırakır
  finished = false;

  // İç grup: sarsılma ve devrilme bunu hareket ettirir, ki dış grubun yeri bozulmasın
  private readonly body = new THREE.Group();
  private readonly stone: THREE.Mesh;
  private materials: GlowMaterial[];
  private vampire: VampireBody | null = null;
  private currentAction: THREE.AnimationAction | null = null;

  private readonly home: THREE.Vector3; // dolaşmanın merkezi (ilk durduğu yer)
  private path: THREE.Vector3[] = [];
  private waitTime = THREE.MathUtils.randFloat(0, WAIT_MAX); // hepsi aynı anda yola çıkmasın
  private hits = 0;
  private hitTime: number | null = null; // son darbenin zamanı (saniye)
  private deathTime: number | null = null; // ölmeye başladığı zaman; null ise ayakta
  private readonly toTarget = new THREE.Vector3();

  constructor(x: number, z: number) {
    const material = STONE_MATERIAL.clone();
    this.stone = new THREE.Mesh(STONE_GEOMETRY, material);
    this.stone.position.y = 0.6; // taş 1.2 boyunda; yarısı kadar yukarı ki zemine otursun
    this.stone.castShadow = true;
    this.stone.receiveShadow = true;
    this.materials = [material];

    this.body.add(this.stone);
    this.root.add(this.body, this.hitbox);
    this.root.position.set(x, 0, z);
    // Haritanın ortasına (karakterin başladığı yere) dönük başlasın
    this.root.rotation.y = Math.atan2(-x, -z);
    this.home = this.root.position.clone();
  }

  get position(): THREE.Vector3 {
    return this.root.position;
  }

  get alive(): boolean {
    return this.deathTime === null;
  }

  /** Vampir modeli geldi: taşı gizle, yerine vampiri koy */
  dress(vampire: VampireBody) {
    this.stone.visible = false;
    for (const material of this.materials) material.dispose(); // taşın malzemesi artık kullanılmıyor
    this.materials = vampire.materials;
    this.body.add(vampire.model);
    // Yürüme animasyonunu vampirin gerçek hızına uydur: ayaklar zeminde kaymasın
    vampire.walk.timeScale = WALK_SPEED / vampire.walkSpeed;
    this.vampire = vampire;
    this.currentAction = vampire.idle;
  }

  /** Darbe al. from: saldıranın konumu. Bu darbeyle öldüyse true döner. */
  hit(from: THREE.Vector3, elapsed: number): boolean {
    if (!this.alive) return false;
    this.hits += 1;
    this.hitTime = elapsed;
    // Saldırana dön ve bir an dur (şaşkınlık). Saldırana döndüğü için darbe hep önden gelir:
    // geriye doğru sarsılır, ölünce de sırtüstü devrilir.
    this.root.rotation.y = Math.atan2(from.x - this.position.x, from.z - this.position.z);
    this.path = [];
    this.waitTime = STUN_TIME;
    if (this.hits < HEALTH) return false;
    this.deathTime = elapsed;
    return true;
  }

  update(delta: number, elapsed: number, grid: Grid) {
    this.vampire?.mixer.update(delta);

    if (this.deathTime !== null) {
      this.updateDeath(elapsed - this.deathTime);
      return;
    }
    this.updateHitFeedback(elapsed);

    // Sadece vampir dolaşır; yedek taş yerinde durur
    if (!this.vampire) return;
    const moving = this.updateWander(delta, grid);
    this.playAnimation(moving ? this.vampire.walk : this.vampire.idle);
  }

  /** Sahneden silinince malzemelerin belleğini boşalt */
  dispose() {
    for (const material of this.materials) material.dispose();
  }

  // Bekle, sonra evinin çevresinde rastgele bir yere yürü. Bu karede yürüdüyse true döner.
  private updateWander(delta: number, grid: Grid): boolean {
    if (this.path.length === 0) {
      this.waitTime -= delta;
      if (this.waitTime > 0) return false;
      this.waitTime = THREE.MathUtils.randFloat(WAIT_MIN, WAIT_MAX);
      this.planWander(grid);
      return false;
    }

    // Karakter ve minion ile aynı yol takibi: adım bitene kadar sıradaki noktaya ilerle
    let step = WALK_SPEED * delta;
    while (step > 0 && this.path.length > 0) {
      const next = this.path[0];
      this.toTarget.subVectors(next, this.root.position);
      const distance = this.toTarget.length();
      if (distance <= step) {
        this.root.position.copy(next);
        this.path.shift();
        step -= distance;
        continue;
      }
      this.root.rotation.y = Math.atan2(this.toTarget.x, this.toTarget.z);
      this.root.position.addScaledVector(this.toTarget.normalize(), step);
      step = 0;
    }
    return true;
  }

  // Evinin çevresinde rastgele, yürünebilir bir nokta seç ve oraya giden yolu bul
  private planWander(grid: Grid) {
    const angle = Math.random() * Math.PI * 2;
    const distance = Math.sqrt(Math.random()) * WANDER_RADIUS; // karekök: daire içine eşit dağılsın
    const x = this.home.x + Math.sin(angle) * distance;
    const z = this.home.z + Math.cos(angle) * distance;
    const goal = grid.worldToCell(x, z);
    if (!grid.isWalkable(goal.col, goal.row)) return; // engel ya da harita dışı: bir dahaki sefere

    const start = grid.worldToCell(this.root.position.x, this.root.position.z);
    const cells = findPath(grid, start, goal);
    if (!cells) return;
    const points = cells.slice(1, -1).map((cell) => {
      const center = grid.cellCenter(cell);
      return new THREE.Vector3(center.x, 0, center.z);
    });
    points.push(new THREE.Vector3(x, 0, z));
    this.path = points;
  }

  private playAnimation(wanted: THREE.AnimationAction) {
    if (wanted === this.currentAction) return;
    wanted.reset().fadeIn(ANIMATION_FADE).play();
    this.currentAction?.fadeOut(ANIMATION_FADE);
    this.currentAction = wanted;
  }

  // Vurulunca: geriye doğru kısa titreşim ve anlık parlama, sonra söner
  private updateHitFeedback(elapsed: number) {
    if (this.hitTime === null) return;
    const t = (elapsed - this.hitTime) / HIT_FEEDBACK; // 0 → 1
    if (t >= 1) {
      this.body.position.set(0, 0, 0);
      this.glow(0);
      this.hitTime = null;
      return;
    }
    const fade = 1 - t;
    // İç grubun kendi ekseninde -z = geri (vampir saldırana bakıyor)
    this.body.position.z = -Math.sin(t * Math.PI * 6) * 0.08 * fade;
    this.glow(fade);
  }

  // Ölüm: önce geriye devril (ilk %55), sonra toprağa gömül (son %55; biraz üst üste biner)
  private updateDeath(sinceDeath: number) {
    const t = sinceDeath / DEATH_DURATION; // 0 → 1
    if (t >= 1) {
      this.finished = true;
      return;
    }
    const fall = THREE.MathUtils.smoothstep(t / 0.55, 0, 1);
    const sink = Math.max(0, (t - 0.45) / 0.55) ** 2;
    this.body.position.set(0, -sink * SINK_DEPTH, -fall * 0.3);
    // x ekseni etrafında eksi yönde dönünce tepe geriye (-z) yatar. Kök ayakta: ayakları üstünde devrilir.
    this.body.rotation.x = -fall * FALL_ANGLE;
    this.glow((1 - t) * 0.6);
  }

  // Parlama (0 = yok, 1 = tam)
  private glow(intensity: number) {
    for (const material of this.materials) material.emissiveIntensity = intensity;
  }
}
