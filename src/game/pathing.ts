// Yol bulma ve yolda yürüme: minion ve vampir aynı kodu kullanır.

import * as THREE from 'three';
import type { Grid } from './Grid';
import { findPath } from './findPath';

const toTarget = new THREE.Vector3(); // her karede yeni vektör yaratmamak için ortak geçici vektör

/**
 * from'dan (x, z)'ye giden yol: sırayla gidilecek dünya noktaları. Ara noktalar kare ortaları,
 * son nokta tam hedef (hedef engelliyse en yakın boş karenin ortası). Yol yoksa null.
 */
export function planPath(grid: Grid, from: THREE.Vector3, x: number, z: number): THREE.Vector3[] | null {
  const clicked = grid.worldToCell(x, z);
  const goalIsFree = grid.isWalkable(clicked.col, clicked.row);
  const goal = goalIsFree ? clicked : grid.nearestWalkable(x, z);
  if (!goal) return null;

  const cells = findPath(grid, grid.worldToCell(from.x, from.z), goal);
  if (!cells) return null;

  // İlk kare zaten durulan kare, son kare de aşağıda tam hedefle değiştiriliyor; ikisi de atlanıyor
  const points = cells.slice(1, -1).map((cell) => {
    const center = grid.cellCenter(cell);
    return new THREE.Vector3(center.x, 0, center.z);
  });
  const end = goalIsFree ? { x, z } : grid.cellCenter(goal);
  points.push(new THREE.Vector3(end.x, 0, end.z));
  return points;
}

/**
 * object'i path boyunca step kadar ilerlet ve yüzünü gittiği yöne çevir. Varılan noktalar
 * path'ten silinir. Bir noktaya varınca adımın kalanı bir sonrakine harcanır, böylece köşelerde
 * duraklamaz. Bu karede yürüdüyse true döner.
 */
export function followPath(object: THREE.Object3D, path: THREE.Vector3[], step: number): boolean {
  if (path.length === 0) return false;
  while (step > 0 && path.length > 0) {
    const next = path[0];
    toTarget.subVectors(next, object.position);
    toTarget.y = 0;
    const distance = toTarget.length();
    if (distance <= step) {
      object.position.x = next.x;
      object.position.z = next.z;
      path.shift();
      step -= distance;
      continue;
    }
    object.rotation.y = Math.atan2(toTarget.x, toTarget.z); // atan2: x ve z farkından açıyı bulur
    object.position.addScaledVector(toTarget.normalize(), step);
    step = 0;
  }
  return true;
}

/** İki nokta arasındaki yatay (zemindeki) uzaklık; yükseklik farkını saymaz */
export function groundDistance(a: THREE.Vector3, b: THREE.Vector3): number {
  return Math.hypot(a.x - b.x, a.z - b.z);
}
