// Vampir modeli ve dövüş tarzları: public/models/Vampire A Lusth.fbx (Mixamo).
// Animasyonlar: karakterin idle'ı (kemik adları aynı), vampirin kendi Walking.fbx'i ve
// "Creature NPC Pack" (mutant idle, yürüme, koşma, pençe, kas gösterisi, ölüm).
// Karakterin kılıç vuruşu (attack.fbx) bilerek kullanılmıyor: o sadece necromancer'a ait.
// Her vampir rastgele bir dövüş tarzıyla doğar: hangi animasyonları kullandığı, ne kadar dayanıklı
// ve güçlü olduğu, ne hızla kovaladığı tarza göre değişir. Davranış Enemy.ts'te.

import * as THREE from 'three';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { adaptClip, stripRootMotion } from './retarget';
import { materialsOf, type GlowMaterial } from './Skeleton';

// Dosya adlarında boşluk var; encodeURI onları adrese uygun hale getirir (boşluk → %20)
const VAMPIRE_URL = encodeURI('/models/Vampire A Lusth.fbx');
const WALK_URL = '/models/Walking.fbx';
const packUrl = (name: string) => encodeURI(`/models/Creature NPC Pack/${name}.fbx`);
// Oyundaki boyu (metre), karakterle aynı; tarzına göre biraz büyür ya da küçülür
const VAMPIRE_HEIGHT = 2;
// Vurulunca parlayacağı renk
const HIT_COLOR = 0xff4a4a;

// Pençe saldırısında darbenin indiği an (0..1). Elin en hızlı hareket ettiği an ölçüldü:
// 2.43 sn'lik animasyonun 1.28. saniyesi.
export const SWIPE_HIT_MOMENT = 0.53;

type MoveName = 'walk' | 'mutantWalk' | 'run';

/** Bir dövüş tarzı: vampirin nasıl dövüştüğünü belirleyen sayılar ve animasyon seçimleri */
interface FightStyle {
  name: string;
  health: number; // can
  damage: number; // bir vuruşun hasarı
  size: number; // boy çarpanı (1 = normal)
  wander: MoveName[]; // dolaşırken kullanabileceği yürüyüşler (biri rastgele seçilir)
  chase: MoveName; // kovalarken
  chaseSpeed: number; // kovalama hızı (metre/sn; karakter 3)
  attackSpeed: number; // pençe animasyonunun hız çarpanı (büyük = hızlı vuruş)
  cooldown: number; // iki vuruş arası mola (saniye)
  taunts: boolean; // karakteri ilk fark edince kas gösterisi yapar mı
}

const STYLES: FightStyle[] = [
  {
    name: 'Avcı', // dengeli: yürüyerek kovalar, orta hızda vurur
    health: 30, damage: 6, size: 1,
    wander: ['walk', 'mutantWalk'], chase: 'walk', chaseSpeed: 2,
    attackSpeed: 1.15, cooldown: 0.7, taunts: false,
  },
  {
    name: 'Vahşi', // iri ve dayanıklı: kas gösterir, koşar, pençesi ağır ama yavaş
    health: 40, damage: 10, size: 1.12,
    wander: ['mutantWalk'], chase: 'run', chaseSpeed: 2.6,
    attackSpeed: 0.85, cooldown: 1.2, taunts: true,
  },
  {
    name: 'Çevik', // zayıf ama hızlı: koşar, kısa aralarla seri vurur
    health: 22, damage: 4, size: 0.92,
    wander: ['walk'], chase: 'run', chaseSpeed: 2.8,
    attackSpeed: 1.6, cooldown: 0.3, taunts: false,
  },
  {
    name: 'Muhafız', // çok dayanıklı, yavaş: kas gösterir, ağır ağır vurur
    health: 50, damage: 7, size: 1.05,
    wander: ['mutantWalk'], chase: 'mutantWalk', chaseSpeed: 1.6,
    attackSpeed: 0.95, cooldown: 0.9, taunts: true,
  },
];

