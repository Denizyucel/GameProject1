# Necromancer ARPG — Başlangıç Planı

6 Kasım 2026

## İlk hedef ve bitti tanımı

İlk hedef, tarayıcıda izometrik açıdan bakan bir Three.js sahnesi: zemin, grid, Necromancer'ın yerinde duran bir kapsül, ışık ve gölge. Oyunun geri kalanı (hareket, düşmanlar, minion'lar) bu iskeletin üstüne kurulacak. Tahmini süre 3-4 akşam, her biri 2-3 saat.

Hedef ancak şu maddelerin hepsi tamamsa bitmiş sayılır:

- [ ] `npm run dev` ile açılan sayfada sahne görünüyor
- [ ] Kamera izometrik açıda: yaklaşık 35° yukarıdan, 45° dönük
- [ ] Kapsül zemine gölge düşürüyor ve hafifçe nefes alıyor (döngü çalışıyor)
- [ ] Pencere boyutu değişince görüntü esnemiyor
- [ ] Retina ekranda kenarlar keskin
- [ ] Safari ve Chrome konsolunda hata yok
- [ ] Kod Git'te, ilk commit atılmış
- [ ] Her dosyanın ne işe yaradığını kendi cümlelerinle anlatabiliyorsun

Son madde en önemlisi: amaç sadece çalışan bir ekran değil, onu anlamak.

## Adım 0: Mac'i hazırla

