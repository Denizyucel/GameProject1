# Necro — proje bağlamı

## Oyun
Diablo tarzı, tek oyunculu, 3D izometrik hack & slash. İlk oynanabilir sınıf:
Necromancer (minion çağıran büyücü). Tek kişilik bir öğrenme projesi;
iyi olursa yayınlanacak.

## Platform
Tarayıcıda çalışır, macOS için optimize edilir. Safari ve Chrome'da test edilir.
Retina ekranlar hedeflenir.

## Teknoloji
- Vite + TypeScript (strict)
- Three.js: render (sahne, kamera, ışık, modeller)
- React: yalnızca HUD ve menüler
- Zustand: oyun ile HUD arasındaki durum (Faz 5'te eklenecek)
- React Three Fiber kullanılmaz.

## Mimari kurallar
- src/game/ React import etmez; src/hud/ Three.js nesnelerine dokunmaz.
- Oyun durumu düz TypeScript sınıflarında tutulur.
- Oyun döngüsü renderer.setAnimationLoop ile çalışır, React'e bağlanmaz.
- HUD katmanı pointer-events: none; tıklanabilir paneller pointer-events: auto.
- Kamera: OrthographicCamera, izometrik açı.
- Piksel oranı en fazla 2.

## Benimle nasıl çalışmalısın
- Arayüz tasarımcısıyım; oyun geliştirmeye ve TypeScript'e yeniyim.
- Her değişiklikte neyi neden yaptığını kısa ve sade Türkçe ile açıkla.
- Bir seferde tek küçük adım at; çalıştığını doğrulamadan sonrakine geçme.
- Yeni bir kavram kullanırsan (raycaster, quaternion vb.) bir cümleyle anlat.
- Kapsamı büyütme; prototip dışındaki fikirleri "Sonra" listesine öner.

## Şu anki hedef
Faz 1 sahnesi ve tıklayarak hareket tamam (raycaster ile tıklama, delta time
ile yürüme, yumuşak kamera takibi).
Sıradaki: grid + A* yol bulma ile engellerin etrafından dolaşma; mezar taşları
ilk engeller.
Ayrıntılı plan: Necromancer-Baslangic-Plani.md
