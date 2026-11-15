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
Vampir kavramı bırakıldı: tarayıcı sürümündeki vampirler (Enemy.ts, Vampire.ts) geçici yer tutucuydu;
Godot sürümünde yerlerini enemy1.glb düşmanları aldı (ileride Altın Ölümsüzler). Yeni işlerde
"vampir" üzerine tasarım yapma.

## Platform
Tarayıcıda çalışır, macOS için optimize edilir. Safari ve Chrome'da test edilir.
Retina ekranlar hedeflenir.

## Teknoloji
- Vite + TypeScript (strict)
- Three.js: render (sahne, kamera, ışık, modeller)
- React: yalnızca HUD ve menüler
- Zustand: oyun ile HUD arasındaki durum (src/state/gameStore.ts; oyun zustand/vanilla ile yazar, HUD useStore ile okur)
- React Three Fiber kullanılmaz.

## Godot 4 geçişi (devam ediyor)
Oyun Godot 4.7'ye taşınıyor (asıl hedef masaüstü/Steam; tarayıcı ikinci planda). Godot projesi
godot/ klasöründe; Three.js sürümü (src/) taşıma bitene kadar başvuru olarak duruyor.
- Godot: /Applications/Godot.app, komut satırı `godot` (Homebrew cask). Renderer: Forward+
  (web dışa aktarımı Compatibility ister; o zaman değiştirilecek).
- godot/assets/: modeller ve dokular public/models'tan KOPYALANIR (git dışında, lisans).
  Yeni dosya eklenince: `godot --headless --path godot --import`.
- godot/levels/yanik_kutuphane.tscn: bölge (tools/build_yanik_kutuphane.gd ile plandan bir kez üretildi;
  artık editörde düzenlenir, betiği yeniden çalıştırmak üzerine yazar). Her parça: konum/dönüş tutan
  bir Node3D ve içinde ölçeklenmiş .glb örneği ("Model").
- Meshy modellerinin hepsi "metal" işaretli (metal oranı dokuda). Metal yüzeyler yansıtacak bir şey
  bulsun diye ortamda sadece yansıma için koyu gri bir ProceduralSky var (arka plan ve genel ışık renkten);
  açık gökyüzü zemini puslandırıyordu.
- godot/main.tscn: ortam ışığı, ay ışığı (gölgeli), Gezinme (NavigationRegion3D; içinde bölge),
  Player, ortografik izometrik kamera (camera_follow.gd: takip, tekerlek/pinch zoom).
- Navmesh: levels/act1_nav.tres (ajan 0.4 m yarıçap, 1.8 m boy, 0.25 m tırmanma). Bölgede
  parça taşıyınca yeniden çıkar: `godot --path godot -s tools/bake_navmesh.gd` ya da editörde Gezinme →
  Bake NavigationMesh. Navmesh zeminden 0.5 m yukarıda çıkıyor; ajanın path_height_offset'i 0.5.
