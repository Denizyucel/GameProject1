import * as THREE from 'three';

// Kameranın dikeyde kaç dünya birimi gördüğü. Küçültürsen yakınlaşır.
const VIEW_HEIGHT = 18;

// Karakterin yürüme hızı: saniyede kaç dünya birimi (≈ metre)
const MOVE_SPEED = 4;

export class Game {
  private readonly container: HTMLElement;
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera: THREE.OrthographicCamera;
  private readonly player: THREE.Mesh;
  private readonly ground: THREE.Mesh;
  private readonly resizeObserver: ResizeObserver;

  // Raycaster: kameradan fare yönüne görünmez bir ışın gönderip neye çarptığını bulur
  private readonly raycaster = new THREE.Raycaster();
  // Farenin ekrandaki konumu, -1..1 aralığında (sol alt -1,-1; sağ üst 1,1)
  private readonly pointer = new THREE.Vector2();

  // Yürüme hedefi; null ise karakter duruyor
  private moveTarget: THREE.Vector3 | null = null;
  // Her karede yeni vektör yaratmamak için tekrar kullanılan geçici vektör
  private readonly toTarget = new THREE.Vector3();
  // Bir önceki karenin zamanı (saniye); delta time bundan hesaplanır
  private lastTime: number | null = null;

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
    this.ground = this.addGround();
    this.addGraves();
    this.player = this.createPlayer();

    // Canvas'a tıklanınca dünyada nereye tıklandığını bul
    this.renderer.domElement.addEventListener('pointerdown', this.onPointerDown);

    // Pencere boyutu değişince kamerayı ve canvas'ı güncelle
    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(container);
    this.resize();
  }

  start() {
    // Her ekran yenilemesinde (genelde saniyede 60 kez) çalışır
    this.renderer.setAnimationLoop((time) => {
      const elapsed = time / 1000; // milisaniyeyi saniyeye çevir
      // Delta time: önceki kareden bu yana geçen süre. Sekme arka plandayken
      // büyük bir boşluk oluşursa karakter ışınlanmasın diye 0.1 sn ile sınırlı.
      const delta = this.lastTime === null ? 0 : Math.min(elapsed - this.lastTime, 0.1);
      this.lastTime = elapsed;

      this.update(elapsed, delta);
      this.renderer.render(this.scene, this.camera);
    });
  }

  dispose() {
    // İleride menüye dönerken oyunu temizlemek için
    this.renderer.setAnimationLoop(null);
    this.renderer.domElement.removeEventListener('pointerdown', this.onPointerDown);
    this.resizeObserver.disconnect();
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }

  private update(elapsed: number, delta: number) {
    this.updateMovement(delta);

    // Nefes alma: döngünün çalıştığını gösteren küçük hareket
    const breath = 1 + Math.sin(elapsed * 2) * 0.03;
    this.player.scale.set(1, breath, 1);
  }

  private updateMovement(delta: number) {
    if (!this.moveTarget) return; // hedef yok, duruyoruz

    // Karakterden hedefe giden vektör: uzunluğu kalan mesafe, yönü gidilecek yön
    this.toTarget.subVectors(this.moveTarget, this.player.position);
    const distance = this.toTarget.length();
    const step = MOVE_SPEED * delta; // bu karede atılacak adımın boyu

    if (distance <= step) {
      // Hedefe bir adımdan az kaldı: tam üstüne koy ve dur
      this.player.position.copy(this.moveTarget);
      this.moveTarget = null;
      return;
    }

    // Yüzünü yürüdüğü yöne çevir. atan2, x ve z farkından açıyı (radyan) bulur.
    this.player.rotation.y = Math.atan2(this.toTarget.x, this.toTarget.z);

    // Yönü 1 birim uzunluğa indir (normalize), sonra adım boyu kadar ilerle
    this.player.position.addScaledVector(this.toTarget.normalize(), step);
  }

  // Ok fonksiyonu (=>) olarak yazıldı ki içindeki "this" her zaman Game'i göstersin
  private readonly onPointerDown = (event: PointerEvent) => {
    if (event.button !== 0) return; // sadece sol tık

    // 1. Fare konumunu piksel cinsinden -1..1 aralığına çevir
    const rect = this.renderer.domElement.getBoundingClientRect();
    this.pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    this.pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1; // ekranda y aşağı doğru artar, dünyada yukarı

    // 2. Kameradan bu noktaya doğru ışın gönder, sadece zemine çarpıp çarpmadığına bak
    this.raycaster.setFromCamera(this.pointer, this.camera);
    const hit = this.raycaster.intersectObject(this.ground)[0];
    if (!hit) return; // zeminin dışına tıklandı

    // 3. Çarptığı noktayı yürüme hedefi yap. Yükseklik (y) karakterinkiyle aynı
    //    kalsın ki kapsül yere gömülmeye çalışmasın, sadece x ve z'de yürüsün.
    const { x, z } = hit.point;
    this.moveTarget = new THREE.Vector3(x, this.player.position.y, z);
  };

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

  private addGround(): THREE.Mesh {
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

    return ground; // tıklama ışını bu nesneye karşı test edilecek
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

    // Yüz işareti: kapsül yuvarlak olduğu için dönüşü görünmez; bu küçük
    // parça karakterin baktığı yönü (yerel +z) gösterir. Kapsülün "çocuğu"
    // olduğu için kapsülle birlikte hareket eder ve döner.
    const face = new THREE.Mesh(
      new THREE.BoxGeometry(0.3, 0.12, 0.2),
      new THREE.MeshStandardMaterial({ color: 0xb6f0d0, emissive: 0x3a8f6a }),
    );
    face.position.set(0, 0.45, 0.38);
    body.add(face);

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
