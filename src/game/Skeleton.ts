// Basit şekillerden (küre, silindir, kutu) çizilmiş iskelet. Hem yerde yatan ceset hem de
// dirilen minion bunu kullanır. Gerçek model gelene kadar yer tutucu.
// Ölçüler metre; ayaklar y = 0'da, yüz +z yönüne bakıyor. Boyu ≈ 1.75.

import * as THREE from 'three';

// Şekiller bütün iskeletlerde ortak (bellekte bir kez durur)
const BONE = new THREE.CylinderGeometry(0.035, 0.03, 1, 6); // boyu 1; kullanırken uzatılır
const JOINT = new THREE.SphereGeometry(1, 10, 8); // yarıçapı 1; kullanırken küçültülür
const BOX = new THREE.BoxGeometry(1, 1, 1);

const EYE_MATERIAL = new THREE.MeshBasicMaterial({ color: 0x7dffb0 }); // ışıktan etkilenmez, hep parlak

export interface Skeleton {
  root: THREE.Group;
  // Her iskeletin kendi malzemesi, ki sadece dirilen parlasın
  material: THREE.MeshStandardMaterial;
  // Kol ve bacakların dönme noktaları (omuz ve kalça). Yürürken bunlar sallanır.
  leftArm: THREE.Group;
  rightArm: THREE.Group;
  leftLeg: THREE.Group;
  rightLeg: THREE.Group;
  eyes: THREE.Group;
}

export function createSkeleton(): Skeleton {
  const material = new THREE.MeshStandardMaterial({
    color: 0xd8cfbd,
    roughness: 0.85,
    emissive: 0x3cff9a, // dirilirken yayacağı yeşil ışık
    emissiveIntensity: 0,
  });

  const root = new THREE.Group();
  const part = (geometry: THREE.BufferGeometry, x: number, y: number, z: number, sx: number, sy: number, sz: number) => {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(x, y, z);
    mesh.scale.set(sx, sy, sz);
    mesh.castShadow = true;
    return mesh;
  };

  // Gövde: leğen, omurga, göğüs kafesi, kafatası ve çene
  root.add(
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
  root.add(eyes);

  // Kol ya da bacak: dönme noktası eklemde, kemik aşağı doğru sarkıyor
  const limb = (x: number, y: number, length: number) => {
    const pivot = new THREE.Group();
    pivot.position.set(x, y, 0);
    pivot.add(part(BONE, 0, -length / 2, 0, 1, length, 1));
    root.add(pivot);
    return pivot;
  };

  return {
    root,
    material,
    leftArm: limb(0.24, 1.4, 0.7),
    rightArm: limb(-0.24, 1.4, 0.7),
    leftLeg: limb(0.12, 0.84, 0.84),
    rightLeg: limb(-0.12, 0.84, 0.84),
    eyes,
  };
}
