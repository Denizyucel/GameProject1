import { useEffect, useRef, useState } from 'react';

// Diablo tarzı can küresi. Dört görsel katman üst üste durur (alttan üste):
//   1. boş küre (koyu cam)
//   2. "kayıp" sıvı: hasarda bir an açık renkte kalıp sonra iner, ne kadar can gittiğini gösterir
//   3. sıvı: can kadar dolu
//   4. çerçeve ve kafatası (kafatası sıvının önünde kalır)
// Sıvı, clip-path ile üstten kesilerek boşaltılır: can azaldıkça kesilen kısım büyür.
// Görseller: public/models/hud/health-globe (asılları orijinal/ içinde).

const BASE = '/models/hud/health-globe/';
// Kürenin görsel içindeki yeri (320 px'lik görselde ölçüldü): üst kenarı 81 px, çapı 157 px.
// Yüzde olarak tutuluyor ki görsel hangi boyutta gösterilirse gösterilsin doğru kessin.
const GLOBE_TOP = (81 / 320) * 100;
const GLOBE_HEIGHT = (157 / 320) * 100;

// Sıvının üstünden ne kadar kesileceği: can doluysa sadece kürenin üstündeki boşluk, boşsa hepsi
function clipFor(fill: number): string {
  const top = GLOBE_TOP + GLOBE_HEIGHT * (1 - fill);
  return `inset(${top}% 0 0 0)`;
}

export function HealthGlobe({ health, maxHealth }: { health: number; maxHealth: number }) {
  const fill = Math.max(0, Math.min(1, health / maxHealth));

  // Can azaldığında kısa kırmızı parlama: her hasarda sayaç artar, parlama baştan oynar
  const previous = useRef(health);
  const [hits, setHits] = useState(0);
  useEffect(() => {
    if (health < previous.current) setHits((count) => count + 1);
    previous.current = health;
  }, [health]);

  return (
    <div className="hud-globe" aria-label={`Can ${health} / ${maxHealth}`}>
      <img className="hud-globe-layer" src={`${BASE}globe-empty.png`} alt="" />
      <img
        className="hud-globe-layer hud-globe-lost"
        src={`${BASE}globe-liquid.png`}
        alt=""
        style={{ clipPath: clipFor(fill) }}
      />
      <img
        className="hud-globe-layer hud-globe-liquid"
        src={`${BASE}globe-liquid.png`}
        alt=""
        style={{ clipPath: clipFor(fill) }}
      />
      {hits > 0 && <div key={hits} className="hud-globe-flash" />}
      <img className="hud-globe-layer" src={`${BASE}globe-frame.png`} alt="" />
      <span className="hud-globe-text">
        {health} / {maxHealth}
      </span>
    </div>
  );
}
