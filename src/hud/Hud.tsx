// Oyunun üstündeki arayüz. Şimdilik başlık ve kontrol ipucu; Faz 5'te HP ve mana barları gelecek.
export function Hud() {
  return (
    <>
      <div className="hud-title">
        <strong>NECRO</strong>
        <span>Faz 1 · sahne</span>
      </div>
      <div className="hud-controls">
        Tıkla veya WASD: yürü · Vampire tıkla: vur · 1: ceset dirilt · Tekerlek: yakınlaş
      </div>
    </>
  );
}