Üç araç gerekiyor: Git, Node.js ve bir kod editörü. Hepsini Terminal uygulamasından kontrol edeceksin (Spotlight'ta "Terminal" yaz).

1. **Git:** Terminal'e `xcode-select --install` yaz. Açılan pencerede kurulumu onayla. Zaten kuruluysa öyle olduğunu söyler.
2. **Node.js:** [nodejs.org](https://nodejs.org) adresinden "LTS" yazan sürümün macOS yükleyicisini indir ve kur. LTS, uzun süre desteklenen kararlı sürüm demek.
3. **VS Code:** [code.visualstudio.com](https://code.visualstudio.com) adresinden indir. Açınca Komut Paleti'nden (Cmd+Shift+P) "Shell Command: Install 'code' command in PATH" komutunu çalıştır; böylece Terminal'den `code .` ile klasör açabilirsin.
4. **Safari geliştirici menüsü:** Safari > Ayarlar > Gelişmiş > "Web geliştiricileri için özellikleri göster" kutusunu işaretle. Safari'de konsolu ve performans araçlarını bununla açacaksın.

Kontrol için Terminal'de şunları çalıştır. Her biri bir sürüm numarası yazmalı, hata değil:

```bash
git --version
node -v
npm -v
```

Git'e kim olduğunu bir kez söyle (commit'lerde görünür):

```bash
git config --global user.name "Adın Soyadın"
git config --global user.email "eposta@adresin.com"
```

## Adım 1: Projeyi oluştur

Vite, React + TypeScript şablonuyla projeyi saniyeler içinde kurar ve kaydettiğin her değişikliği tarayıcıya anında yansıtır. Proje adı burada `necro`; istediğini koyabilirsin.

```bash
cd ~/Documents
npm create vite@latest necro -- --template react-ts
cd necro
npm install
npm install three
npm install -D @types/three
npm run dev
```

Son komut bir adres yazar (genelde `http://localhost:5173`). Onu tarayıcıda açınca Vite'ın örnek sayfasını görmelisin. Durdurmak için Terminal'de Ctrl+C.

Her komutun ne yaptığı:

- `npm create vite@latest`: şablondan yeni proje klasörü üretir.
- `npm install`: şablonun ihtiyaç duyduğu paketleri `node_modules` klasörüne indirir.
- `npm install three`: Three.js'i projeye ekler.
- `npm install -D @types/three`: Three.js için TypeScript tip tanımlarını ekler. `-D` sadece geliştirme sırasında gerekli demek.
- `npm run dev`: geliştirme sunucusunu başlatır.

Son olarak Git'i başlat ve ilk kaydı at:

```bash
git init
git add .
git commit -m "Vite + React + TS iskeleti"
```

Vite şablonu `node_modules` klasörünü zaten `.gitignore` dosyasında hariç tutar; o klasör hiçbir zaman Git'e girmemeli.

## Adım 2: Klasör yapısı ve mimari kural

Tek kural: oyun kodu (`game/`) React'i hiç tanımaz, arayüz kodu (`hud/`) Three.js nesnelerine hiç dokunmaz. İkisi ileride (Faz 5) küçük bir ortak durum deposu üzerinden konuşacak. Bu ayrım şimdi kurulursa ileride ne HUD'u ne de oyunu baştan yazmak gerekir.

Şablondan gelen `src/App.tsx`, `src/App.css` ve `src/assets/` silinsin; hedef yapı şu:

```text
necro/
├─ CLAUDE.md          Opus için proje bağlamı
├─ index.html         iki katman: #game ve #hud
└─ src/
   ├─ main.tsx        giriş noktası: oyunu ve HUD'u başlatır
   ├─ index.css       tam ekran düzen ve katman sırası
   ├─ game/
   │  └─ Game.ts      Three.js: sahne, kamera, ışık, döngü
   └─ hud/
      └─ Hud.tsx      React: oyunun üstündeki arayüz
```

Katmanlar (oyun ve arayüz ayrı katmanlarda, aynı veriyi okur):

```text
┌─────────────────────────────────┐
│ HUD · React          (en üstte) │ ◄── okur (Faz 5) ──┐
│ boş alan tıklamayı geçirir      │                    │
└─────────────────────────────────┘          ┌─────────┴──────────┐
                │ tıklama aşağı geçer        │ Oyun durumu        │
                ▼                            │ düz TypeScript     │
┌─────────────────────────────────┐          │ karakter, düşman,  │
│ Sahne · Three.js       (altta)  │          │ minion             │
│ her ekran yenilemesinde çizilir │ ◄── her kare okur ─────────────┘
└─────────────────────────────────┘          └────────────────────┘
```

Oyuncu HUD'u en üstte görür, ama boş alana yaptığı tıklama alttaki sahneye ulaşır. Şimdilik oyun durumu `Game.ts` içinde duruyor; Faz 3'te savaş eklenince ayrı bir modüle taşınacak, Faz 5'te HUD onu bir store üzerinden okuyacak.

## Adım 3: CLAUDE.md

`CLAUDE.md`, Opus'un her oturumda okuduğu proje hafızası. Claude Code kullanıyorsan proje kökünde durması yeterli. Her faz bittiğinde "Şu anki hedef" satırını güncelle.

```markdown
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
Faz 1: izometrik Three.js sahnesini ekranda görmek.
```

## Adım 4: İzometrik sahne kodu

Dört dosya yeterli. Kodu kopyalamak yerine elle yazmak, satırların ne yaptığını çok daha hızlı öğretir. Yorum satırları (`//` ile başlayanlar) her bloğun amacını anlatıyor. Bu kod henüz çalıştırılarak denenmedi; ilk denemede hata çıkarsa mesajı olduğu gibi Opus'a yapıştır.

**`index.html`** — iki katman: altta oyun, üstte HUD.

```html
<!doctype html>
<html lang="tr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Necro</title>
  </head>
  <body>
    <div id="game"></div>
    <div id="hud"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

**`src/index.css`** — iki katmanı tam ekran üst üste koyar.

```css
html, body {
  margin: 0;
  height: 100%;
  overflow: hidden;
  background: #121018;
}

#game {
  position: fixed;
  inset: 0;
}

#game canvas {
  display: block;
}

#hud {
  position: fixed;
  inset: 0;
  pointer-events: none; /* boş alana tıklama oyuna geçsin */
  font-family: system-ui, sans-serif;
  color: #d8d2e6;
}

#hud .panel {
  pointer-events: auto; /* paneller tıklamayı kendisi alsın */
}

.hud-title {
  position: absolute;
  top: 16px;
  left: 16px;
  display: flex;
  gap: 8px;
  align-items: baseline;
  font-size: 13px;
  letter-spacing: 0.08em;
  opacity: 0.8;
}
```

**`src/game/Game.ts`** — oyunun kalbi. Sahneyi kurar, kamerayı yerleştirir, her karede çizer.

```typescript
import * as THREE from 'three';

// Kameranın dikeyde kaç dünya birimi gördüğü. Küçültürsen yakınlaşır.
const VIEW_HEIGHT = 18;

export class Game {
  private readonly container: HTMLElement;
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera: THREE.OrthographicCamera;
  private readonly player: THREE.Mesh;
  private readonly resizeObserver: ResizeObserver;

