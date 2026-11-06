// Dirilen iskelet: topraktan yükselir, sonra karakteri takip eder.
// Yol bulmayı karakterle aynı ızgara ve A* ile yapar.

import * as THREE from 'three';
import type { Grid } from './Grid';
import { findPath } from './findPath';
import { createSkeleton, type Skeleton } from './Skeleton';

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
// Yürürken kol ve bacakların ne kadar sallandığı (radyan) ve ne hızlı
const LIMB_SWING = 0.6;
const STEP_RATE = 9;

export class Minion {
  readonly object: THREE.Group;
  private readonly skeleton: Skeleton;
  private path: THREE.Vector3[] = [];
  private repathTimer = 0;
  // Topraktan çıkışın kaç saniyedir sürdüğü; null ise çıkış bitti
  private riseTime: number | null = 0;
  // Yürüme döngüsünün açısı: kol ve bacak sallanması bundan hesaplanır
  private walkCycle = 0;
  // Karakterin çevresindeki kendi yeri (açı). Her minion farklı yerde dursun, üst üste binmesin.
  private readonly slotAngle: number;
  private readonly toTarget = new THREE.Vector3();

  constructor(x: number, z: number, facing: number, slotAngle: number) {
    this.skeleton = createSkeleton();
    this.object = this.skeleton.root;
    this.object.position.set(x, -RISE_DEPTH, z);
    this.object.rotation.y = facing;
    this.slotAngle = slotAngle;
  }

  update(delta: number, leader: THREE.Vector3, grid: Grid) {
    if (this.riseTime !== null) {
      this.updateRise(this.riseTime + delta);
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
    this.skeleton.material.emissiveIntensity = 1 - t;
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

  // Yürürken kol ve bacakları zıt yönlerde salla; dururken yavaşça düz pozisyona dön
  private animateLimbs(delta: number, moving: boolean) {
    const { leftArm, rightArm, leftLeg, rightLeg } = this.skeleton;
    let swing = 0;
    if (moving) {
      this.walkCycle += delta * STEP_RATE;
      swing = Math.sin(this.walkCycle) * LIMB_SWING;
    } else {
      // Durunca salınımı sıfıra doğru sönümle (lerp)
      const current = leftLeg.rotation.x;
      swing = THREE.MathUtils.lerp(current, 0, 1 - Math.exp(-10 * delta));
      this.walkCycle = 0;
    }
    leftLeg.rotation.x = swing;
    rightLeg.rotation.x = -swing;
    leftArm.rotation.x = -swing * 0.8; // kollar bacakların tersine
    rightArm.rotation.x = swing * 0.8;
  }
}
