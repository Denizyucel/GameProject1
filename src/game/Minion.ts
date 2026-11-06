// Dirilen iskelet: topraktan yükselir, sonra karakteri takip eder.
// Yol bulmayı karakterle aynı ızgara ve A* ile yapar.

import * as THREE from 'three';
import type { Grid } from './Grid';
import { findPath } from './findPath';
import { createSkeleton, setGlow, type Skeleton } from './Skeleton';

// Yürüme hızı (karakterden biraz hızlı, ki geride kalınca yetişebilsin)
const MINION_SPEED = 3.4;
// Karaktere bu mesafeden uzaksa takibe başlar
const FOLLOW_START = 3;
// Karakterin çevresinde durduğu yerin karaktere uzaklığı
const SLOT_DISTANCE = 1.6;
// Takip ederken yolu kaç saniyede bir yeniden hesapladığı (karakter yürüdükçe hedef değişir)
const REPATH_INTERVAL = 0.5;
// Topraktan çıkma süresi (saniye) ve başlangıçta toprağın ne kadar altında olduğu
const RISE_DURATION = 0.9;
const RISE_DEPTH = 1.8;
// Bekleme ile yürüme animasyonu arasındaki yumuşak geçiş süresi (saniye)
const ANIMATION_FADE = 0.25;
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
  // Yürüme döngüsünün açısı: kol ve bacak sallanması bundan hesaplanır
  private walkCycle = 0;
  private swing = 0;
  // Karakterin çevresindeki kendi yeri (açı). Her minion farklı yerde dursun, üst üste binmesin.
  private readonly slotAngle: number;
  private readonly toTarget = new THREE.Vector3();
  // Riglenmiş modelde animasyonları oynatan mixer ve iki animasyon. Çizilmiş iskelette null.
  private readonly mixer: THREE.AnimationMixer | null = null;
  private readonly idle: THREE.AnimationAction | null = null;
  private readonly walk: THREE.AnimationAction | null = null;
  private currentAction: THREE.AnimationAction | null = null;

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
      // Yürüme animasyonunu minionun hızına uydur, ayaklar yerde kaymasın
      this.walk.timeScale = MINION_SPEED / animations.walkSpeed;
      // Bekleme animasyonu rastgele bir yerinden başlasın, minionlar aynı anda kıpırdamasın
      this.idle.play();
      this.idle.time = Math.random() * animations.idle.duration;
      this.currentAction = this.idle;
    }
  }

  update(delta: number, leader: THREE.Vector3, grid: Grid) {
    if (this.riseTime !== null) {
      this.updateRise(this.riseTime + delta);
      this.mixer?.update(delta); // topraktan çıkarken bekleme animasyonu oynasın
      return;
    }

    // Karakter uzaklaştıysa (ya da zaten yoldaysa) belli aralıklarla yolu yenile
    this.repathTimer -= delta;
    if (this.repathTimer <= 0) {
      this.repathTimer = REPATH_INTERVAL;
      const distance = Math.hypot(leader.x - this.object.position.x, leader.z - this.object.position.z);
      if (distance > FOLLOW_START || this.path.length > 0) this.planPath(leader, grid);
    }

    const moving = this.followPath(delta);
    this.animateLimbs(delta, moving);
  }

  // Topraktan yükselme: aşağıdan yukarı çık, yeşil parıltı sönsün
  private updateRise(riseTime: number) {
    const t = Math.min(riseTime / RISE_DURATION, 1);
    const eased = 1 - (1 - t) ** 3; // hızlı başlayıp yavaşlayan çıkış
    this.object.position.y = -RISE_DEPTH * (1 - eased);
    setGlow(this.skeleton, 1 - t);
    this.riseTime = t >= 1 ? null : riseTime;
  }

  // Karakterin çevresindeki kendi yerine giden yolu bul
  private planPath(leader: THREE.Vector3, grid: Grid) {
    const goalX = leader.x + Math.sin(this.slotAngle) * SLOT_DISTANCE;
    const goalZ = leader.z + Math.cos(this.slotAngle) * SLOT_DISTANCE;

    const clicked = grid.worldToCell(goalX, goalZ);
    const goalIsFree = grid.isWalkable(clicked.col, clicked.row);
    const goal = goalIsFree ? clicked : grid.nearestWalkable(goalX, goalZ);
    if (!goal) return;

    const start = grid.worldToCell(this.object.position.x, this.object.position.z);
    const cells = findPath(grid, start, goal);
    if (!cells) return;

    // Karakterin yürüme yoluyla aynı mantık: ara noktalar kare ortaları, son nokta tam hedef
    const points = cells.slice(1, -1).map((cell) => {
      const center = grid.cellCenter(cell);
      return new THREE.Vector3(center.x, 0, center.z);
    });
    const end = goalIsFree ? { x: goalX, z: goalZ } : grid.cellCenter(goal);
    points.push(new THREE.Vector3(end.x, 0, end.z));
    this.path = points;
  }

  // Yolda ilerle. Bu karede yürüdüyse true döner.
  private followPath(delta: number): boolean {
    if (this.path.length === 0) return false;
    let step = MINION_SPEED * delta;
    while (step > 0 && this.path.length > 0) {
      const next = this.path[0];
      this.toTarget.subVectors(next, this.object.position);
      const distance = this.toTarget.length();
      if (distance <= step) {
        this.object.position.copy(next);
        this.path.shift();
        step -= distance;
        continue;
      }
      this.object.rotation.y = Math.atan2(this.toTarget.x, this.toTarget.z);
      this.object.position.addScaledVector(this.toTarget.normalize(), step);
      step = 0;
    }
    return true;
  }

  // Yürürken adım at: gövde zıplar ve yalpalar, (çizilmiş iskelette) kol ve bacaklar sallanır.
  // Dururken her şey yavaşça düz duruşa döner.
  private animateLimbs(delta: number, moving: boolean) {
    if (this.mixer && this.idle && this.walk) {
      // Riglenmiş model: yürüyorsa yürüme, duruyorsa bekleme animasyonuna yumuşakça geç
      const wanted = moving ? this.walk : this.idle;
      if (wanted !== this.currentAction) {
        wanted.reset().fadeIn(ANIMATION_FADE).play();
        this.currentAction?.fadeOut(ANIMATION_FADE);
        this.currentAction = wanted;
      }
      this.mixer.update(delta);
      return;
    }

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
