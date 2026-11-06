// Et yığını: kırılan mezar taşının bıraktığı ceset. Necromancer iskeleti bunun içinden diriltir.
// Model: public/models/flesh.glb (Meshy). Kemiksiz, hareketsiz; yerde durur.

import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const FLESH_URL = '/models/flesh.glb';
// Yığının oyundaki boyu: zeminde kapladığı en uzun kenar (metre)
const FLESH_SIZE = 1.1;
// Dirilirken yayılan ışığın rengi (iskeletle aynı)
const GLOW_COLOR = 0x3cff9a;

export interface Flesh {
  root: THREE.Group;
  // Her yığının kendi malzemesi, ki sadece diriltilen parlasın
  materials: THREE.MeshStandardMaterial[];
}

// Yüklenip hazırlanmış model. Her yığın bunun kopyası.
let template: THREE.Object3D | null = null;

/** flesh.glb'yi yükle ve hazırla */
export async function loadFleshModel() {
  const gltf = await new GLTFLoader().loadAsync(FLESH_URL);
  const model = gltf.scene;

  // Zemindeki en uzun kenarı FLESH_SIZE'a ölçekle, ortasını merkeze, tabanını zemine koy
  const box = new THREE.Box3().setFromObject(model);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  const scale = FLESH_SIZE / Math.max(size.x, size.z);
  model.scale.setScalar(scale);
  model.position.set(-center.x * scale, -box.min.y * scale, -center.z * scale);

  model.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    child.castShadow = true;
    child.receiveShadow = true;
    const material = child.material as THREE.MeshStandardMaterial;
    // Model "metal" işaretli; yansıtacak ortam olmadığı için simsiyah görünürdü. Et metal değil.
    material.metalness = 0;
    material.emissive.set(GLOW_COLOR);
    material.emissiveIntensity = 0;
  });

  template = model;
}

/** Yeni bir et yığını. Model henüz yüklenmediyse (ya da hiç yoksa) null. */
export function createFlesh(): Flesh | null {
  if (!template) return null;
  // clone() şekli paylaşır (bellekte tek kopya); malzemeyi ayrıca kopyalıyoruz ki parlama yığına özel olsun
  const model = template.clone();
  const materials: THREE.MeshStandardMaterial[] = [];
  model.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    const material = (child.material as THREE.MeshStandardMaterial).clone();
    child.material = material;
    materials.push(material);
  });
  const root = new THREE.Group();
  root.add(model);
  return { root, materials };
}
