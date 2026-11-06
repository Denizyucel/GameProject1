// A* (A yıldız) yol bulma: ızgarada iki kare arasındaki en kısa yolu bulur.
// Three.js'i tanımaz; sadece Grid ile çalışır.
//
// Fikir: başlangıçtan dışa doğru kareleri keşfet. Her adımda
//   f = g (başlangıçtan buraya yürünen yol) + h (buradan hedefe tahmini kalan yol)
// değeri en küçük olan kareyi seç. h tahmini aramayı hedefe doğru yönlendirir;
// bu yüzden A* bütün haritayı taramadan en kısa yolu bulur.

import type { Cell, Grid } from './Grid';

// Çapraz adımın maliyeti: karenin köşegeni, √2 ≈ 1.41
const DIAGONAL_COST = Math.SQRT2;

// 8 komşu: 4 düz (sağ, sol, ileri, geri) + 4 çapraz
const DIRECTIONS: readonly [number, number][] = [
  [1, 0], [-1, 0], [0, 1], [0, -1],
  [1, 1], [1, -1], [-1, 1], [-1, -1],
];

/**
 * start'tan goal'a en kısa yolu döndürür (iki uç dahil).
 * Yol yoksa veya hedef engelliyse null döner.
 */
export function findPath(grid: Grid, start: Cell, goal: Cell): Cell[] | null {
  if (!grid.isWalkable(goal.col, goal.row)) return null;

  const size = grid.cols * grid.rows;
  const key = (col: number, row: number) => row * grid.cols + col;
  const startKey = key(start.col, start.row);
  const goalKey = key(goal.col, goal.row);

  const g = new Float64Array(size).fill(Infinity); // başlangıçtan buraya bilinen en kısa yol
  const f = new Float64Array(size).fill(Infinity); // g + hedefe tahmini kalan
  const cameFrom = new Int32Array(size).fill(-1); // bu kareye hangi kareden gelindi
  const closed = new Uint8Array(size); // 1 = bu kare kesinleşti, bir daha bakma
  const open: number[] = []; // keşfedilmeyi bekleyen kareler

  g[startKey] = 0;
  f[startKey] = heuristic(start.col, start.row, goal);
  open.push(startKey);

  while (open.length > 0) {
    // Bekleyenler içinde f'si en küçük olanı seç. Basit bir tarama; 900 kare için
    // yeterince hızlı. Harita büyürse burası "öncelik kuyruğu" ile hızlandırılır.
    let bestIndex = 0;
    for (let i = 1; i < open.length; i++) {
      if (f[open[i]] < f[open[bestIndex]]) bestIndex = i;
    }
    const current = open[bestIndex];
    open[bestIndex] = open[open.length - 1]; // seçileni listeden çıkar
    open.pop();

    if (current === goalKey) return rebuildPath(grid, cameFrom, goalKey);
    if (closed[current]) continue;
    closed[current] = 1;

    const col = current % grid.cols;
    const row = Math.floor(current / grid.cols);

    for (const [dc, dr] of DIRECTIONS) {
      const nextCol = col + dc;
      const nextRow = row + dr;
      if (!grid.isWalkable(nextCol, nextRow)) continue;

      // Köşe kesme yok: çapraz giderken yandaki iki düz kare de boş olmalı,
      // yoksa karakter engelin köşesinden içeri sürtünerek geçer.
      const diagonal = dc !== 0 && dr !== 0;
      if (diagonal && (!grid.isWalkable(col + dc, row) || !grid.isWalkable(col, row + dr))) continue;

      const nextKey = key(nextCol, nextRow);
      if (closed[nextKey]) continue;

      // Bu komşuya current üzerinden gitmek, bildiğimiz yoldan daha kısa mı?
      const tentative = g[current] + (diagonal ? DIAGONAL_COST : 1);
      if (tentative < g[nextKey]) {
        g[nextKey] = tentative;
        f[nextKey] = tentative + heuristic(nextCol, nextRow, goal);
        cameFrom[nextKey] = current;
        open.push(nextKey);
      }
    }
  }

  return null; // hedefe giden yol yok (etrafı tamamen kapalı)
}

// Hedefe kalan yolun tahmini: engel yokmuş gibi, 8 yönde yürüyerek ("octile" mesafe)
function heuristic(col: number, row: number, goal: Cell): number {
  const dx = Math.abs(col - goal.col);
  const dz = Math.abs(row - goal.row);
  return dx + dz + (DIAGONAL_COST - 2) * Math.min(dx, dz);
}

// Hedeften geriye doğru "nereden geldim" izini takip ederek yolu kur
function rebuildPath(grid: Grid, cameFrom: Int32Array, goalKey: number): Cell[] {
  const path: Cell[] = [];
  for (let k = goalKey; k !== -1; k = cameFrom[k]) {
    path.push({ col: k % grid.cols, row: Math.floor(k / grid.cols) });
  }
  return path.reverse(); // başlangıçtan hedefe sırala
}