  constructor(container: HTMLElement) {
    this.container = container;

    // Renderer: sahneyi canvas'a çizen motor
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFShadowMap; // kenarı yumuşatılmış gölge
    container.appendChild(this.renderer.domElement);

    // Kamera: üç eksende eşit uzaklık = izometrik bakış
    this.camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 200);
    this.camera.position.set(20, 20, 20);
    this.camera.lookAt(0, 0, 0);

    // Sahne içeriği
    this.scene.background = new THREE.Color(0x121018);
    this.addLights();
    this.addGround();
    this.addGraves();
    this.player = this.createPlayer();

    // Pencere boyutu değişince kamerayı ve canvas'ı güncelle
    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(container);
    this.resize();
  }

  start() {
    // Her ekran yenilemesinde (genelde saniyede 60 kez) çalışır
    this.renderer.setAnimationLoop((time) => {
      this.update(time / 1000);
      this.renderer.render(this.scene, this.camera);
    });
  }

  dispose() {
    // İleride menüye dönerken oyunu temizlemek için
    this.renderer.setAnimationLoop(null);
    this.resizeObserver.disconnect();
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }

  private update(elapsed: number) {
    // Nefes alma: döngünün çalıştığını gösteren küçük hareket
    const breath = 1 + Math.sin(elapsed * 2) * 0.03;
    this.player.scale.set(1, breath, 1);
  }

  private addLights() {
    // Gökyüzü ve zeminden gelen yumuşak genel ışık
    const ambient = new THREE.HemisphereLight(0x8f86b0, 0x1a1622, 0.8);
    this.scene.add(ambient);

    // Ay ışığı: yönlü ışık, gölge düşürür
    const moon = new THREE.DirectionalLight(0xc9d4ff, 2);
    moon.position.set(-8, 15, 6);
    moon.castShadow = true;
    moon.shadow.mapSize.set(2048, 2048);
    const area = 15; // gölgenin hesaplandığı alanın yarı genişliği
    moon.shadow.camera.left = -area;
    moon.shadow.camera.right = area;
    moon.shadow.camera.top = area;
    moon.shadow.camera.bottom = -area;
    moon.shadow.camera.far = 50;
    this.scene.add(moon);
  }

  private addGround() {
    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(30, 30),
      new THREE.MeshStandardMaterial({ color: 0x2a2433, roughness: 1 }),
    );
    ground.rotation.x = -Math.PI / 2; // dik duran düzlemi yere yatır
    ground.receiveShadow = true;
    this.scene.add(ground);

    const grid = new THREE.GridHelper(30, 30, 0x4a3f5c, 0x352e42);
    grid.position.y = 0.01; // zeminle çakışıp titremesin
    this.scene.add(grid);
  }

  private addGraves() {
    // Tek geometri ve tek malzeme, beş mezar taşında ortak kullanılıyor
    const geometry = new THREE.BoxGeometry(0.8, 1.2, 0.25);
    const material = new THREE.MeshStandardMaterial({ color: 0x5c5866, roughness: 0.9 });
    const spots: [number, number][] = [[-4, -3], [-2, -5], [3, -4], [5, 2], [-5, 3]];

    for (const [x, z] of spots) {
      const grave = new THREE.Mesh(geometry, material);
      grave.position.set(x, 0.6, z);
      grave.rotation.y = Math.random() * 0.4 - 0.2;
      grave.castShadow = true;
      grave.receiveShadow = true;
      this.scene.add(grave);
    }
  }

  private createPlayer(): THREE.Mesh {
    const body = new THREE.Mesh(
      new THREE.CapsuleGeometry(0.4, 1.2, 8, 16),
      new THREE.MeshStandardMaterial({ color: 0x7b5ea7, roughness: 0.6 }),
    );
    body.position.y = 1; // kapsül 2 birim boyunda; yarısı kadar yukarı ki zemine bassın
    body.castShadow = true;
    this.scene.add(body);
    return body;
  }

  private resize() {
    const width = this.container.clientWidth;
    const height = this.container.clientHeight;
    if (width === 0 || height === 0) return;

    const aspect = width / height;
    this.camera.left = (-VIEW_HEIGHT * aspect) / 2;
    this.camera.right = (VIEW_HEIGHT * aspect) / 2;
    this.camera.top = VIEW_HEIGHT / 2;
    this.camera.bottom = -VIEW_HEIGHT / 2;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height);
  }
}
```

**`src/hud/Hud.tsx`** — şimdilik sadece bir başlık; Faz 5'te HP ve mana barları buraya gelecek.

```tsx
export function Hud() {
  return (
    <div className="hud-title">
      <strong>NECRO</strong>
      <span>Faz 1 · sahne</span>
    </div>
  );
}
```

**`src/main.tsx`** — şablondaki dosyanın yerine. Oyunu ve HUD'u ayrı ayrı başlatır.

```tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { Game } from './game/Game';
import { Hud } from './hud/Hud';
import './index.css';

