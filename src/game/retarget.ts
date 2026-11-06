// Bir Mixamo karakteri için indirilen animasyonu, aynı kemik adlarına sahip başka bir modele uydurur.
// Kemiklerin dönüşleri olduğu gibi kalır; sadece kalçanın konumu boy farkına göre ölçeklenir.

import type * as THREE from 'three';

/**
 * clip'in kopyasını model için uyarla:
 * - modelde olmayan kemiklerin izlerini at (kalsalar konsolda uyarı verirler)
 * - kalça konumunu ratio ile çarp (ratio = hedef modelin kalça yüksekliği / kaynak modelinki);
 *   yoksa kısa model havada, uzun model yere gömülü yürür
 */
export function adaptClip(clip: THREE.AnimationClip, model: THREE.Object3D, ratio: number): THREE.AnimationClip {
  const adapted = clip.clone(); // kaynak animasyon bozulmasın diye kopya
  adapted.tracks = adapted.tracks.filter((track) => model.getObjectByName(track.name.split('.')[0]));
  const hips = adapted.tracks.find((track) => track.name === 'mixamorigHips.position');
  if (hips) for (let i = 0; i < hips.values.length; i++) hips.values[i] *= ratio;
  return adapted;
}

/**
 * Animasyonun karakteri kendiliğinden öne taşımasını (root motion) kaldır ve ne kadar taşıdığını
 * döndür (Mixamo birimi/saniye, yani cm/sn). Kalçanın yatay konumu ilk karedeki yerde sabitlenir;
 * yukarı-aşağı hareketi kalır. Konumu oyun kodu yönetiyor.
 */
export function stripRootMotion(clip: THREE.AnimationClip): number {
  const hips = clip.tracks.find((track) => track.name === 'mixamorigHips.position');
  if (!hips) return 0;
  const v = hips.values; // [x, y, z, x, y, z, ...] her kare için üç sayı
  const distance = Math.hypot(v[v.length - 3] - v[0], v[v.length - 1] - v[2]);
  for (let i = 0; i < v.length; i += 3) {
    v[i] = v[0];
    v[i + 2] = v[2];
  }
  return distance / clip.duration;
}

/** Bir Mixamo animasyon dosyasındaki iskeletin kalça yüksekliği (dosya hangi karakter için indirildiyse onun) */
export function hipsHeightOf(file: THREE.Object3D): number | null {
  const hips = file.getObjectByName('mixamorigHips');
  return hips ? hips.position.y : null;
}
