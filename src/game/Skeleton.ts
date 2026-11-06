// İskelet: hem yerde yatan ceset hem de dirilen minion bunu kullanır.
// public/models/skeleton.fbx (Mixamo'da riglenmiş) yüklendiyse o model kopyalanır ve karakterin
// yürüme/bekleme animasyonlarını oynatır. Yüklenmediyse basit şekillerden çizilmiş yedek iskelet kullanılır.
// Ölçüler metre; ayaklar y = 0'da, yüz +z yönüne bakıyor.

import * as THREE from 'three';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';

const SKELETON_URL = '/models/skeleton.fbx';
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

/** skeleton.fbx'i yükle ve karakterin animasyonlarını ona uyarla. Bitene kadar çizilmiş iskelet kullanılır. */
export async function loadSkeletonModel(source: SourceAnimations) {
  const model = await new FBXLoader().loadAsync(SKELETON_URL);

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
  const ratio = hips ? hips.position.y / source.hipsHeight : 1;
  templateAnimations = {
    idle: adaptClip(source.idle, model, ratio),
    walk: adaptClip(source.walk, model, ratio),
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

// Animasyonu iskelete uydur: kalça konumunu oranla, iskelette olmayan kemiklerin izlerini at
// (karakterin pelerin kemikleri gibi; kalsalar konsolda uyarı verirler)
function adaptClip(clip: THREE.AnimationClip, model: THREE.Object3D, ratio: number): THREE.AnimationClip {
  const adapted = clip.clone(); // karakterin kendi animasyonu bozulmasın diye kopya
  adapted.tracks = adapted.tracks.filter((track) => model.getObjectByName(track.name.split('.')[0]));
  const hips = adapted.tracks.find((track) => track.name === 'mixamorigHips.position');
  if (hips) for (let i = 0; i < hips.values.length; i++) hips.values[i] *= ratio;
  return adapted;
}

function materialsOf(mesh: THREE.Mesh): GlowMaterial[] {
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