const game = new Game(document.getElementById('game')!);
game.start();

createRoot(document.getElementById('hud')!).render(
  <StrictMode>
    <Hud />
  </StrictMode>,
);
```

Dosyaları kaydettikten sonra `npm run dev` açık değilse yeniden başlat ve tarayıcıyı yenile. Mor bir kapsül, etrafında mezar taşları ve gölgeler görmelisin.

## Adım 5: Doğrula

Sahneyi gördükten sonra iki tarayıcıda da şu testleri yap. Bir şey tutmuyorsa sorunun ilk bakılacak yeri sağdaki sütunda.

| Test | Nasıl | Tutmuyorsa ilk bakılacak yer |
| --- | --- | --- |
| Konsol temiz | Chrome: Cmd+Option+J. Safari: Cmd+Option+C | Kırmızı hata satırını Opus'a yapıştır |
| Ekran siyah değil | Sayfa açılınca mor kapsül görünüyor | Konsol hatası; `#game` div'i `index.html`'de var mı |
| Pencere esnemiyor | Pencereyi daralt, genişlet, tam ekran yap | `resize()` içinde `updateProjectionMatrix()` çağrısı |
| Retina'da keskin | Kenarlara yakından bak, tırtıklı olmamalı | `setPixelRatio` satırı |
| Gölge var | Kapsül ve taşların zeminde gölgesi görünüyor | `castShadow`, `receiveShadow`, `shadowMap.enabled` |
| Döngü çalışıyor | Kapsül hafifçe nefes alıyor | `game.start()` çağrısı |
| Akıcı | Chrome DevTools > Performance ile birkaç saniye kaydet, karelerin çoğu 16 ms altında | Gölge haritası boyutunu 1024'e indir |

Hepsi tamamsa Git'e kaydet:

```bash
git add .
git commit -m "Faz 1: izometrik sahne"
```

## Kavramlar sözlüğü

Bu sahnede geçen her kavramın tasarımcı diline yakın karşılığı:

| Kavram | Ne demek | Tasarımdaki benzeri |
| --- | --- | --- |
| Scene (sahne) | İçine her şeyin konduğu dünya | Figma'daki sayfa |
| Camera (kamera) | Dünyaya hangi açıdan bakıldığı | Frame'in görünen alanı |
| OrthographicCamera | Uzaklık arttıkça nesneleri küçültmeyen kamera; izometrik görüntüyü verir | Perspektifsiz izometrik illüstrasyon |
| Renderer | Sahneyi kameradan görüp canvas'a piksel olarak çizen motor | Export işlemi, ama saniyede 60 kez |
| Mesh | Görünen bir nesne: geometri + malzeme | Şekil katmanı |
| Geometry | Nesnenin biçimi (kutu, düzlem, kapsül) | Vektör şeklin kendisi |
| Material | Yüzeyin rengi, pürüzlülüğü, ışığa tepkisi | Fill ve efektler |
| Light (ışık) | Material'ın görünmesini sağlayan kaynak; ışık yoksa sahne siyah | Gölge ve parlaklık efektleri |
| Animation loop (döngü) | Her ekran yenilemesinde çalışan fonksiyon: güncelle, sonra çiz | Prototype'taki smart animate, ama sürekli |
| Dünya birimi | Sahnedeki uzunluk ölçüsü; bu projede 1 birim ≈ 1 metre | Grid boyutu |
| Pixel ratio | Bir CSS pikselinde kaç gerçek ekran pikseli olduğu; Retina'da 2 | @2x export |

İleride en çok karşına çıkacak kavram **delta time**: iki kare arasında geçen süre. Hareketi "her karede 0.1 birim" değil "saniyede 3 birim × delta" diye yazarsın; böylece oyun 60 Hz ekranda da 120 Hz ProMotion ekranda da aynı hızda çalışır.