- characters/player.tscn + player.gd: yeni Necromancer (assets/character/necromancer-kadin.glb; Meshy
  "SmartRig", Mixamo kemik adları + 23 etek/saç kemiği, eli: başparmak/orta/serçe, işaret parmağı YOK;
  1.7 m, 1.176 ölçekle 2 m). Mixamo'ya yüklemeye gerek yok (yüklenirse ek kemikler kaybolur).
  Bekleme: Nightshade'in idle.fbx'i; hareket: modelin kendi "Running"i (yürüme animasyonları yerinde
  yürüyor ve ayakları ~1.8 m/sn taşıyor, 3 m/sn'de kayıyordu; koşu 3.1 m/sn). Animasyon hızı ayaktan
  ölçülür (player.gd stride_speed: sol ayağın bir döngüdeki ileri-geri menzili × 2 / süre). player.gd her animasyonu modelin
  iskeletine uyarlar (iz yolu + kalça yüksekliği oranı); dosya ve ad Inspector'dan (idle_file/walk_file).
  Yeni Mixamo animasyonu: herhangi bir Mixamo karakteriyle "Without Skin" indir, olduğu gibi çalışır.
  Nightshade (nightshade.fbx) assets'te duruyor. Kılıç: assets/weapons/sword.glb sağ elde
  (characters/weapon.gd: Weapon.prepare_sword, Weapon.attach_to_hand → BoneAttachment3D + pivot;
  işaret parmağı yoksa orta parmak kullanılır; 1.1 m, kabzadan %89).
  Vuruş: Shift + sol tık → yerinde, tıklanan yöne dönüp assets/animations/sword/attack*.fbx'ten rastgele
  biri (1.3 kat hızlı, root motion kilitli); vururken yürümez ve yeni tık almaz. Henüz hasar/darbe anı yok.
  Deneme: `godot --path godot --resolution 1280x720 -s tools/attack_test.gd -- <klasör>`. Yürümede kalçanın root motion'ı silinir, hız animasyona
  uydurulur; sol tık → zemin düzlemine ışın → NavigationAgent3D hedefi, 3 m/sn, yumuşak dönüş.
- Kontrol betikleri (pencere kısa süre açılır):
  `godot --path godot --resolution 1280x720 -s tools/screenshot.gd -- <çıktı.png> 90`;
  `... -s tools/walk_test.gd -- <klasör> <tık x> <tık y>` (sahte tık, yol ve iki ekran görüntüsü);
  `godot --headless --path godot -s tools/inspect.gd -- res://...fbx` (model ağacı, animasyonlar).
- WASD/oklar: ekrana göre yön (fiziksel tuş, klavye düzeninden bağımsız), adım navmesh'in en yakın
  noktasına çekilir (duvar boyunca kayar), tıklanan hedefi iptal eder. Önü kapalıysa (adımın %80'inden azı
  gidilebiliyorsa) player.keys_detour ileriye bakar (1-4 m, KEYS_LOOK): orası yürünebilir ve oraya giden yol düz
  uzaklığın 2.2 katından (KEYS_DETOUR) kısaysa yolun ilk köşesine yürür; böylece kapıya çapraz basınca da
  kapıdan süzülür. Seçilen dolanma yönü 0.3 sn korunur, neredeyse tam geriye dönen dolanma atılmaz (engele
  yaslanınca titremesin). Navmesh yatayda sorulur (player.walkable_below / navmesh_below: dikey çizgiye en
  yakın nokta): salonun içi dışından ~0.25 m yüksek, 3B "en yakın nokta" kapı eşiğinde hep içeriyi seçip
  karakteri dışarı bırakmıyordu. Deneme: tools/keys_test.gd.
- HUD: hud/hud.tscn (CanvasLayer; main.tscn'de, player'a bağlı). Can küresi hud/health_globe.gd +
  globe_fill.gdshader (sıvıyı üstten keser; brightness, flash); görseller assets/hud. Can küresinin
  çerçevesi (globe-frame.png, asılları public/models/hud/health-globe) 455 x 413, solunda kanatlı figür;
  CanKuresi 284 x 258 px, 320 x 320'lik küre katmanları (globe-liquid/globe-empty = *-without-frame.png)
  çerçevenin sağ altına oturur (anchor 0.2967, 0.2252 → 1, 1). Boş küre %20 opak açık gri cam (mana da
  aynısını kullanır). Oyuncunun canı
  player.gd'de (max_health 100, take_damage, health_changed sinyali). Pencere ölçeklemesi canvas_items
  (arayüz 1280x720'ye göre büyür). Deneme: tools/hud_test.gd.
- Deneme betiklerinde ekran görüntüsünden önce `await RenderingServer.frame_post_draw` gerekir; yoksa
  arayüzün eski hali kaydedilebiliyor. Sahte fare/tuş olayları pencere odağını kaybedince bırakılabilir.
- Dosyaları ben değiştirirken editör açıksa Godot "diskte değişti, yeniden yükle?" diye sorar: yeniden yükle
  (yoksa editördeki eski hali kaydedip değişikliklerin üstüne yazar).
- Düşmanlar (vampirlerin yerine): enemies/enemy.tscn + enemy.gd, model assets/enemies/enemy1.glb (Meshy
  SmartRig, gümüş zırhlı pençeli şövalye; altın değil). main.tscn'de Dusmanlar altında 5 tane (eski
  vampir yerleri). Vampirlerin davranışı aynen: 5 m'de dolaşma, 5 m'den fark etme, vurulunca 6 sn kızgın
  ve 12 m'ye kadar kovalama, pençe (mutant-swiping, darbe anı ölçülür), 4 dövüş tarzı torbadan (STYLES:
  can, hasar, boy, kovalama animasyonu/hızı, pençe hızı, mola, kas gösterisi). Animasyonlar ilk
  düşmanda bir kez hazırlanıp hepsi arasında paylaşılır (static shared_library). Vurulunca
  material_overlay ile kırmızı parlar, 0.4 sn şaşırır (8'den hafif vuruşta, yani iskeletinkinde, şaşırmaz:
  STUN_MIN_DAMAGE; yoksa 5 iskelet düşmanı kilitliyordu). Ölüm: mutant-dying.fbx (Godot okuyabiliyor; 1.5 kat
  hızlı), bedeni yere vardığı an (RigAnimations.landing_moment, kalçanın en alçağa indiği an) 0.7 sn'de
  saydamlaşıp silinir, yerinde ceset aynı sürede belirir (GeometryInstance3D.transparency); seal_broken sinyali gönderir (mühür kırma efekti buna bağlanacak).
  Gruplar: "dusman" (canlı düşmanlar), "oyuncu".
