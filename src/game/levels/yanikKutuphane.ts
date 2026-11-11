// Act I, 1. bölge: Yanık Kütüphane. Yerleşim planlar/yanik-kutuphane-ornek.svg ile aynı.
// Sayılar plandaki piksellerdir (800 x 800 px, 20 px = 1 m, üst = kuzey), ki plandaki bir şekli
// kaydırınca buradaki sayıyı bulup değiştirmek kolay olsun. Metreye KitLevel çevirir.

/** Bir parça: [dosya adı, plandaki merkez x, merkez y, saat yönünde dönüş (derece)] */
export type Piece = [part: string, x: number, y: number, rotation?: number];

export interface LevelPlan {
  /** Planın kenarı (piksel) ve 1 metrenin kaç piksel olduğu */
  size: number;
  pixelsPerMeter: number;
  /** Karakterin doğduğu ve bölgeden çıktığı yer (plan pikseli) */
  spawn: [number, number];
  exit: [number, number];
  /** Salonun iç zemini: [sol, üst, sağ, alt] (plan pikseli). İçi taş döşeme, dışı toprak. */
  hall: [number, number, number, number];
  pieces: Piece[];
}

/** Plan pikselini dünya koordinatına çevir: planın ortası (0, 0), aşağısı +z */
export function planToWorld(plan: LevelPlan, x: number, y: number): { x: number; z: number } {
  return { x: (x - plan.size / 2) / plan.pixelsPerMeter, z: (y - plan.size / 2) / plan.pixelsPerMeter };
}

export const YANIK_KUTUPHANE: LevelPlan = {
  size: 800,
  pixelsPerMeter: 20,
  spawn: [400, 215],
  exit: [400, 772],
  hall: [206, 126, 594, 538], // duvarların ortasından ortasına
  pieces: [
    // Kuzey duvarı. Kuzey ve batı kameradan uzak taraf: yüksek duvarlar burada, ki salonu
    // kapatmadan arkasında dursunlar. Güney ve doğu kameraya yakın: alçak kalır.
    ['yuksek-duvar', 240, 126], ['yuksek-duvar', 320, 126], ['yuksek-duvar', 400, 126],
    ['yuksek-duvar', 480, 126], ['yuksek-duvar', 560, 126],
    // Batı duvarı (ortasındaki boşlukta kemer var)
    ['yuksek-duvar', 206, 172, 90], ['yuksek-duvar', 206, 252, 90],
    ['yuksek-duvar', 206, 412, 90], ['yuksek-duvar', 206, 492, 90],
    // Duvar dibindeki yüksek kitaplıklar: kuzey duvarı boyunca (güneye bakar) ve batı duvarı boyunca (doğuya bakar)
    ['duvar-rafi', 240, 142], ['duvar-rafi', 320, 142], ['duvar-rafi', 480, 142], ['duvar-rafi', 560, 142],
    ['duvar-rafi', 222, 172, -90], ['duvar-rafi', 222, 252, -90], ['duvar-rafi', 222, 412, -90], ['duvar-rafi', 222, 492, -90],
    // Batı duvarındaki gediği dolduran kemer (yan kapı). Altından yürünür.
    ['cati-kemeri', 206, 332, 90],
    // Doğu duvarı
    ['yikik-duvar', 594, 172, 90], ['yikik-duvar', 594, 252, 90], ['yikik-duvar', 594, 332, 90],
    ['yikik-duvar', 594, 412, 90], ['yikik-duvar', 594, 492, 90],
    // Güney duvarı ve kemerli kapı
    ['yikik-duvar', 240, 538], ['yikik-duvar', 320, 538], ['kemer-kapi', 400, 538],
    ['yikik-duvar', 480, 538], ['yikik-duvar', 560, 538],
    // İki sıra sütun
    ['sutun', 300, 210], ['sutun', 300, 300], ['kirik-sutun', 300, 390], ['sutun', 300, 470],
    ['kirik-sutun', 500, 210], ['sutun', 500, 300], ['sutun', 500, 390], ['sutun', 500, 470],
    // Raflar
    ['yanmis-raf', 250, 230], ['yanmis-raf', 250, 280], ['yanmis-raf', 250, 360], ['yanmis-raf', 250, 440],
    ['yanmis-raf', 550, 250], ['yanmis-raf', 550, 310], ['yanmis-raf', 550, 420], ['yanmis-raf', 550, 470],
    // Mühürlerin durduğu boş kaide
    ['muhur-kaidesi', 400, 165],
    // Yanık kitap yığınları
    ['kitap-yigini', 345, 180], ['kitap-yigini', 455, 185], ['kitap-yigini', 440, 330],
    ['kitap-yigini', 330, 470], ['kitap-yigini', 535, 365],
    // Moloz
    ['moloz', 172, 392], ['moloz', 555, 160], ['moloz', 450, 500], ['moloz', 640, 600],
    // Dışarıdaki yanmış ağaçlar
    ['kuru-agac', 90, 110], ['kuru-agac', 700, 90], ['kuru-agac', 120, 420], ['kuru-agac', 690, 380],
    ['kuru-agac', 150, 660], ['kuru-agac', 610, 720], ['kuru-agac', 280, 640],
  ],
};
