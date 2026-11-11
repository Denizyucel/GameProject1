// Silah ve kalkanı Mixamo modelinin eline takma, kılıç vuruşunun darbe anını ölçme.
// Karakter de iskeletler de aynı kemik adlarını kullandığı için ikisi de bunları kullanır.

import * as THREE from 'three';

/**
 * Pivotu modelin eline tak. Pivotun eksenleri: x = yan (elin sırtına ya da avucuna dik),
 * y = sap (yumruğun içinden öne), z = bıçak. Kılıç, tırpan ya da kalkan bu eksenlere göre
 * yerleştirilip pivotun içine konur. Modelde gerekli kemikler yoksa false döner.
 */
export function attachToHand(pivot: THREE.Object3D, model: THREE.Object3D, hand: 'Right' | 'Left'): boolean {
  const bone = model.getObjectByName(`mixamorig${hand}Hand`);
  const index = model.getObjectByName(`mixamorig${hand}HandIndex1`); // işaret parmağı dibi
  const pinky = model.getObjectByName(`mixamorig${hand}HandPinky1`); // serçe parmak dibi
  if (!bone || !index || !pinky) return false;

  // Yumruğun içinden geçen sap, serçe parmak dibinden işaret parmağı dibine doğru uzanır:
  // kılıç tutar gibi, uç öne bakar. Parmak kemikleri elin "çocuğu" olduğu için konumları
  // zaten elin kendi ekseninde.
  const shaftDirection = new THREE.Vector3().subVectors(index.position, pinky.position).normalize();
  // Bıçak sapa dik, elin sırtı yönünde (parmakların tersi, elin -y ekseni)
  const bladeDirection = new THREE.Vector3(0, -1, 0)
    .addScaledVector(shaftDirection, shaftDirection.y) // sapa dik olsun diye sap yönünü çıkar
    .normalize();
  const side = new THREE.Vector3().crossVectors(shaftDirection, bladeDirection);

  pivot.quaternion.setFromRotationMatrix(new THREE.Matrix4().makeBasis(side, shaftDirection, bladeDirection));
  // Tutulan yer: iki parmak dibinin ortası
  pivot.position.addVectors(index.position, pinky.position).multiplyScalar(0.5);
  // Kemik santimetre ölçeğinde; silah metre ile çizildi, ölçeği geri al
  model.updateMatrixWorld(true);
  pivot.scale.setScalar(1 / bone.getWorldScale(new THREE.Vector3()).x);

  bone.add(pivot);
  return true;
}

/**
 * Kılıç modelini pivota uygun hale getir: kabzası pivotun orijininde, bıçağı pivotun y ekseni
 * boyunca, keskin kenarı z yönünde. Meshy kılıçlarında bıçak -y'de, kabza +y'de, geniş taraf x'te.
 * length: uçtan kabzaya boy (metre); grip: elin tuttuğu yer, bıçak ucundan ölçülen boy oranı.
 */
export function prepareSword(model: THREE.Object3D, length: number, grip: number): THREE.Group {
  const box = new THREE.Box3().setFromObject(model);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());

  // İç grup: modeli, tutulan nokta (kabzanın ortası) tam orijine gelecek şekilde kaydır
  const inner = new THREE.Group();
  model.position.set(-center.x, -(box.min.y + size.y * grip), -center.z);
  inner.add(model);

  // Dış grup: döndür ve ölçekle. Model x → pivot z, model -y → pivot y, model z → pivot x.
  const sword = new THREE.Group();
  sword.quaternion.setFromRotationMatrix(
    new THREE.Matrix4().makeBasis(new THREE.Vector3(0, 0, 1), new THREE.Vector3(0, -1, 0), new THREE.Vector3(1, 0, 0)),
  );
  sword.scale.setScalar(length / size.y);
  sword.add(inner);
  return sword;
}

