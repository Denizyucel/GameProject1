import { useStore } from 'zustand';
import { gameStore } from '../state/gameStore';
import { HealthGlobe } from './HealthGlobe';

// Oyunun üstündeki arayüz: başlık, can küresi, minion sayısı, ölüm mesajı ve kontrol ipucu.
// Değerleri oyundan gameStore üzerinden okur; Three.js'e hiç dokunmaz.
export function Hud() {
  // useStore: store'daki bu değer değişince bileşen kendini yeniden çizer
  const health = useStore(gameStore, (s) => s.health);
  const maxHealth = useStore(gameStore, (s) => s.maxHealth);
  const dead = useStore(gameStore, (s) => s.dead);
  const minions = useStore(gameStore, (s) => s.minions);
  const whisper = useStore(gameStore, (s) => s.whisper);

  return (
    <>
      <div className="hud-title">
        <strong>NECRO</strong>
        <span>Faz 1 · sahne</span>
      </div>

      <div className="hud-status">
        <HealthGlobe health={health} maxHealth={maxHealth} />
        <div className="hud-minions">İskelet: {minions}</div>
      </div>

      {/* key değişince React yazıyı yeniden yaratır, CSS animasyonu baştan oynar; sonunda görünmez kalır */}
      {whisper && (
        <div key={whisper.id} className="hud-whisper">
          {whisper.text}
        </div>
      )}

      {dead && (
        <div className="hud-death">
          <strong>Öldün</strong>
          <span>Birazdan yeniden doğacaksın…</span>
        </div>
      )}

      <div className="hud-controls">
        Tıkla veya WASD: yürü · Düşmana tıkla: mührünü kır · 1: cesetten iskelet kaldır · Tekerlek: yakınlaş
      </div>
    </>
  );
}
