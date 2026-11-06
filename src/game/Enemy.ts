// Düşman: vampir (model yoksa yedek olarak hareketsiz, zararsız mezar taşı).
// Hâlleri:
//   dolaşma  → evinin çevresinde rastgele yürür
//   gösteri  → bazı tarzlar karakteri ilk fark edince kas gösterisi yapar
//   kovalama → karakter yakına gelince (ya da vampir vurulunca) peşine düşer
//   saldırı  → menzildeyse vurur; vuruş bitince kısa bir ara verir
//   şaşkınlık→ vurulunca bir an durur
// Canı bitince ölüm animasyonunu oynatır (yoksa geriye devrilir) ve toprağa gömülür.
// Can, hasar, kovalama hızı ve hangi saldırıları kullandığı vampirin dövüş tarzından gelir (Vampire.ts).

import * as THREE from 'three';
import type { Grid } from './Grid';
import { followPath, groundDistance, planPath } from './pathing';
import type { GlowMaterial } from './Skeleton';
import type { VampireAttack, VampireBody } from './Vampire';

// Yedek taşın canı (vampirin canı dövüş tarzından gelir)
const STONE_HEALTH = 30;
// Vurulunca sarsılıp parladığı süre ve sonrasında şaşkın durduğu süre (saniye)
const HIT_FEEDBACK = 0.3;
const STUN_TIME = 0.4;
// Ölüm animasyonu yoksa: devrilip gömülme süresi (saniye), ne kadar devrildiği (radyan, ≈80°)
// ve ne kadar derine gömüldüğü (metre; vampir 2 m boyunda, tamamen girsin)
const DEATH_DURATION = 1.1;
// Ölüm animasyonu varsa: animasyon bittikten sonra toprağa gömülme süresi (saniye)
const SINK_AFTER_ANIMATION = 0.8;
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
// (Kovalama hızı dövüş tarzından gelir; hepsi karakterden (3 m/sn) yavaş: kaçmak mümkün.)
const AGGRO_RANGE = 5;
const ANGER_TIME = 6;
const GIVE_UP_RANGE = 12;
const CHASE_REPATH = 0.4; // hedef yürüdükçe yolu kaç saniyede bir yeniler

