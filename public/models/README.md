# Modeller, dokular ve görseller

Bu klasördeki dosyalar Git'e eklenmez (bkz. `.gitignore`): Mixamo lisansı ham karakter ve
animasyon dosyalarının tek başına dağıtılmasına izin vermiyor; Meshy modelleri ve HUD görselleri de
aynı şekilde dışarıda tutuluyor. **Bu README, Git'te kalan tek listedir**: disk kaybolursa neyin
nereden geldiğini buradan bulursun. Yeni bir dosya eklediğinde ya da adını değiştirdiğinde burayı da
güncelle.

> ⚠️ Bu dosyaların Git'te yedeği yok. Meshy modellerini ve kendi çizdiğin görselleri yeniden
> indiremezsin: harici diske (Time Machine) ya da başka bir yere düzenli yedekle.

## Nasıl çalışır

- `public/models/` **asılların** durduğu yer (kaynak). Godot burayı okumaz.
- `godot/assets/` Godot'nun kullandığı **kopyalar**. Çoğu asıl dosyanın birebir kopyası; birkaçı
  küçültülmüş ya da betikle üretilmiş (aşağıda **türetilmiş** diye işaretli).
- Godot, `.glb` ve `.fbx` dosyalarının içindeki dokuları içe aktarırken yanlarına ayrı dosya olarak
  çıkarır (`x_normal.png`, `koy_0.jpg`, `skeleton_0.png` gibi). Bunlar `--import` ile kendiliğinden
  yeniden oluşur, asıl listesinde yer almazlar.
