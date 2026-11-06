import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { Game } from './game/Game';
import { Hud } from './hud/Hud';
import './index.css';

// Oyun ve HUD ayrı ayrı başlıyor: oyun #game'e, React arayüzü #hud'a
const game = new Game(document.getElementById('game')!);
game.start();

createRoot(document.getElementById('hud')!).render(
  <StrictMode>
    <Hud />
  </StrictMode>,
);
