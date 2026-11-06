// Vampir modeli: public/models/Vampire A Lusth.fbx (Mixamo). Kemik adları karakterle aynı olduğu için
// karakterin bekleme (idle) ve vuruş (attack) animasyonlarını oynatır; yürüme için kendi Walking.fbx'i var.
// Davranış (dolaşma, vurulma, ölme) Enemy.ts'te; bu dosya sadece görünüşü hazırlar.

import * as THREE from 'three';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { adaptClip } from './retarget';
import { materialsOf, type GlowMaterial } from './Skeleton';

// Dosya adında boşluk var; encodeURI onu adrese uygun hale getirir (boşluk → %20)
const VAMPIRE_URL = encodeURI('/models/Vampire A Lusth.fbx');
// Vampir için indirilen yürüme animasyonu (Mixamo "Walking", vampir seçiliyken)
const WALK_URL = '/models/Walking.fbx';
// Oyundaki boyu (metre), karakterle aynı
const VAMPIRE_HEIGHT = 2;
// Vurulunca parlayacağı renk
const HIT_COLOR = 0xff4a4a;

/** Bir vampirin görünen kısmı: model, kendi malzemeleri ve animasyonları */
export interface VampireBody {
  model: THREE.Object3D;
  materials: GlowMaterial[];
  mixer: THREE.AnimationMixer;
  idle: THREE.AnimationAction;
  walk: THREE.AnimationAction;
  attack: THREE.AnimationAction; // bir kez oynar, son karesinde bekler
  // Yürüme animasyonu normal hızda oynarken vampirin saniyede kaç metre yürüdüğü.
  // Vampir başka hızda yürürse animasyon o oranda hızlandırılır, ayaklar kaymasın.
  walkSpeed: number;
}

// Yüklenip hazırlanmış model ve animasyonları
let template: THREE.Object3D | null = null;
let idleClip: THREE.AnimationClip | null = null;
let walkClip: THREE.AnimationClip | null = null;
let attackClip: THREE.AnimationClip | null = null;
let walkSpeed = 1;

/**
 * Vampir modelini ve yürüme animasyonunu yükle. idle, attack: karakterin bekleme ve vuruş
 * animasyonları; hipsHeight: karakterin kalça yüksekliği (Mixamo birimi). Bu animasyonlar
 * vampirin boyuna bu oranla uydurulur.
 */
export async function loadVampireModel(idle: THREE.AnimationClip, attack: THREE.AnimationClip, hipsHeight: number) {
  const loader = new FBXLoader();
  const [model, walkFile] = await Promise.all([loader.loadAsync(VAMPIRE_URL), loader.loadAsync(WALK_URL)]);

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
  const ratio = hips ? hips.position.y / hipsHeight : 1;
  idleClip = adaptClip(idle, model, ratio);
  attackClip = adaptClip(attack, model, ratio);

  // Yürüme animasyonu vampiri kendiliğinden öne taşıyor (root motion). Önce ne kadar taşıdığını
  // ölç (bu, animasyonun doğal hızı), sonra taşımayı kaldır: konumu biz yönetiyoruz.
  const raw = walkFile.animations[0];
  const hipsTrack = raw.tracks.find((track) => track.name === 'mixamorigHips.position');
  if (hipsTrack) {
    const v = hipsTrack.values;
    const distance = Math.hypot(v[v.length - 3] - v[0], v[v.length - 1] - v[2]); // santimetre
    walkSpeed = (distance / raw.duration) * scale; // metre/saniye
    for (let i = 0; i < v.length; i += 3) {
      v[i] = v[0]; // kalçanın yatay konumunu ilk karedeki yerde sabitle
      v[i + 2] = v[2];
    }
  }
  walkClip = adaptClip(raw, model, 1); // aynı vampir için indirildi: boy oranı 1
  template = model;
}

/** Yeni bir vampir. Model henüz yüklenmediyse (ya da hiç yoksa) null. */
export function createVampire(): VampireBody | null {
  if (!template || !idleClip || !walkClip || !attackClip) return null;

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

  const mixer = new THREE.AnimationMixer(model);
  const idle = mixer.clipAction(idleClip);
  const walk = mixer.clipAction(walkClip);
  const attack = mixer.clipAction(attackClip);
  attack.setLoop(THREE.LoopOnce, 1);
  attack.clampWhenFinished = true;
  idle.play();
  idle.time = Math.random() * idleClip.duration; // hepsi aynı anda kıpırdamasın
  return { model, materials, mixer, idle, walk, attack, walkSpeed };
}
