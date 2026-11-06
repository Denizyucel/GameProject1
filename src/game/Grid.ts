// Zemini eşit karelere bölen ızgara. Her kare ya yürünebilir ya da engelli.
// Three.js'i tanımaz; sadece sayılarla çalışır. Böylece tarayıcı olmadan da test edilebilir.

/** Izgaradaki bir kare: col = sütun (x yönü), row = satır (z yönü) */
export interface Cell {
  col: number;
  row: number;
}

export class Grid {
  readonly cols: number;
  readonly rows: number;
  readonly cellSize: number;
  // Izgaranın dünyadaki sol-üst köşesi (en küçük x ve z)
  private readonly minX: number;
  private readonly minZ: number;
  // Her kare için bir sayı: 1 = engel, 0 = boş. Kareler satır satır tek bir listeye dizili.
  private readonly blocked: Uint8Array;

  // width/depth: dünya birimi cinsinden boyut. Izgara dünyanın ortasına (0,0) yerleşir.
  constructor(width: number, depth: number, cellSize: number) {
    this.cellSize = cellSize;
    this.cols = Math.round(width / cellSize);
    this.rows = Math.round(depth / cellSize);
    this.minX = -width / 2;
    this.minZ = -depth / 2;
    this.blocked = new Uint8Array(this.cols * this.rows);
  }

  inBounds(col: number, row: number): boolean {
    return col >= 0 && col < this.cols && row >= 0 && row < this.rows;
  }

  isWalkable(col: number, row: number): boolean {
    return this.inBounds(col, row) && this.blocked[this.index(col, row)] === 0;
  }

  /** Dünya noktasının düştüğü kare. Izgaranın dışında olabilir; inBounds ile kontrol et. */
  worldToCell(x: number, z: number): Cell {
    return {
      col: Math.floor((x - this.minX) / this.cellSize),
      row: Math.floor((z - this.minZ) / this.cellSize),
    };
  }

  /** Karenin tam ortasının dünya koordinatı */
  cellCenter(cell: Cell): { x: number; z: number } {
    return {
      x: this.minX + (cell.col + 0.5) * this.cellSize,
      z: this.minZ + (cell.row + 0.5) * this.cellSize,
    };
  }

  /** Bütün kareleri boşalt (engeller baştan kurulacaksa) */
  clear() {
    this.blocked.fill(0);
  }

  /** Dünyada verilen dikdörtgenin dokunduğu bütün kareleri engelli yap */
  blockRect(minX: number, minZ: number, maxX: number, maxZ: number) {
    const from = this.worldToCell(minX, minZ);
    const to = this.worldToCell(maxX, maxZ);
    for (let row = Math.max(0, from.row); row <= Math.min(this.rows - 1, to.row); row++) {
      for (let col = Math.max(0, from.col); col <= Math.min(this.cols - 1, to.col); col++) {
        this.blocked[this.index(col, row)] = 1;
      }
    }
  }

  /** Tek bir kareyi engelli yap */
  block(col: number, row: number) {
    if (this.inBounds(col, row)) this.blocked[this.index(col, row)] = 1;
  }

  /** Dünya noktasına en yakın yürünebilir kare (örneğin mezar taşının üstüne tıklanınca) */
  nearestWalkable(x: number, z: number): Cell | null {
    let best: Cell | null = null;
    let bestDistance = Infinity;
    for (let row = 0; row < this.rows; row++) {
      for (let col = 0; col < this.cols; col++) {
        if (!this.isWalkable(col, row)) continue;
        const center = this.cellCenter({ col, row });
        const distance = (center.x - x) ** 2 + (center.z - z) ** 2;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = { col, row };
        }
      }
    }
    return best;
  }

  // (sütun, satır) → listedeki sıra numarası
  private index(col: number, row: number): number {
    return row * this.cols + col;
  }
}
