# Necro — proje bağlamı

## Oyun
Diablo tarzı, tek oyunculu, 3D izometrik hack & slash. İlk oynanabilir sınıf:
Necromancer (minion çağıran büyücü). Tek kişilik bir öğrenme projesi;
iyi olursa yayınlanacak.

## Hikaye (kanon: Hikaye.md)
Oyuncu Ruh Kıran: ikiz kardeşi X'in insanlara taktığı altın ölümsüzlük mühürlerini kıran ölüçağıran.
Düşman öldürülmez, mührü kırılır: ruh mavi ışıkla yükselir ("Teşekkür ederiz"), kalan kemikler
gönüllü minion olarak kalkar. Görsel dil ters: altın/ışıltı = tehlike, karanlık/kemik/kırmızı köz =
oyuncunun tarafı, mavi = özgür ruh. Perdeler: Act I Kül Vadisi (boss: Dönüştürülmüş Yüzbaşı),
Act II Güneş Krallığı (sınır kasabası sahnesi; boss: Altın Engizisyoncu), Act III Hafıza Mahzeni
(boss: Ayna Tayfı), Act IV Ebediyet Kulesi (boss: X, 2 evre), Epilog. Harita, karakter ve mekanik
kararlarında önce Hikaye.md'ye bak.
Vampir kavramı bırakıldı: koddaki vampirler (Enemy.ts, Vampire.ts) geçici yer tutucu, yerlerini
Altın Ölümsüzler alacak. Yeni işlerde "vampir" üzerine tasarım yapma.

## Platform
Tarayıcıda çalışır, macOS için optimize edilir. Safari ve Chrome'da test edilir.
Retina ekranlar hedeflenir.

## Teknoloji
- Vite + TypeScript (strict)
- Three.js: render (sahne, kamera, ışık, modeller)
- React: yalnızca HUD ve menüler
- Zustand: oyun ile HUD arasındaki durum (src/state/gameStore.ts; oyun zustand/vanilla ile yazar, HUD useStore ile okur)
- React Three Fiber kullanılmaz.

## Mimari kurallar
- src/game/ React import etmez; src/hud/ Three.js nesnelerine dokunmaz.
- Oyun durumu düz TypeScript sınıflarında tutulur.
- Oyun döngüsü renderer.setAnimationLoop ile çalışır, React'e bağlanmaz.
- HUD katmanı pointer-events: none; tıklanabilir paneller pointer-events: auto.
- Kamera: OrthographicCamera, izometrik açı.
- Piksel oranı en fazla 2.

## Kontroller
Tip kontrolü: `npx tsc --noEmit -p tsconfig.app.json` (kök tsconfig.json boş; `-p .` hiçbir şeyi denetlemez).

## Benimle nasıl çalışmalısın
- Arayüz tasarımcısıyım; oyun geliştirmeye ve TypeScript'e yeniyim.
- Her değişiklikte neyi neden yaptığını kısa ve sade Türkçe ile açıkla.
- Bir seferde tek küçük adım at; çalıştığını doğrulamadan sonrakine geçme.
- Yeni bir kavram kullanırsan (raycaster, quaternion vb.) bir cümleyle anlat.
- Kapsamı büyütme; prototip dışındaki fikirleri "Sonra" listesine öner.

