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
Faz 1 sahnesi, tıklayarak hareket ve A* yol bulma tamam (src/game/Grid.ts, src/game/findPath.ts;
SHOW_DEBUG ile engelli kareler görünür; şu an sabit engel yok, düşmanlar hareketli olduğu için
ızgarayı engellemiyor).
Düşmanlar: 5 vampir (src/game/Enemy.ts davranış, src/game/Vampire.ts model; Mixamo
"Vampire A Lusth.fbx" + Walking.fbx). Evlerinin çevresinde (5 m) rastgele dolaşıyorlar; beklerken
karakterin idle animasyonu, yürürken Walking (root motion kaldırılıp hızına göre ayarlı).
Model yoksa yedek olarak hareketsiz mezar taşı. Henüz karşılık vermiyorlar.
Tıklamayı görünmez bir kutu (hitbox) yakalıyor. Vampire bir kez tıklayınca karakter onu kovalıyor
(yol 0.3 sn'de bir yenilenir), menzile girince vuruyor, ölene kadar vurmaya devam ediyor; zemine
tıklamak ya da WASD saldırıyı bırakır. Vurulan vampir sarsılıp kırmızı parlıyor, saldırana dönüp
1.6 sn duruyor. 3 vuruşta geriye devrilip toprağa gömülüyor.
Karakter Mixamo modeli (Nightshade): idle, walk, attack animasyonları AnimationMixer ile;
silah sağ el kemiğine bağlı: Meshy kılıcı (sword.glb), yoksa çizilmiş tırpan. Modeller public/models içinde, Git dışında (lisans).
Kontroller: tıklayarak (A*) ya da WASD/ok tuşlarıyla (ekrana göre, çarpışmalı) yürüme;
tekerlek/pinch ile karaktere doğru yumuşak zoom.
Ölü diriltme: ölen vampir 1-2 et yığını (flesh.glb, src/game/Flesh.ts) bırakır; 1 tuşu en yakın
yığını (8 m içinde) diriltir. Karakter Magic Spell Pack'ten rastgele bir büyü animasyonu oynar,
yığın yeşil parlar, içinden iskelet minion topraktan çıkar, yığın toprağa gömülür; minion karakteri A* ile takip eder
(src/game/Skeleton.ts: Mixamo'da riglenmiş skeleton.fbx; flesh.glb yoksa ceset olarak T-pozunda yatar;
model yoksa çizilmiş iskelet. src/game/Minion.ts: takip, kendi AnimationMixer'ı).
Başka Mixamo modellerine karakterin animasyonları src/game/retarget.ts (adaptClip) ile uyarlanır:
kalça konumu boy oranıyla ölçeklenir.
Sıradaki: birlikte kararlaştırılacak (vampirler karşılık versin mi, minionlar saldırsın mı).
Ayrıntılı plan: Necromancer-Baslangic-Plani.md

## Sonra
- Yol düzleştirme: ızgara yolundaki gereksiz kırılmaları kaldır (görüş hattı kontrolü)
- Tıklanan yere kısa süreli işaret (Diablo'daki tıklama halkası)
- Fare basılı tutulunca sürekli yürüme
- Harita kenarı: siyah boşluk yerine duvar/sis; gölge alanı karakteri takip etsin
- A* açık listesini öncelik kuyruğuna çevir (harita büyüyünce)
- Vuruşta kan/parça efekti, ekran sarsıntısı gibi vuruş hissi efektleri
- İskelete yerden kalkma (Standing Up) ve kendine özgü (zombi) yürüme animasyonu
- skeleton.fbx'i hafiflet (278 bin üçgen; çok minionda ağırlaşır)
- Minion sayısı sınırı ve mana; yakında ceset yoksa HUD'da uyarı
- Vampire kendi animasyonları (vurulma, ölüm) ve can barı
- Hareketli çarpışma: karakter, vampir ve minionlar birbirinin içinden geçmesin
- Walking.fbx'i Without Skin indir (15 MB → ~0.5 MB)
- Diriltme büyüsü için ışık/parçacık efekti
- Minionlar birbirinin ve karakterin içinden geçmesin
