// Oyun ile HUD arasındaki ortak durum (Zustand).
// Oyun (src/game) buraya yazar, HUD (src/hud) buradan okur. İkisi birbirini hiç tanımaz.
// "zustand/vanilla" React'e bağlı değil; bu yüzden oyun kodu React import etmeden kullanabilir.

import { createStore } from 'zustand/vanilla';

export interface GameState {
  health: number; // karakterin şu anki canı
  maxHealth: number;
  dead: boolean; // karakter öldü mü (yeniden doğmayı bekliyor)
  minions: number; // kaç minion var
}

export const gameStore = createStore<GameState>(() => ({
  health: 100,
  maxHealth: 100,
  dead: false,
  minions: 0,
}));