## Şu anki hedef
Faz 1 sahnesi, tıklayarak hareket ve A* yol bulma tamam (src/game/Grid.ts, src/game/findPath.ts;
SHOW_DEBUG ile engelli kareler görünür; düşmanlar hareketli olduğu için ızgarayı engellemiyor).
Bölge: Act I / Yanık Kütüphane, parça setinden kuruluyor (src/game/KitLevel.ts). Parçalar
public/models/kit/*.glb (12 parça; asılları kit-orijinal'de, gltf-transform ile ~10 bin üçgene ve
1024 px dokuya küçültüldü). Yerleşim src/game/levels/yanikKutuphane.ts içinde, plan pikseliyle
(800 x 800 px = 40 x 40 m, 20 px = 1 m; plan: planlar/yanik-kutuphane-ornek.svg). Her parça bir kez
yüklenip kopyalanır, en uzun yatay kenarı PARTS'taki boyuta ölçeklenir. Izgara engeli parçanın
dikdörtgeninden (kemerde sadece iki ayak, ağaçta sadece gövde, kitap yığını engel değil). Zemin
dokulu (ambientCG, public/models/floor): dışarısı toprak, salonun içi (plandaki hall) taş döşeme. Karakter bir parçanın arkasındayken sadece o parça %30 saydam oluyor (her kopyanın kendi malzemesi var).
Doğuş noktası plandaki "dogus" işareti (mühür kaidesinin önü). Eski avlu (Environment.ts,
envoirement.glb) artık kullanılmıyor.
Düşmanlar: 5 vampir (src/game/Enemy.ts davranış, src/game/Vampire.ts model; Mixamo
"Vampire A Lusth.fbx" + Walking.fbx). Evlerinin çevresinde (5 m) rastgele dolaşıyorlar; beklerken
karakterin idle animasyonu, yürürken Walking (root motion kaldırılıp hızına göre ayarlı).
Model yoksa yedek olarak hareketsiz, zararsız mezar taşı.
Dövüş tarzları (src/game/Vampire.ts, STYLES): Avcı, Vahşi, Çevik, Muhafız. Can, hasar, boy,
kovalama hızı (yürüyerek ya da koşarak), pençe (mutant swiping) hızı, mola ve kas gösterisi
(ilk fark edişte) tarza göre değişir.
Kılıç vuruşları (src/game/weapon.ts, SWORD_ATTACK_*: Lite Sword and Shield Pack'in 4 attack'ı) karakter ve
iskeletlerde ortak; vampirler pençe kullanır. attack.fbx sadece karakterde yedek.
Tarzlar karıştırılmış bir torbadan dağıtılır: 5 vampirde 4 tarzın hepsi çıkar. Bekleme duruşu da
rastgele (karakter idle, mutant idle, breathing idle). Animasyonlar "Creature NPC Pack"ten;
mutant dying.fbx bozuk (FBXLoader okuyamıyor), yüklenemezse vampir eskisi gibi devrilir.
Vampirler karşılık veriyor: karakteri 5 m'den fark edip (vurulunca 6 sn kızgın, 12 m'ye kadar)
kovalıyor ve vuruyor; vururken darbe almak vuruşu kesmiyor (kas gösterisini kesiyor).
Can puanla: vampir 22-50 (tarza göre), karakterin vuruşu 10, minionunki 5. Karakterin 100 canı var; HUD'da can
küresi (src/hud/HealthGlobe.tsx; Diablo tarzı, sol alt: boş küre, kayıp can, sıvı ve kafatası çerçeve
katmanları, sıvı clip-path ile boşalır, hasarda kırmızı parlama, üzerine gelince sayı; görseller
public/models/hud/health-globe, asılları orijinal/ içinde, saydamlık sonradan çıkarıldı) ve iskelet sayısı. Can bitince geriye devriliyor, "Öldün" yazısı, 4 sn sonra (0, 0)'da tam
canla doğuyor; vampirler evlerine dönüyor.
Tıklamayı görünmez bir kutu (hitbox) yakalıyor. Vampire bir kez tıklayınca karakter onu kovalıyor
(yol 0.3 sn'de bir yenilenir), menzile girince vuruyor, ölene kadar vurmaya devam ediyor; zemine
tıklamak ya da WASD saldırıyı bırakır. Vurulan vampir sarsılıp kırmızı parlıyor, saldırana dönüp
0.4 sn şaşırıyor. Canı bitince geriye devrilip toprağa gömülüyor.
Karakter Mixamo modeli (Nightshade): idle, walk, attack animasyonları AnimationMixer ile;
her vuruşta "Lite Sword and Shield Pack"in 4 attack animasyonundan rastgele biri oynar (yüklenene
kadar attack.fbx); darbe anı yüklenirken sağ elin en hızlı olduğu an ölçülerek bulunur (weapon.ts, fastestHandMoment);
silah sağ el kemiğine bağlı: Meshy kılıcı (sword.glb), yoksa çizilmiş tırpan. Modeller public/models içinde, Git dışında (lisans).
Kontroller: tıklayarak (A*) ya da WASD/ok tuşlarıyla (ekrana göre, çarpışmalı) yürüme;
tekerlek/pinch ile karaktere doğru yumuşak zoom.
Mühür kırma (çekirdek döngü): düşmanın canı bittiği an (karakter ya da iskelet vurmuş olabilir)
src/game/SealBreak.ts efekti oynar: altın parlama, açılan halka, saçılan altın kıymıklar, ardından
dönerek yükselen mavi ruh parçacıkları (Points; ortografik kamerada boyut pikseldir). HUD'da
"Teşekkür ederiz…" fısıltısı (gameStore.whisper, .hud-whisper CSS animasyonu). Beden gömülünce
yerinde tek ceset kalır: et yığını (src/game/Flesh.ts, flesh.glb; yoksa sırtüstü yatan iskelet).
İskelet otomatik kalkmaz; oyuncu 1 tuşuyla 8 m içindeki en yakın cesetten kaldırır (Magic Spell Pack'ten
rastgele büyü animasyonu, ceset mavi parlar, büyünün yarısında iskelet kalkar, ceset gömülür); iskelet
karakteri A* ile takip eder. Efektin ışığı (altın → mavi,
3 sn'de sönen, 3.5 m menzil) SoulLightPool'dan ödünç alınır: 3 ışık oyun başında sönük kurulur; sahneye
sonradan ışık eklemek bütün shader'ları yeniden derletip takıltır
(src/game/Skeleton.ts: Mixamo'da riglenmiş skeleton.fbx; sağ elinde kılıç (sword2.glb), sol ön
kolunda kalkan (kalkan.glb; weapon.ts prepareSword/prepareShield, attachToHand). Dokuları çok koyu olduğu
için GEAR_* ile parlatılıyor; asıllar public/models/orijinal'de, küçültülmüş halleri models içinde; her vuruşta kılıç vuruşlarından rastgele biri, darbe anı ölçülerek; flesh.glb yoksa ceset olarak T-pozunda yatar;
model yoksa çizilmiş iskelet. src/game/Minion.ts: takip, kendi AnimationMixer'ı).
Minionlar 6 m içindeki en yakın vampire koşup vuruyor (karakterden 10 m'den fazla uzaklaşmıyor),
vampir ölünce takibe dönüyor. Minionların canı yok, vampirler onlara saldırmıyor.
Yol bulma + yolda yürüme ortak: src/game/pathing.ts (planPath, followPath).
Başka Mixamo modellerine karakterin animasyonları src/game/retarget.ts (adaptClip) ile uyarlanır:
kalça konumu boy oranıyla ölçeklenir.
Sıradaki: birlikte kararlaştırılacak.
Ayrıntılı plan: Necromancer-Baslangic-Plani.md

## Sonra
- Yol düzleştirme: ızgara yolundaki gereksiz kırılmaları kaldır (görüş hattı kontrolü)
- Tıklanan yere kısa süreli işaret (Diablo'daki tıklama halkası)
- Fare basılı tutulunca sürekli yürüme
- Harita kenarı: siyah boşluk yerine duvar/sis; gölge alanı karakteri takip etsin
- Sahneye biraz daha ışık; parçalar şu an çok koyu
- planlar/yanik-kutuphane-ornek.svg'yi koda göre güncelle (yüksek duvar, duvar rafı, çatı kemeri yok)
- Bölge çıkışı: "cikis" işaretine gelince sonraki bölgeye (Kül Yolu) geçiş
- Kullanılmayan Environment.ts'yi sil
- A* açık listesini öncelik kuyruğuna çevir (harita büyüyünce)
- Vuruşta kan/parça efekti, ekran sarsıntısı gibi vuruş hissi efektleri
- İskelete yerden kalkma (Standing Up) ve kendine özgü (zombi) yürüme animasyonu
- skeleton.fbx'i hafiflet (278 bin üçgen; çok minionda ağırlaşır)
- Minion sayısı sınırı
- Vampire kendi animasyonları (vurulma, ölüm) ve can barı
- Hareketli çarpışma: karakter, vampir ve minionlar birbirinin içinden geçmesin
- Minionların canı olsun, vampirler minionlara da saldırsın
- Can yenilenmesi (iksir ya da zamanla), mana ve diriltmenin mana maliyeti
- Karakter için ölüm ve vurulma animasyonu (şimdi sadece devriliyor)
- Walking.fbx'i Without Skin indir (15 MB → ~0.5 MB)
- Mühür kırılma sesi (cam kırılması) ve fısıltı sesi
- Minionlar birbirinin ve karakterin içinden geçmesin
