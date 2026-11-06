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
Faz 1 sahnesi, tıklayarak hareket ve A* yol bulma tamam. Karakter mezar
taşlarının etrafından dolaşıyor (src/game/Grid.ts, src/game/findPath.ts;
SHOW_DEBUG ile engelli kareler ve yol görünür).
Karakterin tırpanı var: taşa tıklayınca yanına yürüyüp vuruyor, taş sarsılıp
parlıyor, vuruş sayısı tutuluyor.
Taşların 3 vuruşluk canı var; kırılınca toprağa gömülüp siliniyor, ızgara yeniden kuruluyor.
Sıradaki: birlikte kararlaştırılacak (ilk minion ya da ilk düşman).
Ayrıntılı plan: Necromancer-Baslangic-Plani.md

## Sonra
- Yol düzleştirme: ızgara yolundaki gereksiz kırılmaları kaldır (görüş hattı kontrolü)
- Tıklanan yere kısa süreli işaret (Diablo'daki tıklama halkası)
- Fare basılı tutulunca sürekli yürüme
- Harita kenarı: siyah boşluk yerine duvar/sis; gölge alanı karakteri takip etsin
- A* açık listesini öncelik kuyruğuna çevir (harita büyüyünce)
- Kırılan taştan saçılan parçalar, ekran sarsıntısı gibi vuruş hissi efektleri
