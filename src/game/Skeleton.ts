// İskelet: hem yerde yatan ceset hem de dirilen minion bunu kullanır.
// public/models/skeleton.fbx (Mixamo'da riglenmiş) yüklendiyse o model kopyalanır ve karakterin
// yürüme/bekleme animasyonlarını oynatır; vururken vampirin pençe animasyonunu kullanır
// Sağ elinde kılıç (sword2.glb), sol elinde kalkan (kalkan.glb) taşır; vururken kılıç
// vuruşlarından (weapon.ts) rastgele birini oynar. Kılıç ya da kalkan yüklenemezse onsuz kalır. Kılıç vuruşları yüklenemezse vampirin pençe animasyonuna döner.
// Yüklenmediyse basit şekillerden çizilmiş yedek iskelet kullanılır.
// Ölçüler metre; ayaklar y = 0'da, yüz +z yönüne bakıyor.

import * as THREE from 'three';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { adaptClip, hipsHeightOf, stripRootMotion } from './retarget';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { attachToHand, fastestHandMoment, prepareShield, prepareSword, SWORD_ATTACK_URLS } from './weapon';

const SKELETON_URL = '/models/skeleton.fbx';
// Yedek vuruş: Creature NPC Pack'teki pençe (kılıç vuruşları yüklenemezse)
const CLAW_URL = encodeURI('/models/Creature NPC Pack/mutant swiping.fbx');
// Ölçüm yapılamazsa kullanılan darbe anı (0..1)
const FALLBACK_HIT_MOMENT = 0.5;
// İskeletin kılıcı: boyu (uçtan kabzaya, metre) ve elin tuttuğu yer (bıçak ucundan boy oranı)
const SWORD_URL = '/models/sword2.glb';
const SWORD_LENGTH = 1;
const SWORD_GRIP = 0.89;
// Kalkan: boyu (metre) ve yüzünün sol elin hangi tarafına baktığı (1 ya da -1; denenerek bulundu:
// 1 iken süslü yüz gövdeye bakıyordu)
const SHIELD_URL = '/models/kalkan.glb';
const SHIELD_HEIGHT = 0.8;
const SHIELD_FACING: 1 | -1 = -1;
// Kalkanın ortası elden dirseğe doğru bu kadar (metre) kayık: ön kola bağlı gibi dursun
const SHIELD_TOWARD_ELBOW = 0.12;
// Kılıç ve kalkanın dokuları çok koyu (ortalama renk ~45-70 / 255) ve karanlık zeminde
// seçilmiyordu. Görünür olsunlar diye: yansıma gücü, metallik oranı (0..1, dokudakiyle çarpılır;
// düşükse ay ışığını daha çok alır) ve rengin kaç kat açıldığı.
const GEAR_SHINE = 1.6;
const GEAR_METALNESS = 0.5;
const GEAR_BRIGHTNESS = 1.8;
// Oyundaki boyu (metre)
const SKELETON_HEIGHT = 1.8;
// Dirilirken yayılan ışığın rengi
const GLOW_COLOR = 0x3cff9a;

/** Parlatılabilen malzeme (emissive özelliği olan) */
export type GlowMaterial = THREE.MeshStandardMaterial | THREE.MeshPhongMaterial;

/** İskeletin oynatabileceği animasyonlar, iskeletin boyuna uyarlanmış */
export interface SkeletonAnimations {
  idle: THREE.AnimationClip;
  walk: THREE.AnimationClip;
  // Vuruşlar: her biri animasyon ve darbenin indiği an (0..1). Hiçbiri yüklenemezse boş.
  attacks: { clip: THREE.AnimationClip; hitMoment: number }[];
  // Yürüme animasyonu normal hızda oynarken iskeletin saniyede kaç metre yürüdüğü.
  // Minion bundan hızlı yürürse animasyon da o oranda hızlandırılır, ayaklar kaymasın.
  walkSpeed: number;
}