// Saldırı: vurmaya başladığı uzaklık ve darbe anında hedefin en fazla ne kadar uzakta olabileceği.
// (Hasar, mola ve hangi saldırılar: dövüş tarzından.)
const ATTACK_RANGE = 1.6;
const HIT_REACH = 2.2;

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
  private health = STONE_HEALTH;
  private hitTime: number | null = null; // son darbenin zamanı (saniye)
  private angryUntil = -Infinity; // bu zamana kadar kızgın: daha uzaktan da kovalar
  private stunTime = 0; // şaşkın kalacağı süre
  private attackTime: number | null = null; // vuruş başladıysa kaç saniyedir sürdüğü
  private attack: VampireAttack | null = null; // şu anki vuruş (tarzın saldırılarından rastgele biri)
  private attackHasHit = false;
  private tauntTime: number | null = null; // kas gösterisinin kalan süresi; null ise yapmıyor
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
    this.health = vampire.health;
    console.log(`Vampir: ${vampire.style}`);
  }

  /** Hasar al. from: saldıranın konumu. Bu darbeyle öldüyse true döner. */
  hit(from: THREE.Vector3, damage: number, elapsed: number): boolean {
    if (!this.alive) return false;
    this.health -= damage;
    this.hitTime = elapsed;
    this.angryUntil = elapsed + ANGER_TIME;
    // Vururken darbe almak vuruşu kesmez; yoksa sürekli vurulan vampir hiç karşılık veremezdi.
    // Vurmuyorsa saldırana döner ve bir an şaşırır.
    // Kas gösterisi ise darbeyle yarıda kesilir.
    if (this.attackTime === null) {
      this.root.rotation.y = Math.atan2(from.x - this.position.x, from.z - this.position.z);
      this.path = [];
      this.stunTime = STUN_TIME;
      this.tauntTime = null;
    }
    if (this.health > 0) return false;
    this.deathTime = elapsed;
    if (this.vampire?.death) this.playAnimation(this.vampire.death);
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
    if (this.tauntTime !== null) {
      // Kas gösterisi: yerinde durup karaktere bakar
      this.tauntTime -= delta;
      this.face(prey.position);
      if (this.tauntTime <= 0) this.tauntTime = null;
      return;
    }
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
      this.playMove(moving, vampire.walk, WALK_SPEED, vampire.walkSpeed);
      return;
    }

    if (!this.chasing) {
      this.chasing = true;
      // Karakteri yeni fark etti. Gösteri yapan tarzsa (ve vurulup kızmadıysa) önce kaslarını göstersin.
      if (vampire.taunt && elapsed >= this.angryUntil) {
        this.path = [];
        this.face(prey.position);
        this.tauntTime = vampire.taunt.getClip().duration / vampire.taunt.timeScale;
        this.playAnimation(vampire.taunt);
        return;
      }
    }
    if (distance <= ATTACK_RANGE) {
      this.path = [];
      this.face(prey.position);
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
    const moving = followPath(this.root, this.path, vampire.chaseSpeed * delta);
    this.playMove(moving, vampire.chase, vampire.chaseSpeed, vampire.chaseClipSpeed);
  }

  /** Sahneden silinince malzemelerin belleğini boşalt */
  dispose() {
    for (const material of this.materials) material.dispose();
  }

  private face(point: THREE.Vector3) {
    this.root.rotation.y = Math.atan2(point.x - this.position.x, point.z - this.position.z);
  }

  // Tarzın saldırılarından rastgele birini seç ve başlat
  private startAttack() {
    const vampire = this.vampire;
    if (!vampire) return;
    this.attack = vampire.attacks[Math.floor(Math.random() * vampire.attacks.length)];
    this.attackTime = 0;
    this.attackHasHit = false;
    // Aynı saldırı art arda seçilirse playAnimation onu yeniden başlatmaz; bu yüzden önce sıfırla
    if (this.attack.action === this.currentAction) this.currentAction = null;
    this.playAnimation(this.attack.action);
  }

  // Vuruşu ilerlet; darbe anında hedef hâlâ yakındaysa hasar ver
  private updateAttack(attackTime: number, vampire: VampireBody, prey: Prey) {
    const attack = this.attack;
    if (!attack) return;
    this.attackTime = attackTime;
    const duration = attack.action.getClip().duration / attack.action.timeScale;
    const progress = attackTime / duration;

    if (!this.attackHasHit && progress >= attack.hitMoment) {
      this.attackHasHit = true;
      if (prey.alive && groundDistance(this.position, prey.position) <= HIT_REACH) prey.damage(vampire.damage);
    }
    if (progress >= 1) {
      this.attackTime = null;
      this.attack = null;
      this.cooldown = vampire.cooldown;
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

  // Yürüyorsa yürüme/koşma animasyonunu gerçek hızına uydurup oynat, duruyorsa bekleme animasyonunu.
  // clipSpeed: animasyonun normal hızda oynarken kaç m/sn yürüttüğü. Oran tutarsa ayaklar kaymaz.
  private playMove(moving: boolean, move: THREE.AnimationAction, speed: number, clipSpeed: number) {
    const vampire = this.vampire;
    if (!vampire) return;
    if (moving) move.timeScale = speed / clipSpeed;
    this.playAnimation(moving ? move : vampire.idle);
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

  // Ölüm. Animasyon varsa: animasyon oynar, bitince toprağa gömülür.
  // Yoksa: önce geriye devril (ilk %55), sonra toprağa gömül (son %55; biraz üst üste biner).
  private updateDeath(sinceDeath: number) {
    const death = this.vampire?.death;
    if (death) {
      const animation = death.getClip().duration / death.timeScale;
      const t = (sinceDeath - animation) / SINK_AFTER_ANIMATION; // animasyon bitene kadar eksi
      if (t >= 1) this.finished = true;
      else if (t > 0) this.body.position.y = -t * t * SINK_DEPTH * 0.5; // yerde yatıyor: yarısı yeter
      this.glow(Math.max(0, 1 - sinceDeath / 0.5) * 0.6);
      return;
    }

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
