// İskelet: hem yerde yatan ceset hem de dirilen minion bunu kullanır.
// public/models/skeleton.glb yüklendiyse o model kopyalanır; yüklenmediyse basit şekillerden
// (küre, silindir, kutu) çizilmiş yedek iskelet kullanılır.
// Ölçüler metre; ayaklar y = 0'da, yüz +z yönüne bakıyor.

import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const SKELETON_URL = '/models/skeleton.glb';
// Oyundaki boyu (metre)
const SKELETON_HEIGHT = 1.8;
// Model T-pozunda (kollar iki yana açık). Kolları omuzdan bu kadar aşağı indiriyoruz (radyan, ≈78°).
const ARM_DROP = 1.36;
// Omzun modeldeki yeri (modelin kendi biriminde, ölçülerek bulundu): kollar |x| > 0.105'ten
// başlıyor ve y ≈ 0.30 hizasında uzanıyor. Geçiş bölgesindeki noktalar kısmen döner, kopukluk olmaz.
const SHOULDER_X = 0.105;
const SHOULDER_Y = 0.3;
const SHOULDER_BLEND = 0.015;
// Dirilirken yayılan ışığın rengi
const GLOW_COLOR = 0x3cff9a;

export interface Skeleton {
  root: THREE.Group; // oyunun konumlandırıp döndürdüğü dış grup
  body: THREE.Group; // içteki grup: yürürken zıplatılıp sallanır
  // Her iskeletin kendi malzemeleri, ki sadece dirilen parlasın
  materials: THREE.MeshStandardMaterial[];
  // Kol ve bacakların dönme noktaları. Sadece çizilmiş iskelette var; model tek parça.
  limbs: { leftArm: THREE.Group; rightArm: THREE.Group; leftLeg: THREE.Group; rightLeg: THREE.Group } | null;
  eyes: THREE.Group | null;
  // Sırtüstü yatarken merkezin yerden yüksekliği (kemikler toprağa gömülmesin)
  lieHeight: number;
}

// Yüklenip hazırlanmış model (ölçeklenmiş, kolları indirilmiş). Her iskelet bunun kopyası.
let template: THREE.Object3D | null = null;
let templateDepth = 0;

/** skeleton.glb'yi yükle ve hazırla. Bitene kadar (ya da hiç yüklenmezse) çizilmiş iskelet kullanılır. */
export async function loadSkeletonModel() {
  const gltf = await new GLTFLoader().loadAsync(SKELETON_URL);
  const model = gltf.scene;
  model.updateMatrixWorld(true);

  model.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    // Konum/dönüşü noktalara işle, ki ölçümler (omuz yeri) modelin kendi biriminde doğru olsun
    child.geometry.applyMatrix4(child.matrixWorld);
    child.position.set(0, 0, 0);
    child.rotation.set(0, 0, 0);
    child.scale.set(1, 1, 1);
    lowerArms(child.geometry);
    child.castShadow = true;
    // Model "metal" olarak işaretli; yansıtacak ortam olmadığı için simsiyah görünürdü. Kemik metal değil.
    const material = child.material as THREE.MeshStandardMaterial;
    material.metalness = 0;
    material.emissive.set(GLOW_COLOR);
    material.emissiveIntensity = 0;
  });
  model.position.set(0, 0, 0);
  model.rotation.set(0, 0, 0);
  model.scale.set(1, 1, 1);

  // Boyu ölç, SKELETON_HEIGHT'a ölçekle, ayakları zemine ve ortayı x-z'de merkeze koy
  const box = new THREE.Box3().setFromObject(model);
  const scale = SKELETON_HEIGHT / (box.max.y - box.min.y);
  const center = box.getCenter(new THREE.Vector3());
  model.scale.setScalar(scale);
  model.position.set(-center.x * scale, -box.min.y * scale, -center.z * scale);

  templateDepth = (box.max.z - box.min.z) * scale;
  template = model;
}

/** Yeni bir iskelet yarat: model hazırsa onun kopyası, değilse çizilmiş yedek */
export function createSkeleton(): Skeleton {
  return template ? cloneModel(template) : createDrawnSkeleton();
}

/** İskeletin yeşil parıltısını ayarla (0 = yok, 1 = tam) */
export function setGlow(skeleton: Skeleton, intensity: number) {
  for (const material of skeleton.materials) material.emissiveIntensity = intensity;
}

// Kolları T-pozundan aşağı indir: omzun dışındaki her noktayı omuz etrafında döndür.
// Modelde kemik (rig) olmadığı için bunu noktaları bir kez kaydırarak yapıyoruz.
function lowerArms(geometry: THREE.BufferGeometry) {
  const position = geometry.attributes.position;
  const normal = geometry.attributes.normal as THREE.BufferAttribute | undefined;
  const point = new THREE.Vector3();
  const axis = new THREE.Vector3(0, 0, 1); // öne bakan eksen: kol bunun etrafında aşağı döner

  for (let i = 0; i < position.count; i++) {
    point.fromBufferAttribute(position, i);
    const side = Math.sign(point.x); // +1 sol kol, -1 sağ kol
    // 0 = gövde (dönmez), 1 = kol (tam döner); omuz çevresinde yumuşak geçiş.
    // İki koşul: omzun dışında olmak (x) ve omuz hizasında olmak (y). İkincisi olmazsa
    // aynı x'teki kalça ve bacaklar da dönerdi.
    const outside = THREE.MathUtils.smoothstep(Math.abs(point.x), SHOULDER_X - SHOULDER_BLEND, SHOULDER_X + SHOULDER_BLEND);
    const high = THREE.MathUtils.smoothstep(point.y, SHOULDER_Y - 0.1, SHOULDER_Y - 0.05);
    const weight = outside * high;
    if (weight === 0) continue;
    const angle = -side * ARM_DROP * weight;

    // Omzu orijine al, döndür, geri koy
    point.x -= side * SHOULDER_X;
    point.y -= SHOULDER_Y;
    point.applyAxisAngle(axis, angle);
    point.x += side * SHOULDER_X;
    point.y += SHOULDER_Y;
    position.setXYZ(i, point.x, point.y, point.z);

    // Yüzeyin baktığı yön (ışıklandırma için) de aynı açıyla dönmeli
    if (normal) {
      point.fromBufferAttribute(normal, i).applyAxisAngle(axis, angle);
      normal.setXYZ(i, point.x, point.y, point.z);
    }
  }
  position.needsUpdate = true;
  if (normal) normal.needsUpdate = true;
  geometry.computeBoundingBox();
  geometry.computeBoundingSphere();
}

function cloneModel(source: THREE.Object3D): Skeleton {
  // clone() şekli (geometri) paylaşır, bellekte tek kopya durur. Malzemeyi ayrıca kopyalıyoruz
  // ki bir iskeletin parlaması diğerlerine geçmesin (dokular yine ortak).
  const model = source.clone();
  const materials: THREE.MeshStandardMaterial[] = [];
  model.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    const material = (child.material as THREE.MeshStandardMaterial).clone();
    child.material = material;
    materials.push(material);
  });

  const body = new THREE.Group();
  body.add(model);
  const root = new THREE.Group();
  root.add(body);
  return { root, body, materials, limbs: null, eyes: null, lieHeight: templateDepth / 2 };
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
  return { root, body, materials: [material], limbs, eyes, lieHeight: 0.13 };
}
