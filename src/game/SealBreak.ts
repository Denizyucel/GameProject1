// Mühür kırılma anı: Altın Ölümsüz'ün sahte ölümsüzlük mührü kırılınca oynayan görsel efekt.
// Sırası (Hikaye.md, çekirdek döngü):
//   1. Kırılma: göğüs hizasında altın bir parlama, açılan ışık halkası ve dört yana saçılan
//      altın kıymıklar (cam kırılır gibi)
//   2. Ruh: mavi yıldız tozu parçacıkları dönerek göğe yükselir
// Kemiklerden iskeletin kalkması burada değil, Game'de (düşmanın bedeni gömülünce).
// Efekt kendi kendine biter; update false döndürünce Game onu sahneden kaldırıp dispose eder.

import * as THREE from 'three';

// Efektin göğüs hizası (metre)
const CHEST_HEIGHT = 1.2;
const GOLD = 0xffc95a;
const SOUL_BLUE = 0x7cc4ff;

// Kırılma: parlamanın ve halkanın süresi (saniye), halkanın son yarıçapı (metre)
const FLASH_DURATION = 0.35;
const RING_DURATION = 0.5;
const RING_RADIUS = 1.6;
// Kıymıklar: sayısı, fırlama hızı (m/sn), yerçekimi (m/sn²), ömrü (saniye)
const SHARD_COUNT = 16;
const SHARD_SPEED = 4.5;
const SHARD_GRAVITY = 9;
const SHARD_LIFE = 0.9;
// Ruh: parçacık sayısı, yükselme süresi (saniye), ne kadar yükseldiği (metre), kırılmadan ne kadar
// sonra başladığı (saniye), dönerek yükselirken sarmalın yarıçapı (metre)
const SOUL_PARTICLES = 70;
const SOUL_DURATION = 2.8;
const SOUL_HEIGHT = 5;
const SOUL_DELAY = 0.15;
const SOUL_SPIRAL = 0.45;
// Bir ruh parçacığının ekrandaki boyu (CSS pikseli). Izometrik (ortografik) kamerada noktaların
// boyu metre değil piksel olarak çizilir; uzaklıkla küçülmez.
const SOUL_PARTICLE_PIXELS = 14;
// Işık: önce altın parlar, sonra ruhun mavisine döner ve ruh yükseldikçe yavaşça söner.
// Sadece düşmanın etrafını aydınlatır (LIGHT_RANGE metreden ötesine ulaşmaz).
const LIGHT_DURATION = 3; // yanıp tamamen sönmesine kadar geçen süre (saniye)
const LIGHT_RANGE = 3.5; // aydınlattığı en uzak mesafe (metre)
const LIGHT_PEAK = 40; // kırılma anındaki en parlak hali (Three.js ışık şiddeti, candela)
const LIGHT_GOLD_TIME = 0.3; // altın kaldığı süre (saniye)
const LIGHT_TO_BLUE_TIME = 0.6; // altından maviye geçiş süresi (saniye)
const LIGHT_RISE = 1.2; // ruhla birlikte ne kadar yükseldiği (metre); yükseldikçe zemindeki ışık dağılır

/** Efektin tamamının süresi (saniye): bundan sonra kendi kendine biter */
export const SEAL_BREAK_DURATION = Math.max(SOUL_DELAY + SOUL_DURATION, LIGHT_DURATION);

/**
 * Işık havuzu: oyun başında birkaç sönük ışık sahneye bir kez eklenir, efektler bunları ödünç alıp
 * geri verir. Sahneye oyun sırasında yeni ışık eklemek bütün malzemeleri yeniden derletir ve oyun
 * bir an takılır; ışık sayısı hiç değişmezse bu olmaz. Havuz boşsa efekt ışıksız oynar.
 */
export class SoulLightPool {
  private readonly free: THREE.PointLight[] = [];

  constructor(scene: THREE.Scene, count: number) {
    for (let i = 0; i < count; i++) {
      const light = new THREE.PointLight(GOLD, 0, LIGHT_RANGE, 2);
      light.castShadow = false; // gölge hesaplamak pahalı; bu kısa ışığa gerek yok
      scene.add(light);
      this.free.push(light);
    }
  }

  take(): THREE.PointLight | null {
    return this.free.pop() ?? null;
  }

  give(light: THREE.PointLight) {
    light.intensity = 0;
    this.free.push(light);
  }
}

const LIGHT_GOLD = new THREE.Color(GOLD);
const LIGHT_BLUE = new THREE.Color(SOUL_BLUE);

// Bütün efektlerde ortak şekiller ve yuvarlak, kenarı yumuşak parçacık görseli (bellekte bir kez)
const SHARD_GEOMETRY = new THREE.TetrahedronGeometry(0.09); // dört yüzlü küçük kıymık
const RING_GEOMETRY = new THREE.RingGeometry(0.85, 1, 48);
const FLASH_GEOMETRY = new THREE.SphereGeometry(0.5, 16, 12);
let dotTexture: THREE.Texture | null = null;