## Öğrenme deneyleri

Sahne çalıştıktan sonra her deneyi tek tek yap: bir değeri değiştir, kaydet, sonucu gör, sonra geri al. Kod okumaktan çok daha hızlı öğretir. Önce sonucu tahmin et, sonra dene.

- [ ] `VIEW_HEIGHT` değerini 10 ve 30 yap. Zoom nasıl değişiyor?
- [ ] Kamera konumunu `(20, 20, 20)` yerine `(20, 35, 20)` yap. Açı nasıl değişiyor? Diablo hissine hangisi daha yakın?
- [ ] `OrthographicCamera` yerine `new THREE.PerspectiveCamera(35, 1, 0.1, 200)` dene. Farkı gör, sonra geri dön (resize kodu da değişmesi gerekecek; bu yüzden hata alırsan bu normal).
- [ ] Ay ışığının rengini sıcak turuncu (`0xffaa66`) yap. Atmosfer nasıl değişiyor?
- [ ] `HemisphereLight` satırını sil. Gölgeler neden tamamen siyah oldu?
- [ ] Mezar taşlarına altıncı bir konum ekle.
- [ ] Nefes almayı dönmeye çevir: `scale` yerine `rotation.y` kullan. Kapsül döndüğü halde neden fark edilmiyor?
- [ ] Kapsülün rengini Figma'da seçtiğin bir mor tonla değiştir. Renk paletin oyuna buradan girecek.

Her denemeden sonra öğrendiğini bir cümleyle bir notlar dosyasına yaz. Faz sonu notlarının temeli bu olacak.

## Opus ile çalışma yöntemi

Opus kodu senin yerine yazabilir; ama amaç öğrenmek olduğu için onu bir öğretmen ve eşli programlama ortağı gibi kullan.

1. **Bir oturum, bir hedef.** "Tıklayınca kapsül oraya yürüsün" iyi bir oturum. "Hareket, düşman ve HUD'u ekle" değil.
2. **Önce plan iste.** "Kod yazmadan önce hangi dosyaları neden değiştireceğini anlat." Planı anlamıyorsan soru sor, sonra onay ver.
3. **Açıklamayı iste.** Yeni bir kod geldiğinde: "Bu fonksiyonu satır satır anlat" ya da "Bunu silsem ne olur?"
4. **Bazen sen yaz.** "Bana bu kodu yazma; yol göster, ben yazayım, sonra gözden geçir." Haftada en az bir özellik böyle olsun.
5. **Hatayı olduğu gibi ver.** Konsoldaki kırmızı mesajın tamamını, hangi dosyada ne değiştirdiğini ve ne beklediğini yaz.
6. **Her çalışan adımda commit.** Bir şey bozulursa `git diff` ile neyin değiştiğini görür, `git restore .` ile son çalışan duruma dönersin.
7. **Ekran görüntüsü paylaş.** Görsel bir sorunu anlatmak yerine ekran görüntüsünü göster; Opus görüntüyü okuyabilir.

Örnek açılış mesajı:

```text
CLAUDE.md'yi oku. Faz 1'deyiz. Sahne çalışıyor. Şimdi zemine tıklayınca
tıklanan noktayı konsola yazdırmak istiyorum. Kod yazmadan önce bunun için
hangi Three.js kavramlarına ihtiyacım olduğunu ve hangi dosyaya ne
ekleyeceğimizi anlat.
```

## Sonraki adım: tıklayarak hareket

Sahne hazır olunca sıradaki hedef, Diablo'nun temel hissi: zemine tıklayınca karakter oraya yürür. Bunu üç küçük oturuma böl:

1. **Tıklamayı dünyaya çevir.** Raycaster ile fare konumundan zemine bir ışın gönder, çarptığı noktayı konsola yazdır.
2. **Düz çizgide yürü.** Kapsül hedef noktaya delta time kullanarak sabit hızla gitsin, vardığında dursun ve yürüdüğü yöne dönsün.
3. **Kamera takibi.** Kamera kapsülü izometrik açıyı koruyarak takip etsin.

Engellerin etrafından dolaşma (grid ve A* yol bulma) bu üçü bittikten sonra gelir. Mezar taşları o aşamada ilk engellerin olacak.
