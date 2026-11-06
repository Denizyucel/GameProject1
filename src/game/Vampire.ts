// Vampir modeli ve dövüş tarzları: public/models/Vampire A Lusth.fbx (Mixamo).
// Animasyonlar: karakterin idle ve attack'ı (kemik adları aynı), vampirin kendi Walking.fbx'i ve
// "Creature NPC Pack" (mutant idle, yürüme, koşma, pençe, kas gösterisi, ölüm).
// Her vampir rastgele bir dövüş tarzıyla doğar: hangi animasyonları kullandığı, ne kadar dayanıklı
// ve güçlü olduğu, ne hızla kovaladığı tarza göre değişir. Davranış Enemy.ts'te.

import * as THREE from 'three';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { adaptClip } from './retarget';
import { materialsOf, type GlowMaterial } from './Skeleton';

// Dosya adlarında boşluk var; encodeURI onları adrese uygun hale getirir (boşluk → %20)
const VAMPIRE_URL = encodeURI('/models/Vampire A Lusth.fbx');
const WALK_URL = '/models/Walking.fbx';
const packUrl = (name: string) => encodeURI(`/models/Creature NPC Pack/${name}.fbx`);
// Oyundaki boyu (metre), karakterle aynı; tarzına göre biraz büyür ya da küçülür
const VAMPIRE_HEIGHT = 2;
// Vurulunca parlayacağı renk
const HIT_COLOR = 0xff4a4a;

// Saldırı animasyonlarında darbenin indiği an (0..1). Elin en hızlı hareket ettiği an ölçüldü.
const SWORD_HIT_MOMENT = 0.45; // karakterin kılıç vuruşu
const SWIPE_HIT_MOMENT = 0.53; // pençe: 2.43 sn'lik animasyonun 1.28. saniyesi

type AttackName = 'sword' | 'swipe';
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
  attacks: AttackName[]; // her vuruşta bunlardan biri rastgele seçilir
  attackSpeed: number; // saldırı animasyonunun hız çarpanı
  cooldown: number; // iki vuruş arası mola (saniye)
  taunts: boolean; // karakteri ilk fark edince kas gösterisi yapar mı
}

const STYLES: FightStyle[] = [
  {
    name: 'Kılıççı', // dengeli: kılıçla vurur, yürüyerek kovalar
    health: 30, damage: 6, size: 1,
    wander: ['walk', 'mutantWalk'], chase: 'walk', chaseSpeed: 2,
    attacks: ['sword'], attackSpeed: 1, cooldown: 0.7, taunts: false,
  },
  {
    name: 'Vahşi', // iri ve dayanıklı: kas gösterir, koşar, pençesi ağır ama yavaş
    health: 40, damage: 10, size: 1.12,
    wander: ['mutantWalk'], chase: 'run', chaseSpeed: 2.6,
    attacks: ['swipe'], attackSpeed: 1, cooldown: 1.2, taunts: true,
  },
  {
    name: 'Çevik', // zayıf ama hızlı: koşar, kılıç ve pençeyi karışık, sık sık vurur
    health: 22, damage: 4, size: 0.92,
    wander: ['walk'], chase: 'run', chaseSpeed: 2.8,
    attacks: ['sword', 'swipe'], attackSpeed: 1.4, cooldown: 0.3, taunts: false,
  },
  {
    name: 'Muhafız', // çok dayanıklı, yavaş: kas gösterir, iki saldırıyı karışık kullanır
    health: 50, damage: 7, size: 1.05,
    wander: ['mutantWalk'], chase: 'mutantWalk', chaseSpeed: 1.6,
    attacks: ['sword', 'swipe'], attackSpeed: 0.9, cooldown: 0.9, taunts: true,
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
  attacks: VampireAttack[]; // her vuruşta biri rastgele seçilir
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
let attackClips: Partial<Record<AttackName, THREE.AnimationClip>> = {};
let tauntClip: THREE.AnimationClip | null = null;
let deathClip: THREE.AnimationClip | null = null;

/**
 * Vampir modelini ve animasyonlarını yükle. idle, attack: karakterin bekleme ve vuruş
 * animasyonları; hipsHeight: karakterin kalça yüksekliği (Mixamo birimi). Bu ikisi vampirin
 * boyuna bu oranla uydurulur. Paketten yüklenemeyen animasyon olursa o hareket kullanılmaz.
 */
export async function loadVampireModel(idle: THREE.AnimationClip, attack: THREE.AnimationClip, hipsHeight: number) {
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
  attackClips = { sword: adaptClip(attack, model, ratio) };
  if (swipe) {
    stripRootMotion(swipe);
    attackClips.swipe = adaptClip(swipe, model, 1);
  }
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
  if (!template || idleClips.length === 0 || !fallbackMove || !attackClips.sword) return null;
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
  const attacks = style.attacks
    .map((name) => attackClips[name] && { action: once(attackClips[name], style.attackSpeed), hitMoment: name === 'sword' ? SWORD_HIT_MOMENT : SWIPE_HIT_MOMENT })
    .filter((attack) => !!attack);
  if (attacks.length === 0) attacks.push({ action: once(attackClips.sword, style.attackSpeed), hitMoment: SWORD_HIT_MOMENT });

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

// Animasyonun karakteri kendiliğinden öne taşımasını (root motion) kaldır ve ne kadar taşıdığını
// döndür (santimetre/saniye). Kalçanın yatay konumu ilk karedeki yerde sabitlenir.
function stripRootMotion(clip: THREE.AnimationClip): number {
  const hips = clip.tracks.find((track) => track.name === 'mixamorigHips.position');
  if (!hips) return 0;
  const v = hips.values;
  const distance = Math.hypot(v[v.length - 3] - v[0], v[v.length - 1] - v[2]);
  for (let i = 0; i < v.length; i += 3) {
    v[i] = v[0];
    v[i + 2] = v[2];
  }
  return distance / clip.duration;
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
