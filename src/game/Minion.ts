// Dirilen iskelet: topraktan yükselir, karakteri takip eder ve yakındaki vampirlere saldırır.
// Hâlleri:
//   takip   → hedef yoksa karakterin çevresindeki kendi yerine yürür
//   saldırı → yakında vampir varsa ona koşar ve vurur; vampir ölünce ya da karakterden
//             çok uzaklaşınca takibe döner
// Yol bulmayı karakterle aynı ızgara ve A* ile yapar. Şimdilik canı yok, ölmez.

import * as THREE from 'three';
import type { Enemy } from './Enemy';
import type { Grid } from './Grid';
import { followPath, groundDistance, planPath } from './pathing';
import { createSkeleton, setGlow, type Skeleton } from './Skeleton';

// Yürüme hızı (karakterden biraz hızlı, ki geride kalınca yetişebilsin)
const MINION_SPEED = 3.4;
// Karaktere bu mesafeden uzaksa takibe başlar
const FOLLOW_START = 3;
// Karakterin çevresinde durduğu yerin karaktere uzaklığı
const SLOT_DISTANCE = 1.6;
// Yolu kaç saniyede bir yeniden hesapladığı (karakter ya da hedef yürüdükçe yer değişir)
const REPATH_INTERVAL = 0.4;

// Saldırı: vampiri fark ettiği uzaklık, karakterden en fazla ne kadar uzaklaşabileceği
// (daha uzaktaki vampiri kovalamaz, kovalarken bu sınırı geçerse geri döner),
// yeni hedef aramanın sıklığı (saniye)
const SIGHT_RANGE = 6;
const LEASH_RANGE = 10;
const SCAN_INTERVAL = 0.5;
// Vurmaya başladığı uzaklık, darbe anında hedefin en fazla ne kadar uzakta olabileceği, hasarı
// (vampirin canı 30, karakterinki 10: minion daha zayıf), vuruş animasyonunun hızı,
// darbenin animasyonun hangi anında (0..1) indiği ve iki vuruş arası mola (saniye)
const ATTACK_RANGE = 1.5;
const HIT_REACH = 2.1;
const DAMAGE = 5;
const ATTACK_TIME_SCALE = 1.3;
const ATTACK_HIT_MOMENT = 0.45;
const ATTACK_COOLDOWN = 0.5;
// Çizilmiş (animasyonsuz) iskelette bir vuruşun süresi (saniye)
const DRAWN_ATTACK_DURATION = 0.8;

// Topraktan çıkma süresi (saniye) ve başlangıçta toprağın ne kadar altında olduğu
const RISE_DURATION = 0.9;
const RISE_DEPTH = 1.8;
// Animasyonlar arasındaki yumuşak geçiş süresi (saniye)
const ANIMATION_FADE = 0.2;
// Çizilmiş (kemiksiz) iskelet için: yürürken kol ve bacakların ne kadar sallandığı (radyan) ve adım hızı
const LIMB_SWING = 0.6;
const STEP_RATE = 9;
// Yürürken gövdenin her adımda ne kadar zıpladığı (metre) ve iki yana yalpaladığı (radyan).
// Çizilmiş iskelette animasyon olmadığı için yürüme hissini bu ikisi veriyor.
const STEP_BOB = 0.06;
const STEP_SWAY = 0.1;

export class Minion {
  readonly object: THREE.Group;
  private readonly skeleton: Skeleton;
  private path: THREE.Vector3[] = [];
  private repathTimer = 0;
  // Topraktan çıkışın kaç saniyedir sürdüğü; null ise çıkış bitti
  private riseTime: number | null = 0;
  // Karakterin çevresindeki kendi yeri (açı). Her minion farklı yerde dursun, üst üste binmesin.
  private readonly slotAngle: number;

  // Saldırı durumu
  private target: Enemy | null = null;
  private scanTimer = 0;
  private attackTime: number | null = null; // vuruş başladıysa kaç saniyedir sürdüğü
  private attackHasHit = false;
  private cooldown = 0;