- Oyuncu dövüşü: Shift + tık vuruşunun darbe anında (sağ elin en hızlı anı) önündeki 2.2 m içindeki
  en yakın düşmana 10 hasar. Can 0 → ölüm animasyonu, HUD'da "Öldün", 4 sn sonra doğuş noktasında tam can.
  Ortak animasyon işleri: characters/rig_animations.gd (RigAnimations: take, remove_root_motion,
  stride_speed, fastest_hand_moment, step_along_path). Deneme: tools/combat_test.gd.
- Mühür kırma: main.gd (Main'in betiği) düşmanların seal_broken sinyalini dinler →
  effects/seal_break.tscn (+ .gd): altın parlama küresi ve halka (kodla), Kiymiklar (GPUParticles3D, 16
  altın prizma, yerçekimli), Ruh (GPUParticles3D, 70 mavi nokta, halkadan yukarı hızlanarak ve dönerek;
  0.15 sn gecikmeli), OmniLight3D (altın → mavi, 3 sn'de söner, 3.5 m). Parçacık ayarları editörde
  sahneden. release = true: altınsız (serbest bırakılan iskelet için).
  Düşman ölümünde with_soul = false (kullanıcı istedi): yalnızca altın kırılma (parlama, halka, kıymıklar, altın ışık)
  ve sarsıntı; mavi ruh noktaları ve "Teşekkür ederiz" fısıltısı yok (main.on_seal_broken). İskelet serbest kalırken
  (release) ruh duruyor. HUD.whisper başka işler için duruyor. 3.2 sn sonra kendini siler.
  HUD.whisper(metin): Fisilti etiketi (italik SystemFont, mavi parıltı), belirip yukarı süzülerek kaybolur.
  Godot Forward+'ta sahneye ışık eklemek shader derletmez; ışık havuzu gerekmedi.
  Deneme: tools/seal_test.gd (efektin kendi saatine göre görüntü alır; ekran görüntüsü oyunu dondurur ve
  Godot o süreyi oyun zamanına saymaz, duvar saatine göre beklemek yanıltır).
- Ceset ve iskeletler (main.gd yönetir): düşman yere düşünce buried sinyali → minions/corpse.tscn (flesh.glb,
  1.1 m, rastgele yön, "ceset" grubu). 1 tuşu (fiziksel; numpad 1 de): oyuncu 8 m içindeki en yakın cesede
  döner, Magic Spell Pack'ten rastgele büyü (assets/animations/spell/spell1-12.fbx, 1.5 kat hızlı;
  player.start_cast/cast_progress/is_busy); ceset ilk yarıda mavi parlar, yarısında iskelet kalkar, ceset
  gömülür. minions/minion.tscn + minion.gd: skeleton.fbx (1.8 m, 1.05 ölçek), sağda sword2.glb, sol ön
  kolda kalkan.glb (Weapon.prepare_shield, facing -1; Weapon.brighten ile 1.8 kat parlak, metal 0.5).
  Animasyonlar paylaşılır: idle.fbx, koşu = yeni Necromancer'ın "Running"i, 4 kılıç vuruşu (1.5 kat, darbe
  anı ölçülür). Topraktan 0.9 sn'de mavi parıltıyla yükselir; oyuncuyu takip eder (altın açılı yer, 1.6 m;
  3 m'den uzaklaşınca, 3.4 m/sn); 6 m içindeki ve oyuncudan 10 m'den yakın düşmana koşup vurur (5 hasar,
  0.5 sn mola). En fazla 5 (MAX_MINIONS); fazlasında rastgele biri seal_break release efektiyle yok olur.
  İskeletlerin canı var (minion.MAX_HEALTH 40, take_damage, vurulunca kırmızı parlar; topraktan çıkana kadar
  alive false). Düşmanlar 0.3 sn'de bir rakip seçer (enemy.pick_foe): oyuncu ve "iskelet" grubundan 5 m içindeki
  en yakını (şu anki 1 m avantajlı; kızgınken 12 m); pençe rakibe vurur. Canı biten iskelet fell sinyali →
  main.release_minion (mavi release efekti, HUD sayısı düşer). Deneme: tools/minion_test.gd (5. adım).
  Ayaktaki iskelet sayısı HUD'da mana küresinin kafatasının üstündeki rozette (ManaKuresi/Rozet; HUD.set_minions; yazı tipi godot/fonts/AguafinaScript-Regular.ttf, 16 px, 3.5 px aşağı kaydırılmış: el yazısının taban çizgisi rakamı yukarıda bırakıyordu; kürelerin üzerine gelince çıkan "100 / 100" sayısı da aynı yazı tipiyle, 15 px; OFL lisanslı, Git'te). Deneme: tools/minion_test.gd.