export interface Skeleton {
  root: THREE.Group; // oyunun konumlandırıp döndürdüğü dış grup
  body: THREE.Group; // içteki grup: çizilmiş iskelette yürürken zıplatılıp sallanır
  // Her iskeletin kendi malzemeleri, ki sadece dirilen parlasın
  materials: GlowMaterial[];
  // Riglenmiş model ve animasyonları. Sadece model yüklendiyse var.
  model: THREE.Object3D | null;
  animations: SkeletonAnimations | null;
  // Kol ve bacakların dönme noktaları. Sadece çizilmiş iskelette var.
  limbs: { leftArm: THREE.Group; rightArm: THREE.Group; leftLeg: THREE.Group; rightLeg: THREE.Group } | null;
  eyes: THREE.Group | null;
  // Sırtüstü yatarken merkezin yerden yüksekliği (kemikler toprağa gömülmesin)
  lieHeight: number;
}

/** Karakterden alınan animasyonlar ve o animasyonların yapıldığı karakterin ölçüleri */
export interface SourceAnimations {
  idle: THREE.AnimationClip;
  walk: THREE.AnimationClip;
  hipsHeight: number; // karakterin kalça kemiğinin duruştaki yüksekliği (Mixamo birimi, cm)
  walkClipSpeed: number; // yürüme animasyonunda ayağın geriye kayma hızı (cm/sn)
}

// Yüklenip hazırlanmış model ve animasyonları. Her iskelet bunun kopyası.
let template: THREE.Object3D | null = null;
let templateAnimations: SkeletonAnimations | null = null;
let templateLieHeight = 0;
// Elde taşınan kılıç ve kalkan (pivot eksenine göre yerleşmiş). Her iskelete birer kopyası takılır.
let sword: THREE.Object3D | null = null;
let shield: THREE.Object3D | null = null;
// Kılıç ve kalkanın malzemeleri (kopyalarda ortak) ve yansıtacakları ortam (Game verir)
const gearMaterials: THREE.MeshStandardMaterial[] = [];
let environment: THREE.Texture | null = null;

/** Metal kılıç ve kalkanın yansıtacağı ortam haritasını ver (karakterin kılıcınınkiyle aynı) */
export function setSkeletonEnvironment(texture: THREE.Texture) {
  environment = texture;
  for (const material of gearMaterials) applyEnvironment(material);
}

function applyEnvironment(material: THREE.MeshStandardMaterial) {
  if (!environment) return;
  material.envMap = environment;
  material.envMapIntensity = GEAR_SHINE;
  material.needsUpdate = true;
}

// Kılıç ya da kalkan modelini yükle, gölge ve yansıma ayarlarını yap. Yüklenemezse null.
async function loadGear(url: string): Promise<THREE.Object3D | null> {
  try {
    const model = (await new GLTFLoader().loadAsync(url)).scene;
    model.traverse((child) => {
      if (!(child instanceof THREE.Mesh)) return;
      child.castShadow = true;
      if (child.material instanceof THREE.MeshStandardMaterial) {
        child.material.metalness = GEAR_METALNESS;
        child.material.color.setScalar(GEAR_BRIGHTNESS);
        gearMaterials.push(child.material);
        applyEnvironment(child.material);
      }
    });
    return model;
  } catch (error) {
    console.warn('İskeletin teçhizatı yüklenemedi:', url, error);
    return null;
  }
}