  // Riglenmiş modelde animasyonları oynatan mixer ve animasyonlar. Çizilmiş iskelette null.
  private readonly mixer: THREE.AnimationMixer | null = null;
  private readonly idle: THREE.AnimationAction | null = null;
  private readonly walk: THREE.AnimationAction | null = null;
  private readonly attack: THREE.AnimationAction | null = null;
  private currentAction: THREE.AnimationAction | null = null;
  // Çizilmiş iskelet için yürüme döngüsü ve adım salınımı (-1..1)
  private walkCycle = 0;
  private swing = 0;

  constructor(x: number, z: number, facing: number, slotAngle: number) {
    this.skeleton = createSkeleton();
    this.object = this.skeleton.root;
    this.object.position.set(x, -RISE_DEPTH, z);
    this.object.rotation.y = facing;
    this.slotAngle = slotAngle;

    const { model, animations } = this.skeleton;
    if (model && animations) {
      // Her minionun kendi mixer'ı var: hepsi aynı animasyonu kendi zamanında oynar
      this.mixer = new THREE.AnimationMixer(model);
      this.idle = this.mixer.clipAction(animations.idle);
      this.walk = this.mixer.clipAction(animations.walk);
      this.attack = this.mixer.clipAction(animations.attack);
      // Yürüme animasyonunu minionun hızına uydur, ayaklar yerde kaymasın
      this.walk.timeScale = MINION_SPEED / animations.walkSpeed;
      // Vuruş bir kez oynar ve son karesinde bekler
      this.attack.setLoop(THREE.LoopOnce, 1);
      this.attack.clampWhenFinished = true;
      this.attack.timeScale = ATTACK_TIME_SCALE;
      // Bekleme animasyonu rastgele bir yerinden başlasın, minionlar aynı anda kıpırdamasın
      this.idle.play();
      this.idle.time = Math.random() * animations.idle.duration;
      this.currentAction = this.idle;
    }
  }

  update(delta: number, elapsed: number, leader: THREE.Vector3, grid: Grid, enemies: readonly Enemy[]) {
    this.mixer?.update(delta);
    if (this.riseTime !== null) {
      this.updateRise(this.riseTime + delta); // topraktan çıkarken bekleme animasyonu oynar
      return;
    }

    if (this.attackTime !== null) {
      this.updateAttack(this.attackTime + delta, elapsed);
      return;
    }
    this.cooldown -= delta;

    // Belli aralıklarla hedefi gözden geçir: öldüyse ya da karakterden çok uzaklaştıysa bırak,
    // hedef yoksa yakındaki en yakın vampiri seç
    this.scanTimer -= delta;
    if (this.scanTimer <= 0) {
      this.scanTimer = SCAN_INTERVAL;
      this.chooseTarget(leader, enemies);
    }

    const target = this.target;
    if (target) {
      const distance = groundDistance(this.object.position, target.position);
      if (distance <= ATTACK_RANGE) {
        this.path = [];
        this.face(target.position);
        if (this.cooldown <= 0) this.startAttack();
        else this.animate(delta, false);
        return;
      }
      // Kovala: hedefin kendine bakan tarafına, ondan 1 m öteye
      this.repathTimer -= delta;
      if (this.repathTimer <= 0 || this.path.length === 0) {
        this.repathTimer = REPATH_INTERVAL;
        const away = 1 / distance;
        const p = target.position;
        this.path = planPath(grid, this.object.position, p.x + (this.object.position.x - p.x) * away, p.z + (this.object.position.z - p.z) * away) ?? [];
      }
    } else {
      // Takip: karakter uzaklaştıysa (ya da zaten yoldaysa) belli aralıklarla yolu yenile
      this.repathTimer -= delta;
      if (this.repathTimer <= 0) {
        this.repathTimer = REPATH_INTERVAL;
        if (groundDistance(leader, this.object.position) > FOLLOW_START || this.path.length > 0) {
          const x = leader.x + Math.sin(this.slotAngle) * SLOT_DISTANCE;
          const z = leader.z + Math.cos(this.slotAngle) * SLOT_DISTANCE;
          this.path = planPath(grid, this.object.position, x, z) ?? [];
        }
      }
    }

    const moving = followPath(this.object, this.path, MINION_SPEED * delta);
    this.animate(delta, moving);
  }