// Ortası beyaz, kenarına doğru saydamlaşan yuvarlak bir nokta: parçacıkların görüntüsü
function getDotTexture(): THREE.Texture {
  if (dotTexture) return dotTexture;
  const size = 64;
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const context = canvas.getContext('2d')!;
  const gradient = context.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  gradient.addColorStop(0, 'rgba(255,255,255,1)');
  gradient.addColorStop(0.35, 'rgba(255,255,255,0.6)');
  gradient.addColorStop(1, 'rgba(255,255,255,0)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, size, size);
  dotTexture = new THREE.CanvasTexture(canvas);
  return dotTexture;
}

// Işık saçan malzeme: rengi arkasındakine eklenir (additive), böylece karanlıkta parlar.
// Işıktan etkilenmez (MeshBasic), derinliğe yazmaz ki parçacıklar birbirini kesmesin.
function glowMaterial(color: number): THREE.MeshBasicMaterial {
  return new THREE.MeshBasicMaterial({
    color,
    transparent: true,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
    side: THREE.DoubleSide,
  });
}

interface Shard {
  mesh: THREE.Mesh;
  velocity: THREE.Vector3;
  spin: THREE.Vector3;
}

export class SealBreak {
  readonly object = new THREE.Group();
  readonly light: THREE.PointLight | null;
  private readonly goldTime: number; // ışığın altın kaldığı süre (saniye)
  private time = 0;

  private readonly flash: THREE.Mesh<THREE.SphereGeometry, THREE.MeshBasicMaterial>;
  private readonly ring: THREE.Mesh<THREE.RingGeometry, THREE.MeshBasicMaterial>;
  private readonly shardMaterial = glowMaterial(GOLD);
  private readonly shards: Shard[] = [];

  private readonly soul: THREE.Points<THREE.BufferGeometry, THREE.PointsMaterial>;
  // Her ruh parçacığının başlangıç açısı, sarmal yarıçapı, hızı ve gecikmesi (0..1)
  private readonly soulSeeds: { angle: number; radius: number; speed: number; delay: number }[] = [];

  /**
   * at: kırılan mührün sahibinin ayak noktası (dünya koordinatı)
   * light: havuzdan ödünç alınan ışık (yoksa null); efekt bitince Game onu havuza geri verir
   * kind: 'seal' = mühür kırılması (altın kırılma + mavi ruh);
   *       'release' = serbest bırakılan iskelet (kırılacak mühür yok: sadece mavi parlama ve ruh)
   */
  constructor(at: THREE.Vector3, light: THREE.PointLight | null = null, kind: 'seal' | 'release' = 'seal') {
    this.light = light;
    this.goldTime = kind === 'seal' ? LIGHT_GOLD_TIME : -LIGHT_TO_BLUE_TIME; // serbest bırakmada ışık baştan mavi
    this.object.position.set(at.x, 0, at.z);
    light?.position.set(at.x, CHEST_HEIGHT, at.z);
    const burst = kind === 'seal' ? GOLD : SOUL_BLUE;

    // 1. Parlama: göğüste kısa süre büyüyüp sönen küre (mühürde altın, serbest bırakmada mavi)
    this.flash = new THREE.Mesh(FLASH_GEOMETRY, glowMaterial(burst));
    this.flash.position.y = CHEST_HEIGHT;
    this.object.add(this.flash);

    // Halka: yere paralel, dışa doğru açılıp sönen çember
    this.ring = new THREE.Mesh(RING_GEOMETRY, glowMaterial(burst));
    this.ring.rotation.x = -Math.PI / 2;
    this.ring.position.y = CHEST_HEIGHT;
    this.object.add(this.ring);

    // Kıymıklar: göğüsten dört yana ve biraz yukarı fırlar, düşerken söner (sadece mühür kırılınca)
    const shardCount = kind === 'seal' ? SHARD_COUNT : 0;
    for (let i = 0; i < shardCount; i++) {
      const mesh = new THREE.Mesh(SHARD_GEOMETRY, this.shardMaterial);
      mesh.position.y = CHEST_HEIGHT;
      const angle = (i / SHARD_COUNT) * Math.PI * 2 + Math.random() * 0.4;
      const speed = SHARD_SPEED * (0.6 + Math.random() * 0.6);
      const velocity = new THREE.Vector3(Math.sin(angle) * speed, 1.5 + Math.random() * 2.5, Math.cos(angle) * speed);
      const spin = new THREE.Vector3(Math.random(), Math.random(), Math.random()).multiplyScalar(14);
      this.shards.push({ mesh, velocity, spin });
      this.object.add(mesh);
    }

    // 2. Ruh: noktalardan oluşan bir bulut (Points). Konumları her karede hesaplanır.
    const positions = new Float32Array(SOUL_PARTICLES * 3);
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    for (let i = 0; i < SOUL_PARTICLES; i++) {
      this.soulSeeds.push({
        angle: Math.random() * Math.PI * 2,
        radius: SOUL_SPIRAL * (0.3 + Math.random()),
        speed: 0.7 + Math.random() * 0.6,
        delay: Math.random() * 0.35,
      });
    }
    this.soul = new THREE.Points(
      geometry,
      new THREE.PointsMaterial({
        color: SOUL_BLUE,
        size: SOUL_PARTICLE_PIXELS,
        sizeAttenuation: false,
        map: getDotTexture(),
        transparent: true,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
        opacity: 0,
      }),
    );
    this.soul.frustumCulled = false; // noktalar her karede yer değiştiriyor; sınır kutusu hep eski kalırdı
    this.object.add(this.soul);
  }

  /** Efekti ilerlet. Bittiyse false döner. */
  update(delta: number): boolean {
    this.time += delta;
    const t = this.time;

    // Parlama: hızla büyüyüp söner
    const flash = Math.min(t / FLASH_DURATION, 1);
    this.flash.scale.setScalar(0.3 + flash * 1.4);
    this.flash.material.opacity = 1 - flash;
    this.flash.visible = flash < 1;

    // Halka: dışa açılırken incelir gibi söner
    const ring = Math.min(t / RING_DURATION, 1);
    this.ring.scale.setScalar(0.2 + (1 - (1 - ring) ** 3) * RING_RADIUS);
    this.ring.material.opacity = (1 - ring) * 0.9;
    this.ring.visible = ring < 1;

    // Kıymıklar: basit fizik (hız + yerçekimi), yere değince orada kalır, ömrü bitince söner
    const shardLife = Math.min(t / SHARD_LIFE, 1);
    for (const shard of this.shards) {
      shard.velocity.y -= SHARD_GRAVITY * delta;
      shard.mesh.position.addScaledVector(shard.velocity, delta);
      if (shard.mesh.position.y < 0.05) {
        shard.mesh.position.y = 0.05;
        shard.velocity.set(0, 0, 0);
      }
      shard.mesh.rotation.x += shard.spin.x * delta;
      shard.mesh.rotation.y += shard.spin.y * delta;
      shard.mesh.visible = shardLife < 1;
    }
    this.shardMaterial.opacity = 1 - shardLife * shardLife;

    // Ruh: kırılmadan biraz sonra başlar; parçacıklar dönerek yükselir, sarmal yukarıda daralır
    const soulTime = (t - SOUL_DELAY) / SOUL_DURATION; // 0 → 1
    const positions = this.soul.geometry.attributes.position as THREE.BufferAttribute;
    for (let i = 0; i < SOUL_PARTICLES; i++) {
      const seed = this.soulSeeds[i];
      const p = THREE.MathUtils.clamp((soulTime - seed.delay) / (1 - seed.delay), 0, 1);
      const rise = p * p * seed.speed; // yavaş başlayıp hızlanan yükseliş
      const angle = seed.angle + p * Math.PI * 3;
      const radius = seed.radius * (1 - p * 0.7);
      positions.setXYZ(i, Math.sin(angle) * radius, CHEST_HEIGHT + rise * SOUL_HEIGHT, Math.cos(angle) * radius);
    }
    positions.needsUpdate = true;
    // Görünürlük: hızla belirir, son üçte birde söner
    const soulVisible = THREE.MathUtils.clamp(soulTime * 6, 0, 1) * THREE.MathUtils.clamp((1 - soulTime) * 3, 0, 1);
    this.soul.material.opacity = soulVisible;

    // Işık: altın → mavi, kırılma anında en parlak, sonra yavaşça söner ve ruhla biraz yükselir
    if (this.light) {
      const life = Math.min(t / LIGHT_DURATION, 1);
      const toBlue = THREE.MathUtils.clamp((t - this.goldTime) / LIGHT_TO_BLUE_TIME, 0, 1);
      this.light.color.lerpColors(LIGHT_GOLD, LIGHT_BLUE, toBlue);
      const flare = Math.min(t / 0.05, 1); // ilk 0.05 sn'de yanar
      this.light.intensity = LIGHT_PEAK * flare * (1 - life) ** 2;
      this.light.position.y = CHEST_HEIGHT + life * LIGHT_RISE;
    }

    return t < SEAL_BREAK_DURATION;
  }

  /** Bu efekte ait malzemeleri ve noktaları bellekten sil (ortak şekiller ve görsel kalır) */
  dispose() {
    this.flash.material.dispose();
    this.ring.material.dispose();
    this.shardMaterial.dispose();
    this.soul.geometry.dispose();
    this.soul.material.dispose();
  }
}
