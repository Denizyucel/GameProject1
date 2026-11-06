// Düşman: vampir (model yoksa yedek olarak hareketsiz, zararsız mezar taşı).
// Hâlleri:
//   dolaşma  → evinin çevresinde rastgele yürür
//   kovalama → karakter yakına gelince (ya da vampir vurulunca) peşine düşer
//   saldırı  → menzildeyse vurur; vuruş bitince kısa bir ara verir
//   şaşkınlık→ vurulunca bir an durur
// Canı bitince geriye devrilip toprağa gömülür.

import * as THREE from 'three';
import type { Grid } from './Grid';
import { followPath, groundDistance, planPath } from './pathing';
import type { GlowMaterial } from './Skeleton';
import type { VampireBody } from './Vampire';

// Can: toplam kaç hasar alınca öldüğü
const MAX_HEALTH = 30;
// Vurulunca sarsılıp parladığı süre ve sonrasında şaşkın durduğu süre (saniye)
const HIT_FEEDBACK = 0.3;
const STUN_TIME = 0.4;
// Ölünce devrilip gömülme süresi (saniye), ne kadar devrildiği (radyan, ≈80°)
// ve ne kadar derine gömüldüğü (metre; vampir 2 m boyunda, tamamen girsin)
const DEATH_DURATION = 1.1;
const FALL_ANGLE = 1.4;
const SINK_DEPTH = 2.3;

// Dolaşma: yürüme hızı, evinden en fazla ne kadar uzaklaştığı ve iki yürüyüş arasında
// ne kadar beklediği (en az, en çok; saniye)
const WALK_SPEED = 1.2;
const WANDER_RADIUS = 5;
const WAIT_MIN = 1.5;
const WAIT_MAX = 4;

// Kovalama: karakteri fark ettiği uzaklık; vurulduktan sonra kaç saniye "kızgın" kaldığı
// (bu sürede daha uzaktan da kovalar) ve en fazla ne kadar uzağa kadar kovaladığı.
// Kovalarken dolaşmaktan hızlı ama karakterden (3 m/sn) yavaş: kaçmak mümkün.
const AGGRO_RANGE = 5;
const ANGER_TIME = 6;
const GIVE_UP_RANGE = 12;
const CHASE_SPEED = 2;
const CHASE_REPATH = 0.4; // hedef yürüdükçe yolu kaç saniyede bir yeniler

// Saldırı: vurmaya başladığı uzaklık, darbe anında hedefin en fazla ne kadar uzakta olabileceği,
// verdiği hasar, darbenin animasyonun hangi anında (0..1) indiği ve iki vuruş arası mola (saniye)
const ATTACK_RANGE = 1.6;
const HIT_REACH = 2.2;
const DAMAGE = 6;
const ATTACK_HIT_MOMENT = 0.45;
const ATTACK_COOLDOWN = 0.7;

// Animasyonlar arasındaki yumuşak geçiş süresi (saniye)
const ANIMATION_FADE = 0.2;

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

