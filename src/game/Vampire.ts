// Vampir: mezar taşlarının yerinde duran düşman. Model: public/models/Vampire A Lusth.fbx (Mixamo).
// Kemik adları karakterle aynı olduğu için karakterin bekleme (idle) animasyonunu oynatır.
// Şimdilik karşılık vermiyor; vurulunca sarsılıp kırmızı parlıyor, ölünce et yığını bırakıyor.

import * as THREE from 'three';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { adaptClip } from './retarget';
import { materialsOf, type GlowMaterial } from './Skeleton';

// Dosya adında boşluk var; encodeURI onu adrese uygun hale getirir (boşluk → %20)
const VAMPIRE_URL = encodeURI('/models/Vampire A Lusth.fbx');
// Oyundaki boyu (metre), karakterle aynı
const VAMPIRE_HEIGHT = 2;
// Vurulunca parlayacağı renk
const HIT_COLOR = 0xff4a4a;

/** Bir vampirin görünen kısmı: model, kendi malzemeleri ve animasyon oynatıcısı */
export interface VampireBody {
  model: THREE.Object3D;
  materials: GlowMaterial[];
  mixer: THREE.AnimationMixer | null;
}

// Yüklenip hazırlanmış model ve ona uyarlanmış bekleme animasyonu
let template: THREE.Object3D | null = null;
let idleClip: THREE.AnimationClip | null = null;

/**
 * Vampir modelini yükle. idle: karakterin bekleme animasyonu, hipsHeight: karakterin kalça
 * yüksekliği (Mixamo birimi). Animasyon vampirin boyuna bu oranla uydurulur.
 */
export async function loadVampireModel(idle: THREE.AnimationClip, hipsHeight: number) {
  const model = await new FBXLoader().loadAsync(VAMPIRE_URL);

  // Mixamo santimetre kullanır; boyu ölçüp VAMPIRE_HEIGHT'a ölçekle, ayakları zemine koy
  const box = new THREE.Box3().setFromObject(model);
  const scale = VAMPIRE_HEIGHT / (box.max.y - box.min.y);
  model.scale.setScalar(scale);
  model.position.y = -box.min.y * scale;

  model.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    child.castShadow = true;
    child.receiveShadow = true;
    child.frustumCulled = false; // iskeletli model: animasyonda yanlışlıkla gizlenmesin
    for (const material of materialsOf(child)) {
      material.emissive.set(HIT_COLOR);
      material.emissiveIntensity = 0;
    }
  });

  const hips = model.getObjectByName('mixamorigHips');
  idleClip = adaptClip(idle, model, hips ? hips.position.y / hipsHeight : 1);
  template = model;
}

/** Yeni bir vampir. Model henüz yüklenmediyse (ya da hiç yoksa) null. */
export function createVampire(): VampireBody | null {
  if (!template) return null;

  // SkeletonUtils.clone kemikleri de kopyalar, ki her vampir kendi başına hareket etsin
  const model = SkeletonUtils.clone(template);
  // Malzemeleri ayrıca kopyala ki sadece vurulan parlasın (dokular ortak kalır)
  const materials: GlowMaterial[] = [];
  model.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    const copies = materialsOf(child).map((material) => material.clone());
    child.material = copies.length === 1 ? copies[0] : copies;
    materials.push(...copies);
  });

  let mixer: THREE.AnimationMixer | null = null;
  if (idleClip) {
    mixer = new THREE.AnimationMixer(model);
    const idle = mixer.clipAction(idleClip);
    idle.play();
    idle.time = Math.random() * idleClip.duration; // hepsi aynı anda kıpırdamasın
  }
  return { model, materials, mixer };
}