- Tarayıcı sürümü (`src/`) bu klasörü doğrudan okur; aşağıdaki [Tarayıcı sürümü](#tarayıcı-sürümü-src)
  bölümüne bak.

## Yeni bir bilgisayarda kurmak

1. `public/models/` klasörünü yedekten geri koy.
2. Aşağıdaki tablolarda "asıl" sütunundaki her dosyayı `godot/assets/` içindeki yoluna kopyala
   (birçoğunun adı ya da klasörü değişiyor; tablodaki gibi yap).
3. Türetilmiş dosyaları üret:
   - Köy ve can iksiri: [Küçültülen modeller](#küçültülen-modeller) bölümündeki komutlar.
   - Mana çerçevesi: `godot --headless --path godot -s tools/prepare_mana_frame.gd`
4. Godot'ya içe aktart: `godot --headless --path godot --import`

Doğrulama: `godot --headless --path godot res://main.tscn --quit-after 900` hatasız açılmalı.
Çıktıda iki "ERROR" satırı şimdilik normal: navmesh'in ilk karedeki "before first map
synchronization" uyarısı ve çıkıştaki "RID allocations ... leaked" satırı. Eksik dosya varsa
"Failed loading resource" ya da "Cannot open file" satırları çıkar.

İşaretler: **Kaynak** sütununda `?` kaynağı kayıtlı olmayan dosyaları gösteriyor; bildiğinde doldur.

## Karakterler

| godot/assets | Asıl (public/models) | Kaynak | Ne için |
| --- | --- | --- | --- |
| `character/necromancer-kadin.glb` | `Characters/Necromencer/Necromencer-kadin.glb` | Meshy (SmartRig) | Ruh Kıran. İçindeki "Running" yürüme olarak kullanılır (player.tscn `walk_file`) |
| `character/idle.fbx` | `idle.fbx` | Mixamo: Idle, Without Skin | Oyuncu, düşman, köylü ve X'in beklemesi |
| `character/walk.fbx` | `walk.fbx` | Mixamo: Walking, Without Skin, In Place | Yalnızca player.gd'nin varsayılanı; oyunda kullanılmıyor |
| `character/nightshade.fbx` | yok (`Weapons/Lite Sword and Shield Pack/nightshade.fbx` farklı bir indirme) | Mixamo: Nightshade J Friedrich, With Skin | Kullanılmıyor (eski karakter) |
| `enemies/enemy1.glb` | `Characters/Enemy/Enemy1.glb` | Meshy (SmartRig) | Düşmanlar (gümüş zırhlı şövalye) |
| `x/x.glb` | `Characters/X/x.glb` | Meshy (SmartRig) | X (açılış ara sahnesi) |
| `npc/woman1.glb` | `Characters/Woman/woman1.glb` | Meshy (SmartRig) | Köylü kadın (Saklanan Anne) |
| `minion/bone-golem.glb` | `Characters/bone-golem.glb` | Meshy (SmartRig) | Kemik golemi |
| `minion/skeleton.fbx` | `Characters/skeleton.fbx` | Meshy modeli, Mixamo'da Upload Character ile riglendi | İskelet minion |
| `minion/flesh.glb` | `flesh.glb` | Meshy | Ceset (et yığını) |

İskeletin Mixamo'ya yüklenen hali `Characters/skeleton-for-mixamo.zip`: Meshy modeli Mixamo'ya GLB
olarak yüklenemiyor, önce OBJ + PNG doku olarak zip'lendi. `Characters/skeleton.glb` Meshy'nin
riglenmemiş hali.

## Silahlar

| godot/assets | Asıl (public/models) | Kaynak | Ne için |
| --- | --- | --- | --- |
| `weapons/sword.glb` | `Weapons/sword.glb` | Meshy | Ruh Kıran'ın kılıcı |
| `weapons/sword2.glb` | `Weapons/sword2.glb` (küçültülmemiş hali `orijinal/sword2.glb`) | ? | İskeletin kılıcı |
| `weapons/kalkan.glb` | `Weapons/kalkan.glb` (küçültülmemiş hali `orijinal/kalkan.glb`, 27 MB) | ? | İskeletin kalkanı |

## Animasyonlar (Mixamo, Without Skin)

Mixamo'da herhangi bir karakter seçiliyken indirilebilir; Godot iskelete kendisi uyarlar.

| godot/assets | Asıl (public/models) |
| --- | --- |
| `animations/sword/attack.fbx` | `Weapons/Lite Sword and Shield Pack/sword and shield attack.fbx` |
| `animations/sword/attack2.fbx` | `Weapons/Lite Sword and Shield Pack/sword and shield attack (2).fbx` |
| `animations/sword/attack3.fbx` | `Weapons/Lite Sword and Shield Pack/sword and shield attack (3).fbx` |
| `animations/sword/attack4.fbx` | `Weapons/Lite Sword and Shield Pack/sword and shield attack (4).fbx` |
| `animations/spell/spell1.fbx` | `Magic Spell Pack/Standing 1H Magic Attack 01.fbx` (kemik mızrağı) |
| `animations/spell/spell2.fbx` | `Magic Spell Pack/Standing 1H Magic Attack 02.fbx` (kemik mızrağı) |
| `animations/spell/spell3.fbx` | `Magic Spell Pack/Standing 1H Magic Attack 03.fbx` (kemik mızrağı) |
| `animations/spell/spell4.fbx` | `Magic Spell Pack/Standing 2H Cast Spell 01.fbx` (X'in ara sahnedeki büyüsü de) |
| `animations/spell/spell5.fbx` | `Magic Spell Pack/Standing 2H Magic Area Attack 01.fbx` |
| `animations/spell/spell6.fbx` | `Magic Spell Pack/Standing 2H Magic Area Attack 02.fbx` |
| `animations/spell/spell7.fbx` | `Magic Spell Pack/Standing 2H Magic Attack 01.fbx` |
| `animations/spell/spell8.fbx` | `Magic Spell Pack/Standing 2H Magic Attack 02.fbx` |
| `animations/spell/spell9.fbx` | `Magic Spell Pack/Standing 2H Magic Attack 03.fbx` |
| `animations/spell/spell10.fbx` | `Magic Spell Pack/Standing 2H Magic Attack 04.fbx` |
| `animations/spell/spell11.fbx` | `Magic Spell Pack/Standing 2H Magic Attack 05.fbx` |
| `animations/spell/spell12.fbx` | `Magic Spell Pack/standing 1H cast spell 01.fbx` |
| `animations/creature/mutant-breathing-idle.fbx` | `Creature NPC Pack/mutant breathing idle.fbx` |
| `animations/creature/mutant-idle.fbx` | `Creature NPC Pack/mutant idle.fbx` |
| `animations/creature/mutant-swiping.fbx` | `Creature NPC Pack/mutant swiping.fbx` (düşmanın pençesi, golemin vuruşu) |
| `animations/creature/mutant-flexing-muscles.fbx` | `Creature NPC Pack/mutant flexing muscles.fbx` |
| `animations/creature/mutant-dying.fbx` | `Creature NPC Pack/mutant dying.fbx` (düşman ve oyuncu ölümü) |

Büyü ve kılıç dosyaları 1'den başlayarak numaralanır; oyun eksik numarayı atlar.

## Mekân parçaları

| godot/assets | Asıl (public/models) | Kaynak | Not |
| --- | --- | --- | --- |
| `kit/cati-kemeri.glb`, `duvar-rafi`, `kemer-kapi`, `kirik-sutun`, `kitap-yigini`, `moloz`, `muhur-kaidesi`, `sutun`, `yanmis-raf`, `yikik-duvar`, `yuksek-duvar` | `kit/` içinde aynı adla | Meshy | Yanık Kütüphane ve Kül Yolu. Küçültülmemiş halleri `kit-orijinal/` içinde (gltf-transform ile ~10 bin üçgene ve 1024 px dokuya indirildi; tam ayarlar kaydedilmedi) |
| `kit/kuru-agac.glb` | `kit/agaclar/agac1.glb` (aynı dosya) | Meshy | Kuru ağaç. Küçültülmemiş hali `kit-orijinal/kuru-agac.glb` |
| `kit/agaclar/agac1.glb` | `kit/agaclar/agac1.glb` | Meshy | Kullanılmıyor (`kuru-agac.glb` ile aynı) |
| `kit/agaclar/agac2.glb` | `kit/agaclar/agac2.glb` | ? | Büyük dallı ağaç |
| `kit/agaclar/agac3.glb` | `kit/agaclar/agac3.glb` | ? | Yapraksız kahverengi ağaç (props/agac3.tscn sarar) |
| `kit/tas/tas1.glb`, `tas2`, `tas3` | `kit/tas/` içinde aynı adla | ? | Taşlar (props/tas1-3.tscn sarar) |
| `kit/bina/bina1.glb` | `kit/bina/bina1.glb` | ? | Gotik bina (dışı) |
| `kit/bina/katlar/bina1-kat-1.glb`, `kat0`, `kat1`, `kat2` | `kit/bina/bina1-katplanlari/` içinde aynı adla (klasör adı farklı) | ? | Gotik binanın kat planları |
| `kit/koy.glb` | **türetilmiş**: `kit/koy.glb`'den küçültülür | ? | Harabe Köy |
| `items/health-potion.glb` | **türetilmiş**: `kit/health-potion.glb`'den küçültülür | ? | Can iksiri |

`kit-orijinal/devrik-raf.glb` yalnızca asıllarda var, oyunda kullanılmıyor.

### Küçültülen modeller

Asıllar oyun için çok ağır; `npx @gltf-transform/cli` ile küçültülür (komutları proje kökünden çalıştır):

```bash
# Harabe Köy: 2.6 milyon üçgen, 80 MB → ~77 bin üçgen, 4.7 MB
npx @gltf-transform/cli weld public/models/kit/koy.glb /tmp/koy-weld.glb
npx @gltf-transform/cli simplify /tmp/koy-weld.glb /tmp/koy-simple.glb --ratio 0.03 --error 0.002
npx @gltf-transform/cli resize /tmp/koy-simple.glb godot/assets/kit/koy.glb --width 2048 --height 2048

# Can iksiri: 1.3 milyon üçgen, 43 MB → ~9 bin üçgen, 0.6 MB
npx @gltf-transform/cli weld public/models/kit/health-potion.glb /tmp/iksir-weld.glb
npx @gltf-transform/cli simplify /tmp/iksir-weld.glb /tmp/iksir-simple.glb --ratio 0.004 --error 0.02
npx @gltf-transform/cli resize /tmp/iksir-simple.glb godot/assets/items/health-potion.glb --width 512 --height 512
```

Köy modeli değişirse arazi ve navmesh de yeniden çıkarılmalı (CLAUDE.md, "ENGEBELİ ZEMİN"):
`tools/build_village_terrain.gd`, sonra `tools/bake_navmesh.gd`.

## Zemin dokuları (ambientCG, CC0)

Her klasörden yalnızca dört harita kopyalanır: `_Color`, `_NormalGL`, `_Roughness`,
`_AmbientOcclusion`. `.blend`, `.usdc`, `.mtlx`, `.tres`, `_Displacement` ve `_NormalDX` Godot'da
kullanılmıyor.

| godot/assets | Asıl (public/models) | ambientCG adı | Ne için |
| --- | --- | --- | --- |
| `floor/cimen/Grass001_1K-PNG_*.png` | `floor/cimen/` | Grass001 | Dışarıdaki çimen |
| `floor/zemin/Ground110_1K-PNG_*.png` | `floor/zemin/` | Ground110 | Toprak yol ve patika |
| `floor/disarisi/Ground048_1K-JPG_*.jpg` | `floor/disarisi/` | Ground048 | Oyunda kullanılmıyor: dış zemin artık `materials/disarisi.tres` (çimen + toprak yol); yalnızca eski `tools/build_yanik_kutuphane.gd` anar |
| `floor/salonun-ici/Tiles130_1K-JPG_*.jpg` | `floor/salonun-ici/` | Tiles130 | Kütüphane salonunun taş döşemesi |

## HUD görselleri

| godot/assets | Asıl (public/models) | Not |
| --- | --- | --- |
| `hud/globe-frame.png` | `hud/health-globe/globe-frame.png` | Can küresinin çerçevesi (kanatlı figür) |
| `hud/globe-liquid.png` | `hud/health-globe/globe-liquid-without-frame.png` | Can sıvısı |
| `hud/globe-empty.png` | `hud/health-globe/globe-empty-without-frame.png` | Boş küre; mana küresi de bunu kullanır (`mana-empty-without-frame.png` ile aynı) |
| `hud/mana-liquid.png` | `hud/mana-globe/mana-liquid-without-frame.png` | Mana sıvısı |
| `hud/mana-frame.png` | **türetilmiş**: `hud/mana-globe/mana-frame.png`'den | `tools/prepare_mana_frame.gd` rozetteki örnek "1"i siler |
| `hud/skills/create-skeleton.png` | `hud/Skills/Create-skeleton.png` | Beceri simgesi (senin çizimin) |
| `hud/skills/create-golem.png` | `hud/Skills/Create-gollem.png` (adı farklı) | Beceri simgesi (senin çizimin) |

`hud/health-globe/orijinal/` (ve içindeki `eski`, `eski-2`, `eski-3`) önceki sürümler, oyunda
kullanılmıyor.

Yazı tipi (`godot/fonts/AguafinaScript-Regular.ttf`, OFL lisanslı) Git'te; buraya gerekmez.

## Godot'nun kullanmadıkları

- `envoirement.glb`: eski avlu (Meshy), yalnızca tarayıcı sürümü.
- `Walking.fbx`: vampir seçiliyken indirilmiş Walking, yalnızca tarayıcı sürümü.
- `attack.fbx`: eski tek vuruş, yalnızca tarayıcı sürümü.
- `Weapons/Lite Sword and Shield Pack.zip` (paketin kendisi; açılmış hali yanındaki klasörde) ve
  klasördeki öteki animasyonlar (block, run, strafe, turn, death...).
- `Creature NPC Pack/` içinde run, walking ve turn animasyonları; `Magic Spell Pack/standing idle.fbx`.
- `kit-orijinal/` ve `orijinal/`: küçültülmeden önceki asıllar. Kullanılmıyorlar ama sakla: yeniden
  küçültmek için gerekiyorlar.

## Tarayıcı sürümü (src/)

Three.js sürümü dosyaları klasörlenmeden önceki adlarla arar (`models/nightshade.fbx`,
`models/skeleton.fbx`, `models/sword.glb`, `models/sword2.glb`, `models/kalkan.glb`,
`models/Vampire A Lusth.fbx`...). Dosyalar `Characters/` ve `Weapons/` altına taşındığı ve
`Vampire A Lusth.fbx` artık olmadığı için tarayıcıda yedek görünümler çıkar (mor kapsül, mezar taşı,
tırpan...). Godot taşıması bitince bu sürüm önemini yitirir.

## Lisans notları

- **Mixamo**: oyunun içinde kullanmak serbest; ham `.fbx` dosyaları tek başına dağıtılamaz (bu yüzden
  Git'te değiller).
- **ambientCG**: CC0, serbest.
- **Meshy**: kullanım hakkı modelin hangi planla üretildiğine bağlı. Yayından önce her Meshy modelinin
  hangi hesap ve planla üretildiğini kontrol et.
- **Aguafina Script**: SIL Open Font License, Git'te.
