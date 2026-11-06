import { useStore } from 'zustand';
import { gameStore } from '../state/gameStore';

// Oyunun üstündeki arayüz: başlık, can barı, minion sayısı, ölüm mesajı ve kontrol ipucu.
// Değerleri oyundan gameStore üzerinden okur; Three.js'e hiç dokunmaz.
export function Hud() {
  // useStore: store'daki bu değer değişince bileşen kendini yeniden çizer
  const health = useStore(gameStore, (s) => s.health);
  const maxHealth = useStore(gameStore, (s) => s.maxHealth);
  const dead = useStore(gameStore, (s) => s.dead);
  const minions = useStore(gameStore, (s) => s.minions);
  const percent = (health / maxHealth) * 100;

  return (
    <>
      <div className="hud-title">
        <strong>NECRO</strong>
        <span>Faz 1 · sahne</span>
      </div>

      <div className="hud-status">
        <div className="hud-health" aria-label={`Can ${health} / ${maxHealth}`}>
          <div className="hud-health-fill" style={{ width: `${percent}%` }} />
          <span className="hud-health-text">
            {health} / {maxHealth}
          </span>
        </div>
        <div className="hud-minions">İskelet: {minions}</div>
      </div>

      {dead && (
        <div className="hud-death">
          <strong>Öldün</strong>
          <span>Birazdan yeniden doğacaksın…</span>
        </div>
      )}

      <div className="hud-controls">
        Tıkla veya WASD: yürü · Vampire tıkla: saldır · 1: ceset dirilt · Tekerlek: yakınlaş
      </div>
    </>
  );
}
