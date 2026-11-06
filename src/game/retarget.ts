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
