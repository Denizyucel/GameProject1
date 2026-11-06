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
