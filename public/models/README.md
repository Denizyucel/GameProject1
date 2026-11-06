# Modeller

Bu klasördeki model dosyaları Git'e eklenmez (bkz. `.gitignore`). Mixamo lisansı
ham karakter ve animasyon dosyalarının tek başına dağıtılmasına izin vermiyor.

Projeyi yeni bir bilgisayarda açınca bu dosyaları [Mixamo](https://www.mixamo.com)'dan
yeniden indirip buraya koy:

| Dosya | Mixamo'da | Ayar |
| --- | --- | --- |
| `nightshade.fbx` | Karakter: Nightshade J Friedrich | FBX Binary, With Skin |
| `idle.fbx` | Idle animasyonu | Without Skin |
| `walk.fbx` | Walking animasyonu | Without Skin, In Place |
| `attack.fbx` | Sword And Shield Attack | Without Skin |
| `sword.glb` | Kılıç, [Meshy](https://www.meshy.ai) | GLB |
| `skeleton.fbx` | İskelet (ceset ve minion): Meshy modeli, Mixamo'da Upload Character ile riglendi | FBX Binary, T-pose, With Skin |
| `Vampire A Lusth.fbx` | Düşman: Vampire A Lusth (karakter) | FBX Binary, T-pose, With Skin |
| `Walking.fbx` | Walking animasyonu, Vampire seçiliyken indirildi | With Skin (Without Skin da olur), In Place değil |
| `Creature NPC Pack/` | Creature NPC Pack, Vampire seçiliyken (klasör adıyla) | Without Skin |
| `flesh.glb` | Et yığını (kırılan taşın bıraktığı ceset), Meshy | GLB |
| `Magic Spell Pack/` | Magic Spell Pack (paket, klasör adıyla) | Without Skin |

Dosyalar yoksa oyun yine çalışır; karakter yerine mor kapsül, vampir yerine mezar taşı, kılıç yerine tırpan görünür,
et yığını yoksa yerde yatan iskelet, iskelet modeli yoksa çizilmiş iskelet,
büyü animasyonları yoksa ceset yine dirilir ama karakter büyü hareketi yapmaz.

İskelet minion, karakterin `idle.fbx` ve `walk.fbx` animasyonlarını kullanır (kemik adları aynı).
Meshy modeli Mixamo'ya GLB olarak yüklenemiyor; önce OBJ + PNG doku olarak zip'lenip yüklendi.