/** Bir saldırı hareketi: animasyonu ve darbenin hangi anında indiği */
export interface VampireAttack {
  action: THREE.AnimationAction;
  hitMoment: number;
}

/** Bir vampirin görünen kısmı, animasyonları ve dövüş tarzının sayıları */
export interface VampireBody {
  model: THREE.Object3D;
  materials: GlowMaterial[];
  mixer: THREE.AnimationMixer;
  style: string; // tarzın adı (konsolda görünür)
  health: number;
  damage: number;
  cooldown: number;
  idle: THREE.AnimationAction;
  walk: THREE.AnimationAction;
  walkSpeed: number; // yürüme animasyonu normal hızda oynarken kaç m/sn yürüdüğü
  chase: THREE.AnimationAction;
  chaseClipSpeed: number; // kovalama animasyonunun kendi hızı (m/sn)
  chaseSpeed: number; // gerçekte ne hızla kovaladığı (m/sn)
  attacks: VampireAttack[]; // her vuruşta biri rastgele seçilir (şimdilik sadece pençe)
  taunt: THREE.AnimationAction | null; // kas gösterisi; tarzı yapmıyorsa null
  death: THREE.AnimationAction | null; // ölüm animasyonu; dosya yoksa null (o zaman devrilir)
}

// Yürüme/koşma animasyonu ve onun doğal hızı (m/sn, vampirin ölçeğinde)
interface MoveClip {
  clip: THREE.AnimationClip;
  speed: number;
}

// Yüklenip hazırlanmış model ve bütün animasyonlar
let template: THREE.Object3D | null = null;
let modelScale = 1;
let idleClips: THREE.AnimationClip[] = [];
let moveClips: Partial<Record<MoveName, MoveClip>> = {};
let swipeClip: THREE.AnimationClip | null = null;
let tauntClip: THREE.AnimationClip | null = null;
let deathClip: THREE.AnimationClip | null = null;

/**
 * Vampir modelini ve animasyonlarını yükle. idle: karakterin bekleme animasyonu;
 * hipsHeight: karakterin kalça yüksekliği (Mixamo birimi). Bekleme animasyonu vampirin boyuna
 * bu oranla uydurulur. Paketten yüklenemeyen animasyon olursa o hareket kullanılmaz.
 */
export async function loadVampireModel(idle: THREE.AnimationClip, hipsHeight: number) {
  const loader = new FBXLoader();
  const [model, walkFile] = await Promise.all([loader.loadAsync(VAMPIRE_URL), loader.loadAsync(WALK_URL)]);
  // Paket dosyaları: biri bozuksa diğerleri yine kullanılsın diye tek tek, hata yakalanarak
  const packNames = ['mutant idle', 'mutant breathing idle', 'mutant walking', 'mutant run', 'mutant swiping', 'mutant flexing muscles', 'mutant dying'];
  const pack = await Promise.all(
    packNames.map((name) =>
      loader.loadAsync(packUrl(name)).then(
        (file) => file.animations[0],
        (error) => {
          console.warn(`Vampir animasyonu yüklenemedi: ${name}`, error);
          return null;
        },
      ),
    ),
  );
  const [mutantIdle, breathingIdle, mutantWalk, run, swipe, flex, dying] = pack;

  // Mixamo santimetre kullanır; boyu ölçüp VAMPIRE_HEIGHT'a ölçekle, ayakları zemine koy
  const box = new THREE.Box3().setFromObject(model);
  modelScale = VAMPIRE_HEIGHT / (box.max.y - box.min.y);
  model.scale.setScalar(modelScale);
  model.position.y = -box.min.y * modelScale;

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

  // Karakterden gelen animasyonları vampirin boyuna uydur; paket ve Walking zaten vampir için indirildi
  const hips = model.getObjectByName('mixamorigHips');
  const ratio = hips ? hips.position.y / hipsHeight : 1;
  const own = (clip: THREE.AnimationClip | null) => (clip ? adaptClip(clip, model, 1) : null);

  idleClips = [adaptClip(idle, model, ratio), own(mutantIdle), own(breathingIdle)].filter((c) => c !== null);
  moveClips = {};
  for (const [name, clip] of [['walk', walkFile.animations[0]], ['mutantWalk', mutantWalk], ['run', run]] as const) {
    if (clip) moveClips[name] = { speed: stripRootMotion(clip) * modelScale, clip: adaptClip(clip, model, 1) };
  }
  if (swipe) stripRootMotion(swipe);
  swipeClip = own(swipe);
  tauntClip = own(flex);
  deathClip = own(dying);
  template = model;
}