/** Vampirin saldırabileceği hedef (şimdilik sadece karakter) */
export interface Prey {
  readonly position: THREE.Vector3;
  readonly alive: boolean;
  damage(amount: number): void;
}

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
  private chasing = false;
  private repathTimer = 0;
  private health = MAX_HEALTH;
  private hitTime: number | null = null; // son darbenin zamanı (saniye)
  private angryUntil = -Infinity; // bu zamana kadar kızgın: daha uzaktan da kovalar
  private stunTime = 0; // şaşkın kalacağı süre
  private attackTime: number | null = null; // vuruş başladıysa kaç saniyedir sürdüğü
  private attackHasHit = false;
  private cooldown = 0; // bir sonraki vuruşa kalan mola
  private deathTime: number | null = null; // ölmeye başladığı zaman; null ise ayakta

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
    this.vampire = vampire;
    this.currentAction = vampire.idle;
  }

  /** Hasar al. from: saldıranın konumu. Bu darbeyle öldüyse true döner. */
  hit(from: THREE.Vector3, damage: number, elapsed: number): boolean {
    if (!this.alive) return false;
    this.health -= damage;
    this.hitTime = elapsed;
    this.angryUntil = elapsed + ANGER_TIME;
    // Vururken darbe almak vuruşu kesmez; yoksa sürekli vurulan vampir hiç karşılık veremezdi.
    // Vurmuyorsa saldırana döner ve bir an şaşırır.
    if (this.attackTime === null) {
      this.root.rotation.y = Math.atan2(from.x - this.position.x, from.z - this.position.z);
      this.path = [];
      this.stunTime = STUN_TIME;
    }
    if (this.health > 0) return false;
    this.deathTime = elapsed;
    return true;
  }

  update(delta: number, elapsed: number, grid: Grid, prey: Prey) {
    this.vampire?.mixer.update(delta);

    if (this.deathTime !== null) {
      this.updateDeath(elapsed - this.deathTime);
      return;
    }
    this.updateHitFeedback(elapsed);

    // Sadece vampir hareket eder ve saldırır; yedek taş yerinde durur
    const vampire = this.vampire;
    if (!vampire) return;

    if (this.attackTime !== null) {
      this.updateAttack(this.attackTime + delta, vampire, prey);
      return;
    }
    this.cooldown -= delta;
    if (this.stunTime > 0) {
      this.stunTime -= delta;
      this.playAnimation(vampire.idle);
      return;
    }

    // Karakter yakında mı (ya da vampir kızgınken yeterince yakında mı)?
    const distance = groundDistance(this.position, prey.position);
    const engaged = prey.alive && (distance <= AGGRO_RANGE || (elapsed < this.angryUntil && distance <= GIVE_UP_RANGE));

    if (!engaged) {
      if (this.chasing) {
        // Kovalamayı bıraktı (karakter kaçtı ya da öldü): evine dön, sonra yine dolaşsın
        this.chasing = false;
        this.path = planPath(grid, this.position, this.home.x, this.home.z) ?? [];
      }
      const moving = this.updateWander(delta, grid);
      this.playWalkOrIdle(vampire, moving, WALK_SPEED);
      return;
    }

    this.chasing = true;
    if (distance <= ATTACK_RANGE) {
      this.path = [];
      this.root.rotation.y = Math.atan2(prey.position.x - this.position.x, prey.position.z - this.position.z);
      if (this.cooldown <= 0) this.startAttack();
      else this.playAnimation(vampire.idle);
      return;
    }

    // Kovala: hedefin kendisine bakan tarafına, ondan 1 m öteye yürü; yolu belli aralıklarla yenile
    this.repathTimer -= delta;
    if (this.repathTimer <= 0 || this.path.length === 0) {
      this.repathTimer = CHASE_REPATH;
      const away = 1 / distance;
      const x = prey.position.x + (this.position.x - prey.position.x) * away;
      const z = prey.position.z + (this.position.z - prey.position.z) * away;
      this.path = planPath(grid, this.position, x, z) ?? [];
    }
    const moving = followPath(this.root, this.path, CHASE_SPEED * delta);
    this.playWalkOrIdle(vampire, moving, CHASE_SPEED);
  }

  /** Sahneden silinince malzemelerin belleğini boşalt */
  dispose() {
    for (const material of this.materials) material.dispose();
  }

  private startAttack() {
    this.attackTime = 0;
    this.attackHasHit = false;
    if (this.vampire) this.playAnimation(this.vampire.attack);
  }

  // Vuruşu ilerlet; darbe anında hedef hâlâ yakındaysa hasar ver
  private updateAttack(attackTime: number, vampire: VampireBody, prey: Prey) {
    this.attackTime = attackTime;
    const duration = vampire.attack.getClip().duration / vampire.attack.timeScale;
    const progress = attackTime / duration;

    if (!this.attackHasHit && progress >= ATTACK_HIT_MOMENT) {
      this.attackHasHit = true;
      if (prey.alive && groundDistance(this.position, prey.position) <= HIT_REACH) prey.damage(DAMAGE);
    }
    if (progress >= 1) {
      this.attackTime = null;
      this.cooldown = ATTACK_COOLDOWN;
    }
  }

  // Bekle, sonra evinin çevresinde rastgele bir yere yürü. Bu karede yürüdüyse true döner.
  private updateWander(delta: number, grid: Grid): boolean {
    if (this.path.length === 0) {
      this.waitTime -= delta;
      if (this.waitTime > 0) return false;
      this.waitTime = THREE.MathUtils.randFloat(WAIT_MIN, WAIT_MAX);
      const angle = Math.random() * Math.PI * 2;
      const distance = Math.sqrt(Math.random()) * WANDER_RADIUS; // karekök: daire içine eşit dağılsın
      const x = this.home.x + Math.sin(angle) * distance;
      const z = this.home.z + Math.cos(angle) * distance;
      const cell = grid.worldToCell(x, z);
      if (grid.isWalkable(cell.col, cell.row)) this.path = planPath(grid, this.position, x, z) ?? [];
      return false;
    }
    return followPath(this.root, this.path, WALK_SPEED * delta);
  }

  // Yürüyorsa yürüme animasyonunu hızına uydurup oynat, duruyorsa bekleme animasyonunu
  private playWalkOrIdle(vampire: VampireBody, moving: boolean, speed: number) {
    if (moving) vampire.walk.timeScale = speed / vampire.walkSpeed; // ayaklar yerde kaymasın
    this.playAnimation(moving ? vampire.walk : vampire.idle);
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
    // İç grubun kendi ekseninde -z = geri
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