/** skeleton.fbx'i yükle ve karakterin animasyonlarını ona uyarla. Bitene kadar çizilmiş iskelet kullanılır. */
export async function loadSkeletonModel(source: SourceAnimations) {
  const loader = new FBXLoader();
  // Vuruş dosyası yüklenemezse iskelet yine çalışsın: o vuruş listede olmaz
  const optional = (url: string) =>
    loader.loadAsync(url).catch((error) => {
      console.warn('İskeletin vuruş animasyonu yüklenemedi:', url, error);
      return null;
    });
  const [model, swordModel, shieldModel, ...swordFiles] = await Promise.all([
    loader.loadAsync(SKELETON_URL),
    loadGear(SWORD_URL),
    loadGear(SHIELD_URL),
    ...SWORD_ATTACK_URLS.map(optional),
  ]);
  sword = swordModel && prepareSword(swordModel, SWORD_LENGTH, SWORD_GRIP);
  shield = shieldModel && prepareShield(shieldModel, SHIELD_HEIGHT, SHIELD_FACING, SHIELD_TOWARD_ELBOW);
  let attackFiles = swordFiles.filter((file) => file !== null);
  if (attackFiles.length === 0) {
    const claw = await optional(CLAW_URL);
    attackFiles = claw ? [claw] : [];
  }

  // Mixamo santimetre kullanır; boyu ölçüp SKELETON_HEIGHT'a ölçekle, ayakları zemine koy
  const box = new THREE.Box3().setFromObject(model);
  const scale = SKELETON_HEIGHT / (box.max.y - box.min.y);
  model.scale.setScalar(scale);
  model.position.y = -box.min.y * scale;
  templateLieHeight = ((box.max.z - box.min.z) * scale) / 2;

  model.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    child.castShadow = true;
    child.frustumCulled = false; // karakterdeki gibi: animasyonda yanlışlıkla gizlenmesin
    for (const material of materialsOf(child)) {
      material.emissive.set(GLOW_COLOR);
      material.emissiveIntensity = 0;
      if (material instanceof THREE.MeshPhongMaterial) material.shininess = 5; // kemik parlak plastik gibi durmasın
    }
  });

  // Animasyonlar karakter için yapıldı. İskelet daha kısa: kalça konumunu boy oranıyla küçült,
  // yoksa iskelet havada yürür. Rotasyonlar (kemiklerin dönüşü) olduğu gibi kalır.
  const hips = model.getObjectByName('mixamorigHips');
  const skeletonHips = hips ? hips.position.y : source.hipsHeight;
  const ratio = skeletonHips / source.hipsHeight;
  // Vuruşlar başka bir karakter için indirildi: oranı o dosyadaki iskeletin kalçasına göre hesapla.
  // Darbe anı, iskeletin sağ elinin en hızlı olduğu an ölçülerek bulunur.
  const attacks = attackFiles.map((file) => {
    const clip = file.animations[0];
    stripRootMotion(clip);
    const adapted = adaptClip(clip, model, skeletonHips / (hipsHeightOf(file) ?? skeletonHips));
    return { clip: adapted, hitMoment: fastestHandMoment(model, adapted, FALLBACK_HIT_MOMENT) };
  });
  templateAnimations = {
    idle: adaptClip(source.idle, model, ratio),
    walk: adaptClip(source.walk, model, ratio),
    attacks,
    walkSpeed: source.walkClipSpeed * ratio * scale,
  };
  template = model;
}

/** Yeni bir iskelet yarat: model hazırsa onun kopyası, değilse çizilmiş yedek */
export function createSkeleton(): Skeleton {
  return template ? cloneModel(template) : createDrawnSkeleton();
}

/** Yeşil parıltıyı ayarla (0 = yok, 1 = tam). İskelette de et yığınında da çalışır. */
export function setGlow(target: { materials: GlowMaterial[] }, intensity: number) {
  for (const material of target.materials) material.emissiveIntensity = intensity;
}

/** Bir mesh'in parlatılabilen malzemeleri (tek ya da liste olabilir) */
export function materialsOf(mesh: THREE.Mesh): GlowMaterial[] {
  const list = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
  return list.filter((m): m is GlowMaterial => m instanceof THREE.MeshStandardMaterial || m instanceof THREE.MeshPhongMaterial);
}