// Tarz torbası: tarzlar karıştırılıp sırayla dağıtılır, torba boşalınca yeniden doldurulur.
// Tamamen rastgele seçseydik 5 vampirin hepsi aynı tarzda çıkabilirdi; böylece hepsi farklı olur
// (tarz sayısından çok vampir varsa ancak o zaman tekrar eder).
let styleBag: FightStyle[] = [];
function nextStyle(): FightStyle {
  if (styleBag.length === 0) styleBag = shuffle(STYLES);
  return styleBag.pop() ?? STYLES[0];
}

/** Bir sonraki dövüş tarzıyla yeni bir vampir. Model henüz yüklenmediyse (ya da hiç yoksa) null. */
export function createVampire(): VampireBody | null {
  const fallbackMove = moveClips.walk ?? moveClips.mutantWalk;
  // Pençe yoksa vampir saldıramaz; o zaman yedek taş olarak kalsın
  if (!template || idleClips.length === 0 || !fallbackMove || !swipeClip) return null;
  const style = nextStyle();

  // SkeletonUtils.clone kemikleri de kopyalar, ki her vampir kendi başına hareket etsin
  const model = SkeletonUtils.clone(template);
  model.scale.setScalar(modelScale * style.size);
  model.position.y *= style.size;
  // Malzemeleri ayrıca kopyala ki sadece vurulan parlasın (dokular ortak kalır)
  const materials: GlowMaterial[] = [];
  model.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    const copies = materialsOf(child).map((material) => material.clone());
    child.material = copies.length === 1 ? copies[0] : copies;
    materials.push(...copies);
  });

  const mixer = new THREE.AnimationMixer(model);
  const once = (clip: THREE.AnimationClip, timeScale = 1) => {
    const action = mixer.clipAction(clip);
    action.setLoop(THREE.LoopOnce, 1); // bir kez oynar ve son karesinde bekler
    action.clampWhenFinished = true;
    action.timeScale = timeScale;
    return action;
  };

  // Bekleme duruşu: tarzdan bağımsız, rastgele (her vampir biraz farklı dursun)
  const idleClip = pick(idleClips);
  const idle = mixer.clipAction(idleClip);
  idle.play();
  idle.time = Math.random() * idleClip.duration; // hepsi aynı anda kıpırdamasın

  const wander = moveClips[pick(style.wander)] ?? fallbackMove;
  const chase = moveClips[style.chase] ?? wander;
  const attacks = [{ action: once(swipeClip, style.attackSpeed), hitMoment: SWIPE_HIT_MOMENT }];

  // Animasyonun kendi hızı boy çarpanıyla değişir: büyük vampirin adımı da büyük
  return {
    model,
    materials,
    mixer,
    style: style.name,
    health: style.health,
    damage: style.damage,
    cooldown: style.cooldown,
    idle,
    walk: mixer.clipAction(wander.clip),
    walkSpeed: wander.speed * style.size,
    chase: mixer.clipAction(chase.clip),
    chaseClipSpeed: chase.speed * style.size,
    chaseSpeed: style.chaseSpeed,
    attacks,
    taunt: style.taunts && tauntClip ? once(tauntClip, 1.5) : null,
    death: deathClip ? once(deathClip) : null,
  };
}

// Listenin karıştırılmış kopyası (Fisher-Yates: sondan başa, her elemanı rastgele bir öncekiyle değiştir)
function shuffle<T>(list: readonly T[]): T[] {
  const copy = [...list];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function pick<T>(list: readonly T[]): T {
  return list[Math.floor(Math.random() * list.length)];
}