/**
 * Kalkan modelini sol el pivotuna uygun hale getir: ön kola kayışla bağlı gibi. Boyu ön kol
 * boyunca (pivot z: bilekten dirseğe), yüzü elin sırtına dik (pivot x) dışarı bakar.
 * Meshy kalkanında yüz +z'de, üstü +y'de.
 * height: kalkanın boyu (metre); facing: yüzün pivot x'in hangi yönüne baktığı (1 ya da -1);
 * towardElbow: kalkanın ortasının elden dirseğe doğru ne kadar kaydığı (metre).
 */
export function prepareShield(model: THREE.Object3D, height: number, facing: 1 | -1, towardElbow: number): THREE.Group {
  const box = new THREE.Box3().setFromObject(model);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());

  // İç grup: kalkanın ortası orijinde, arka yüzü ele değecek şekilde biraz dışarı itilmiş
  const inner = new THREE.Group();
  model.position.set(-center.x, -center.y, -center.z + size.z / 2);
  inner.add(model);

  // Dış grup: model y → pivot z (üstü dirseğe), model z → pivot x * facing (yüzü dışarı),
  // model x → pivot y * facing (dönüş olsun, ayna görüntüsü olmasın diye işareti facing'e bağlı)
  const shield = new THREE.Group();
  shield.quaternion.setFromRotationMatrix(
    new THREE.Matrix4().makeBasis(
      new THREE.Vector3(0, facing, 0),
      new THREE.Vector3(0, 0, 1),
      new THREE.Vector3(facing, 0, 0),
    ),
  );
  shield.scale.setScalar(height / size.y);
  shield.position.z = towardElbow;
  shield.add(inner);
  return shield;
}

/**
 * Bir vuruşun darbe anı (0..1): animasyonu ayrı bir mixer'la kare kare oynatıp sağ elin dünyadaki
 * konumunu ölçer, elin en hızlı hareket ettiği anı döndürür (kılıç en hızlı o an iner).
 * Ölçüm yüklenirken bir kez yapılır; model sonraki karede asıl mixer'ın pozuna döner.
 */
export function fastestHandMoment(model: THREE.Object3D, clip: THREE.AnimationClip, fallback: number): number {
  const hand = model.getObjectByName('mixamorigRightHand');
  if (!hand) return fallback;
  const mixer = new THREE.AnimationMixer(model);
  const action = mixer.clipAction(clip);
  // Son karede başa sarmasın: yoksa el bir anda başlangıç pozuna "ışınlanır", en hızlı an o sanılır
  action.setLoop(THREE.LoopOnce, 1);
  action.clampWhenFinished = true;
  action.play();
  const steps = 60;
  const previous = new THREE.Vector3();
  const current = new THREE.Vector3();
  let bestSpeed = -1;
  let bestStep = 0;
  for (let step = 0; step <= steps; step++) {
    mixer.setTime((step / steps) * clip.duration);
    model.updateMatrixWorld(true);
    hand.getWorldPosition(current);
    if (step > 0) {
      const speed = current.distanceTo(previous);
      if (speed > bestSpeed) {
        bestSpeed = speed;
        bestStep = step;
      }
    }
    previous.copy(current);
  }
  mixer.stopAllAction();
  mixer.uncacheRoot(model);
  return bestStep / steps;
}

// Kılıç vuruşları (Mixamo "Lite Sword and Shield Pack"). Karakter ve iskeletler her vuruşta
// bunlardan rastgele birini oynar.
export const SWORD_ATTACK_NAMES = [
  'sword and shield attack',
  'sword and shield attack (2)',
  'sword and shield attack (3)',
  'sword and shield attack (4)',
];
// Dosya adlarında boşluk var; encodeURI onları adrese uygun hale getirir (boşluk → %20)
export const SWORD_ATTACK_URLS = SWORD_ATTACK_NAMES.map((name) =>
  encodeURI(`/models/Lite Sword and Shield Pack/${name}.fbx`),
);