function cloneModel(source: THREE.Object3D): Skeleton {
  // Kemikli modeller normal clone() ile kopyalanamaz (kopya, eskisinin kemiklerine bağlı kalır).
  // SkeletonUtils.clone kemikleri de kopyalar; şekil (geometri) yine ortak, bellekte tek kopya durur.
  const model = SkeletonUtils.clone(source);
  // Malzemeyi ayrıca kopyalıyoruz ki bir iskeletin parlaması diğerlerine geçmesin (dokular ortak)
  const materials: GlowMaterial[] = [];
  model.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    const copies = materialsOf(child).map((material) => material.clone());
    child.material = copies.length === 1 ? copies[0] : copies;
    materials.push(...copies);
  });

  // Elde kılıç ve kalkan: birer kopya (şekli ve dokusu ortak), ele bağlı birer pivotun içinde
  if (sword) {
    const pivot = new THREE.Group();
    if (attachToHand(pivot, model, 'Right')) pivot.add(sword.clone());
  }
  if (shield) {
    const pivot = new THREE.Group();
    if (attachToHand(pivot, model, 'Left')) pivot.add(shield.clone());
  }

  const body = new THREE.Group();
  body.add(model);
  const root = new THREE.Group();
  root.add(body);
  return { root, body, materials, model, animations: templateAnimations, limbs: null, eyes: null, lieHeight: templateLieHeight };
}

// --- Yedek: basit şekillerden çizilmiş iskelet (boyu ≈ 1.75) ---

// Şekiller bütün çizilmiş iskeletlerde ortak (bellekte bir kez durur)
const BONE = new THREE.CylinderGeometry(0.035, 0.03, 1, 6); // boyu 1; kullanırken uzatılır
const JOINT = new THREE.SphereGeometry(1, 10, 8); // yarıçapı 1; kullanırken küçültülür
const BOX = new THREE.BoxGeometry(1, 1, 1);
const EYE_MATERIAL = new THREE.MeshBasicMaterial({ color: 0x7dffb0 }); // ışıktan etkilenmez, hep parlak

function createDrawnSkeleton(): Skeleton {
  const material = new THREE.MeshStandardMaterial({
    color: 0xd8cfbd,
    roughness: 0.85,
    emissive: GLOW_COLOR,
    emissiveIntensity: 0,
  });

  const body = new THREE.Group();
  const part = (geometry: THREE.BufferGeometry, x: number, y: number, z: number, sx: number, sy: number, sz: number) => {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(x, y, z);
    mesh.scale.set(sx, sy, sz);
    mesh.castShadow = true;
    return mesh;
  };

  // Gövde: leğen, omurga, göğüs kafesi, kafatası ve çene
  body.add(
    part(BOX, 0, 0.84, 0, 0.32, 0.1, 0.14), // leğen
    part(BONE, 0, 1.02, 0, 1, 0.36, 1), // omurga
    part(JOINT, 0, 1.27, 0, 0.19, 0.21, 0.12), // göğüs kafesi
    part(BOX, 0, 1.4, 0, 0.46, 0.05, 0.08), // omuz kemiği
    part(JOINT, 0, 1.62, 0, 0.12, 0.13, 0.13), // kafatası
    part(BOX, 0, 1.52, 0.04, 0.13, 0.05, 0.1), // çene
  );

  // Gözler: iki küçük yeşil nokta. Minionun hangi yöne baktığını da gösterir.
  const eyes = new THREE.Group();
  for (const x of [-0.045, 0.045]) {
    const eye = new THREE.Mesh(JOINT, EYE_MATERIAL);
    eye.position.set(x, 1.63, 0.1);
    eye.scale.setScalar(0.028);
    eyes.add(eye);
  }
  body.add(eyes);

  // Kol ya da bacak: dönme noktası eklemde, kemik aşağı doğru sarkıyor
  const limb = (x: number, y: number, length: number) => {
    const pivot = new THREE.Group();
    pivot.position.set(x, y, 0);
    pivot.add(part(BONE, 0, -length / 2, 0, 1, length, 1));
    body.add(pivot);
    return pivot;
  };
  const limbs = {
    leftArm: limb(0.24, 1.4, 0.7),
    rightArm: limb(-0.24, 1.4, 0.7),
    leftLeg: limb(0.12, 0.84, 0.84),
    rightLeg: limb(-0.12, 0.84, 0.84),
  };

  const root = new THREE.Group();
  root.add(body);
  return { root, body, materials: [material], model: null, animations: null, limbs, eyes, lieHeight: 0.13 };
}