- Düşmana tıklayarak dövüş: player.enemy_under_cursor ekranda düşmanın ayağından 2 m yukarısına uzanan
  çizgiye bakar (0.6 m yarıçap, fizik/çarpışma kutusu yok). Tıklanan düşman attack_target olur: oyuncu
  kovalar (yol 0.3 sn'de bir), 1.7 m'ye yetişince vurur, ölene kadar vuruşları zincirler; zemine tık ya da
  WASD bırakır. Darbe önce kovalanan düşmana gider. Deneme: tools/click_fight_test.gd (gerçek tık).
- Kemik mızrağı (sağ tık; Mac'te Ctrl + tık da): player.start_spear → Magic Spell Pack'in 1H Magic
  Attack 01-03'ünden (spell1-3) biri 1.8 kat hızlı; elin en hızlı anında effects/bone_spear.tscn fırlar
  (göğüs hizası, 0.6 m önden). Mızrak: kemik beyazı koni + kırmızı köz izi (GPUParticles3D) + kırmızı ışık;
  16 m/sn, 14 m menzil, yolundaki her düşmana bir kez 15 hasar (delip geçer); altı navmesh'ten 0.6 m'den
  uzaksa duvara çarpmış sayılıp kırılır (kitap yığını gibi alçak engellerde de kırılır). Bekleme 0.8 sn,
  mana yok. Deneme: tools/spear_test.gd (gerçek sağ tık).
- X (açılış ara sahnesi için, Hikaye.md "Açılış: X gece mühürleri çalar, kütüphaneyi yakar"):
  assets/x/x.glb (Meshy SmartRig; kıvırcık saçlı genç erkek, turkuaz-altın zırh, yere kadar altın
  pelerin, pelerin gövdeyle tek parça; 1.7 m, 1.176 ölçekle 2 m). İçindeki animasyonlar: Walking,
  Running, Clapping_Run (14 sn), Walking_Scan_with_Sudden_Look_Back (7 sn, root motion'lı: kendisi
  ilerler, etrafı tarayıp arkasına bakar).
- Açılış ara sahnesi: cutscenes/acilis.tscn + acilis.gd; projenin başlangıç sahnesi bu (run/main_scene).
  Gece ortamı (koyu, glow açık), aynı yanik_kutuphane.tscn. Zaman çizelgesi Senaryo (AnimationPlayer)
  "acilis", 30 sn: kamera konumu/boyu (kesmelerde doğrusal geçiş; kübik geçiş sıçramada taşıp boyu
  eksiye düşürüyordu), X konumu/dönüşü, mühürlerin yükselmesi, mühür ışığı, kararma, ve "Call Method" izi:
  x_play(ad, hız), seals_reverse (gümüş → altın), seals_absorb (X'e uçar), fire_wave (altın kıvılcımlar
  10 rafa yayla uçar, effects/fire.tscn tutuşur: alev + duman parçacıkları + titreyen turuncu ışık),
  finish. Akış: 0-6 kaidede üç dik gümüş mühür, 6-15 X güney kapıdan kaideye yürür, 15-18 kaidenin
  önünde bekler, 18-21 büyü (spell4), mühürler yükselip altına döner ve X'e çekilir, 22 yangın, 24-30 X
  yanan kütüphaneden çıkar, kararma. Ruh Kıran ara sahnede görünmez (kullanıcı istedi). Esc ya da tık:
  geç. Bitince MainScene.after_intro = true → main.tscn; Ruh Kıran uyumaz: player.enter_scene ile güney
  kapıdan (0, 0, 8) salonun ortasına (0, 0, -5) kendiliğinden yürür (bu sırada kontrol yok), varınca
  arrived sinyali → HUD.say("Buraya ne oldu böyle?") (Konusma etiketi, altta alt yazı). Yanan 10 raf
  (MainScene.FIRE_POINTS; ara sahne de bunları kullanır) oyunda da yanmaya devam eder: main.gd her
  açılışta effects/fire.tscn koyar. main.gd class_name MainScene. Deneme: tools/cutscene_test.gd.
  Oyunu ara sahnesiz denemek: editörde main.tscn açıkken F6 (Run Current Scene).
- Harita tek parça (geçiş/yükleme yok): main.tscn'de Gezinme altında YanikKutuphane ve hemen güneyinde
  KulYolu (z = 40'a kaydırılmış; ikisi de 40 x 40 m). Navmesh ikisini birlikte kapsar:
  levels/act1_nav.tres. Yanık Kütüphane düşmansız (Hikaye.md), 10 raf yanıyor. Kül Yolu
  (levels/kul_yolu.tscn, tools/build_kul_yolu.gd ile bir kez üretildi; artık editörde): kuzeyi
  kütüphaneye açık (ikinci kapı kaldırıldı), yolun iki yanında yıkık duvar, sütun, moloz, kuru ağaç; zemin kütüphanenin dışıyla aynı
  malzeme (renk farkı sınırda çizgi yapıyordu): materials/disarisi.tres (ShaderMaterial,
  materials/zemin.gdshader): her yer çimen assets/floor/cimen (Grass001), üstünde toprak
  assets/floor/zemin (Ground110) bir yol; ikisi de public/models/floor'dan kopya. Yol: road_points (dünya
  x, z), kütüphanenin kapısından (0, 6.9) Kül Yolu'nun güney ucuna (0, 60) kıvrılarak iner; road_width 3.6,
  kenarlar gürültüyle düzensiz (edge_wobble). Yolu değiştirmek: disarisi.tres → Inspector → road_points.
  Yol dışına sonradan kuru ağaçlar eklendi (kütüphane bölgesinde 69, Kül Yolu'nda 83; harita kenarlarında
  sık orman; build betiklerinde yok). Kit'in agaclar/ klasöründen büyük dallı ağaç agac2.glb (18 bin
  üçgen, ~6.5 m; 0.6 ölçek, gövde modelin kökünde) de serpiştirildi: kütüphanede 13, Kül Yolu'nda 10 ("agac2-N";
  yoldan 5 m uzak). agac3.glb: yapraksız kahverengi ağaç (2.2 bin üçgen, 10.8 m; dokusuz, tek malzeme "kabuk";
  0.6 ölçek; kullanıcı eski yapraklı agac3'ü bununla değiştirdi, agac4'ü sildi). props/agac3.tscn glb'yi sarar;
  sahnelerde bu props sahnesi kullanılır ("agac3-N": kütüphanede 8, Kül Yolu'nda 8, Harabe Köy kenarında 5, Cevre'de 45).
  agac1.glb kuru-agac.glb ile aynı dosya. ~3 milyon üçgen.
  Gotik bina: assets/kit/bina/bina1.glb (25.5 x 22.5 m taş meydanlı kapalı yapı, 13.6 m, 22 bin üçgen; turuncu
  pencereler, çatıda ateş kaseleri; içine girilmez). levels/gotik_bina.tscn (main.tscn'de Gezinme/GotikBina;
  navmesh'e girer: meydan yürünür, bina engel): Parcalar/bina1 Kül Yolu'nun batısında (-32.5, 0, 40), +90°
  dönük, kapısı (dünyada -26.5, 40) yola bakar; Kopru: Kül Yolu'nun kenarıyla (x = -20) meydan (x = -21.5)
  arasına zemin; yalnızca navmesh için, görünmez (visible = false; görünürken meydanla üst üste binip z-fighting ile
  titriyordu, kullanıcı "titreyen gölge" sandı; navmesh betiği gizli mesh'i yine okur). Altındaki 68 Cevre ağacı/taşı kaldırıldı. Saydamlaşmaya eklenmedi: kutusu meydanı da
  kapsadığı için meydandaki oyuncu bütün binayı saydamlaştırıyordu. Ara sahnede bina yok.
  Görüş penceresi (köydeki gibi): levels/building_window.gd (GotikBina'nın betiği) açılışta binanın 10 malzemesini
  aynı renk/doku/ışımayla materials/pencere.gdshader'a çevirir; oyuncu binanın merkezine 20 m'den yakınken
  binanın önünde kalan kısmı karakterin çevresinde noktalı silinir. Deneme: tools/building_window_test.gd.
  (Not: .tscn'de Transform3D satır satır yazılır: +90° y dönüşü = (0, 0, 1, 0, 1, 0, -1, 0, 0).)
  Binaya patika: zemin.gdshader'da ikinci çizgi (path_points, path_count, path_width 2.2; kenarı yolun yarısı
  kadar oynar). disarisi.tres: yoldan (0.5, 40) meydanın kenarına (-23, 40) kıvrılır. Üstündeki 5 kuru ağaç ve moloz-1
  (Kül Yolu) kaldırıldı. road_count 12'den 11'e düzeltildi (11 nokta var). Deneme: oyuncu yoldan kapıya
  (-24.8, 40) yürür.
  Harita kenarında siyah boşluk yok: levels/cevre.tscn (main.tscn'de Cevre; Gezinme'nin DIŞINDA, navmesh'e
  girmez, oyuncu oraya yürüyemez): 120 x 160 m DisZemin (aynı disarisi.tres, y = -0.02) ve oynanan alanın
  çevresinde 30 m'lik orman (711 ağaç; ilk 12 m sık). 30 m = en uzak zoom'da (0.6) ekranın gördüğü kadar;
  MIN_ZOOM küçülürse halka da büyümeli. Yol güneye z = 101'e kadar devam eder (road_count 13). Ara sahnede
  (acilis.tscn) de KulYolu (z = 40) ve Cevre var; kenarlar orada da siyah değil.
  Harabe Köy (Act I 3. bölge; dünya x -20..20, z 60..104): tek parça köy modeli assets/kit/koy.glb (asıl
  public/models/kit/koy.glb 2.6 milyon üçgen, 80 MB; gltf-transform weld → simplify --ratio 0.03 --error 0.002 →
  resize 2048 ile 77 bin üçgen, 4.7 MB). levels/koy.tscn (main.tscn'de Koy; Gezinme'nin DIŞINDA): Zemin (düz
  çimen) + Model (18 ölçek, 90° dönük: kilise kuzeybatıda yüksekte, giriş kuzeyden x ~3, meydan x -4..10,
  z 72..79; batıya doğru sokak 3-4 m yükselir) + village.gd. Köyün kenarındaki ağaç ve taşlar
  levels/harabe_koy.tscn'de (Gezinme/HarabeKoy/Parcalar; navmesh'te engel).
  ENGEBELİ ZEMİN: oyunun mantığı düz kalır: herkesin global_position'ı y = 0'da (yol bulma, uzaklık, vuruş
  yatay). Yalnızca görüntü kalkar: levels/terrain.gd (Terrain.height(x, z), on_ground, ray_to_ground; veri
  yoksa 0). Oyuncu, düşman ve iskelet _process'te model.position.y'yi zemin yüksekliğine çeker (iskelette
  + rise_offset); kamera odağı, tıklama ışını (ray_to_ground, sonuç y = 0), enemy_under_cursor, mızrak, mühür
  efekti, ceset, iksir ve saydamlaşma da Terrain kullanır. Yeni bir şey eklerken: konumu düz tut, çizerken
  Terrain.on_ground ile kaldır. Veri: levels/harabe_koy_terrain.res (TerrainData: 0.25 m'lik karelerde
  yükseklik + yürünemez işareti), tools/build_village_terrain.gd modelden çıkarır (zemin = yukarı bakan en
  alçak yüzey; bel hizasında yüzey, 0.3 m'den dik basamak ya da girişten ulaşılamayan yer yürünemez; haritayı
  yazdırır). Navmesh: tools/bake_navmesh.gd köy bölgesine yürünebilir karelerden DÜZ zemin ekler (model
  navmesh'e girmez); editördeki Bake düğmesi köyü yürünemez bırakır, hep betiği kullan. Modeli taşıyınca:
  build_village_terrain, sonra bake_navmesh, sonra ENEMY_SPAWNS'ı haritaya göre gözden geçir.
  Düşmanlar: köy girişinde 3 (z ~68), meydanda 4, batıdaki yokuşta 5; toplam 15. Yol köy girişinde biter
  (road_count 12; köyün içinde modelin kendi taş yolu var). Köy tek mesh olduğu için saydamlaşmaz: evlerin
  arkasında karakter görünmeyebilir. Cevre halkası z = 130'a kadar (DisZemin 120 x 200). Ara sahnede köy yok.
  Deneme: tools/village_test.gd (düşmanlara yol, yokuş yürüyüşü, tıklama).
  Görüş penceresi: köy tek mesh olduğu için see_through.gd onu saydamlaştıramaz; village.gd açılışta modelin
  malzemesini aynı dokularla materials/koy.gdshader'a çevirir. Karakter köy alanındayken (AREA) karakterin
  göğsünün çevresinde (ekranda 3.2 m yarıçap) ondan kameraya yakın ve zeminden 0.4 m yüksek pikseller
  noktalı (dither, %80) silinir; gölge çiziminde silinmez (kamera yönüne bakılır). Deneme:
  tools/village_window_test.gd (pencere kapalı/açık görüntüler).
  Taşlar: assets/kit/tas/tas1-3.glb (dokusuz, rengi köşe renklerinde/COLOR_0; Godot bunu kendiliğinden
  kullanmıyor, bembeyaz çıkıyordu). props/tas1-3.tscn glb'yi sarıp materials/tas.tres'i takar
  (vertex_color_use_as_albedo + is_srgb); sahnelerde glb değil bu props sahneleri kullanılır. Kütüphane
  bölgesinde 14, Kül Yolu'nda 18 (Parcalar altında "tasN-M", navmesh'te engel), Cevre'de 110 (Taslar altında).
  Dokular dünya konumuna göre döşenir, iki zemin dikişsiz birleşir. Düşmanlar main.gd ENEMY_SPAWNS'tan kodla Dusmanlar
  altına konur (main.tscn'de düşman yok): Kül Yolu'nda 1 tek, sonra 2. Doğuş hâlâ kütüphanede.
  Kütüphanenin güney kemer kapısı (kemer-kapi-1) yatayda 1.5, dikeyde 1.15 kat büyütüldü: açıklığı ~1.3 m'ydi,
  ajan yarıçapı (0.4) yüzünden navmesh'te geçit 0.5 m kalıyor, WASD ile geçilemiyordu; şimdi ~1.1 m.
  Deneme: tools/level_test.gd (kütüphaneden Kül Yolu'na yürüyüş).
- Can iksiri: items/health_potion.tscn + .gd; model assets/items/health-potion.glb (asıl public/models/kit/
  health-potion.glb 1.3 milyon üçgen, 43 MB; `npx @gltf-transform/cli` weld → simplify --ratio 0.004 --error
  0.02 → resize 512 ile 9 bin üçgen, 0.6 MB). Düşman yere düşünce main.on_enemy_fell: ceset + %20 olasılıkla (bir iksirden sonraki 2 ölümde düşmez, POTION_GAP; ortalama 7 ölümde 1)
  (POTION_CHANCE) main.drop_potion: cesedin 1 m yanına (navmesh'e çekilir) yayla sıçrar, yerde dönüp süzülür,
  kırmızı ışığı var. Oyuncu 1.1 m'ye gelince kendiliğinden alınır, 25 can (HEAL; player.heal); can tamsa
  alınmaz, yerde bekler. Deneme: tools/potion_test.gd.
- Mana ve yenilenme (player.gd): max_mana 100, MANA_REGEN 5/sn. Kemik mızrağı SPEAR_MANA 12 (start_spear
  harcar), iskelet kaldırma RAISE_MANA 25 (main.raise_dead önce bakar, büyü başlayınca harcar; büyü yarıda
  kalırsa geri gelmez). player.spend_mana(bedel) yetmezse harcamaz, not_enough_mana sinyali → HUD mana küresini
  parlatır (globe.blink) ve en sık 2 sn'de bir "Manam yetmiyor." der. Can: son hasardan 5 sn sonra
  (HEALTH_REGEN_DELAY) 1/sn dolar. Doğuşta mana da tam. mana_changed sinyali → HUD ManaKuresi (sağ alt; can
  küresinin aynısı; kendi görselleri assets/hud/mana-frame.png (kafatası sağda; tools/prepare_mana_frame.gd asıl görseldeki rozetten örnek "1"i silerek üretir, görsel güncellenince yeniden çalıştır) ve mana-liquid.png, asılları
  public/models/hud/mana-globe; boş küre ortak globe-empty.png). globe_fill.gdshader rengi COLOR'dan alır (COLOR
  zaten doku x modulate; eskiden doku bir kez daha çarpılıp sıvı koyulaşıyordu, düzeltildi: renkler görseldeki gibi). health_globe.gd artık Tween değil _process ile akar (yenilenme her kare küçük artış
  gönderse de boşalma animasyonu kesilmez). Deneme: tools/mana_test.gd.
- Ekran sarsıntısı: camera_follow.gd artık class_name GameCamera; GameCamera.shake(miktar 0..1) her yerden
  çağrılır (static active; ara sahnede kamera yok, hiçbir şey yapmaz). Miktar "trauma"da birikir, saniyede 2
  söner; kayma ekran düzleminde, trauma'nın karesi x SHAKE_REACH (1 m) / zoom. Kılıç darbesi 0.35 (~5 piksel),
  mızrak isabeti 0.3, oyuncu hasar alınca 0.5, mühür kırılınca 0.6; iskeletlerin vuruşu sarsmaz.
- Hareketli çarpışma: characters/crowd.gd (main.gd açılışta "Kalabalik" düğümü olarak ekler; fizik yok). Her fizik
  karesinde herkesin hareketinden sonra (process_physics_priority 100) oyuncu (0.4 m, ağırlık 4), canlı düşmanlar
  (0.45 m x boy, 2) ve ayaktaki iskeletler (0.35 m, 1) yerde daire sayılır; üst üste binen ikililer ağırlığa göre
  itilir (iskelet oyuncuya yol verir), itilen navmesh'e yatayda çekilir. Ölüler ve kalkmakta olan iskeletler
  engel değil. Deneme: tools/crowd_test.gd.
- Vuruş hissi: düşman her vuruluşta (enemy.hit; kılıç, iskelet, mızrak) effects/hit_spark.tscn (+ .gd, class_name
  HitSpark): göğüs hizasında vurandan uzağa saçılan 18 beyaz-sarı kıvılcım (GPUParticles3D, ince kutu, hıza
  hizalı, yerçekimli) + 0.15 sn'lik küçük ışık; güç hasarla (hasar / 12, en az 0.3): iskeletinki daha az kıvılcım.
  Hit stop: effects/hit_stop.gd (class_name HitStop; HitStop.freeze(sn)): Engine.time_scale 0.1'e iner, kökte
  oluşturduğu yardımcı düğüm (PROCESS_MODE_ALWAYS) her kare gerçek saate bakıp hızı 0.2 sn'de yumuşakça 1'e
  çıkarır ve sonunda kesin 1 yapar (ilk sürümde geri dönüş zamanlayıcıya bağlıydı, kullanıcının oyununda yavaş
  kalıyordu). Yalnızca oyuncunun kılıcı (player.HIT_STOP 0.2). Deneme: tools/combat_test.gd (darbe anında oyun hızını yazar, 1b-kivilcim.png).
- Parça saydamlaşması: levels/see_through.gd (main.tscn'de Saydamlik; piece_roots: iki bölgenin Parcalar'ı ve
  Cevre/Agaclar). Açılışta her parçanın sınır kutusu (kendi uzayında) ölçülür; 0.1 sn'de bir karakterin ayak,
  göğüs ve başından kameraya uzanan çizgi kutuyu kesiyorsa parça %70 saydamlaşır (GeometryInstance3D.transparency,
  ~0.18 sn'de), çıkınca geri belirir. 1.2 m'den alçak parçalar (taş, moloz) sayılmaz. Ağaçta kutu dalları da
  kapsar; birkaç ağaç birden saydamlaşabilir. Düşmanlar için yok. Deneme: tools/see_through_test.gd.

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
karakteri A* ile takip eder. En fazla 5 iskelet (Game.ts MAX_MINIONS): sınır doluyken yenisi kaldırılırsa
rastgele biri serbest kalır (SealBreak 'release': altınsız, sadece mavi parlama, ruh ve ışık) ve yok olur. Efektin ışığı (altın → mavi,
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
- Sahneye biraz daha ışık; parçalar şu an çok koyu
- planlar/yanik-kutuphane-ornek.svg'yi koda göre güncelle (yüksek duvar, duvar rafı, çatı kemeri yok)
- Köy modelinin kenarındaki basamağı (0.1-1 m) taş/çalıyla gizle
- Harabe Köy'ün güneyine 4. bölge Sisli Orman
- Kül Yolu'nda ölünce kütüphane yerine Kül Yolu girişinde doğma (kontrol noktası)
- Kullanılmayan Environment.ts'yi sil
- A* açık listesini öncelik kuyruğuna çevir (harita büyüyünce)
- İskelete yerden kalkma (Standing Up) ve kendine özgü (zombi) yürüme animasyonu
- skeleton.fbx'i hafiflet (278 bin üçgen; çok minionda ağırlaşır)
- Vampire kendi animasyonları (vurulma, ölüm) ve can barı
- Mana iksiri; iksir alma sesi ve yerdeki iksirin süreyle kaybolması
- Karakter için ölüm ve vurulma animasyonu (şimdi sadece devriliyor)
- Walking.fbx'i Without Skin indir (15 MB → ~0.5 MB)
- Sesler: mühür kırılması (freesound CC0 "glass shatter"), fısıltı (kendi Türkçe kaydımız), kılıç darbesi