  // Hedefi güncelle. Yeni hedef: minionun SIGHT_RANGE içindeki, karakterin de LEASH_RANGE
  // içindeki en yakın canlı vampir (karakterden çok uzaklaşıp onu yalnız bırakmasın).
  private chooseTarget(leader: THREE.Vector3, enemies: readonly Enemy[]) {
    const current = this.target;
    if (current && current.alive && groundDistance(leader, current.position) <= LEASH_RANGE) return;
    if (current) this.path = []; // bırakılan hedefin kovalama yolunu at

    let best: Enemy | null = null;
    let bestDistance = SIGHT_RANGE;
    for (const enemy of enemies) {
      if (!enemy.alive || groundDistance(leader, enemy.position) > LEASH_RANGE) continue;
      const distance = groundDistance(this.object.position, enemy.position);
      if (distance <= bestDistance) {
        best = enemy;
        bestDistance = distance;
      }
    }
    this.target = best;
  }

  private startAttack() {
    this.attackTime = 0;
    this.attackHasHit = false;
    if (this.attack) this.play(this.attack);
  }

  // Vuruşu ilerlet; darbe anında hedef hâlâ yakındaysa hasar ver
  private updateAttack(attackTime: number, elapsed: number) {
    this.attackTime = attackTime;
    const duration = this.attack ? this.attack.getClip().duration / ATTACK_TIME_SCALE : DRAWN_ATTACK_DURATION;
    const progress = attackTime / duration;

    // Çizilmiş iskelet: sağ kolu kaldırıp indir
    const limbs = this.skeleton.limbs;
    if (limbs) limbs.rightArm.rotation.x = -Math.sin(Math.min(progress, 1) * Math.PI) * 2.2;

    const target = this.target;
    if (!this.attackHasHit && progress >= ATTACK_HIT_MOMENT && target) {
      this.attackHasHit = true;
      if (target.alive && groundDistance(this.object.position, target.position) <= HIT_REACH) {
        target.hit(this.object.position, DAMAGE, elapsed);
      }
    }
    if (progress >= 1) {
      this.attackTime = null;
      this.cooldown = ATTACK_COOLDOWN;
    }
  }

  private face(point: THREE.Vector3) {
    this.object.rotation.y = Math.atan2(point.x - this.object.position.x, point.z - this.object.position.z);
  }

  // Topraktan yükselme: aşağıdan yukarı çık, yeşil parıltı sönsün
  private updateRise(riseTime: number) {
    const t = Math.min(riseTime / RISE_DURATION, 1);
    const eased = 1 - (1 - t) ** 3; // hızlı başlayıp yavaşlayan çıkış
    this.object.position.y = -RISE_DEPTH * (1 - eased);
    setGlow(this.skeleton, 1 - t);
    this.riseTime = t >= 1 ? null : riseTime;
  }

  private play(wanted: THREE.AnimationAction) {
    if (wanted === this.currentAction) return;
    wanted.reset().fadeIn(ANIMATION_FADE).play();
    this.currentAction?.fadeOut(ANIMATION_FADE);
    this.currentAction = wanted;
  }

  // Yürürken ya da dururken doğru hareketi göster
  private animate(delta: number, moving: boolean) {
    if (this.idle && this.walk) {
      // Riglenmiş model: yürüyorsa yürüme, duruyorsa bekleme animasyonuna yumuşakça geç
      this.play(moving ? this.walk : this.idle);
      return;
    }

    // Çizilmiş iskelet: gövde zıplar ve yalpalar, kol ve bacaklar sallanır.
    // swing: -1..1 arası adım salınımı. Dururken sıfıra doğru sönümlenir (lerp).
    if (moving) {
      this.walkCycle += delta * STEP_RATE;
      this.swing = Math.sin(this.walkCycle);
    } else {
      this.swing = THREE.MathUtils.lerp(this.swing, 0, 1 - Math.exp(-10 * delta));
      this.walkCycle = 0;
    }

    const { body, limbs } = this.skeleton;
    body.position.y = Math.abs(this.swing) * STEP_BOB; // her adımda bir kez yukarı
    body.rotation.z = this.swing * STEP_SWAY; // adım atılan ayağın tarafına yatar

    if (!limbs) return;
    const angle = this.swing * LIMB_SWING;
    limbs.leftLeg.rotation.x = angle;
    limbs.rightLeg.rotation.x = -angle;
    limbs.leftArm.rotation.x = -angle * 0.8; // kollar bacakların tersine
    limbs.rightArm.rotation.x = angle * 0.8;
  }
}
