// Harabe Köy modelinin malzemesi (koy.glb'nin kendi StandardMaterial3D'sinin aynısı: renk, metal/pürüz, normal
// dokuları) + "pencere": karakterle kamera arasında kalan kısım, karakterin çevresinde ekranda yuvarlak bir alanda
// noktalı (dither) olarak silinir. Köy tek mesh olduğu için evleri tek tek saydamlaştıramıyoruz; bu yüzden
// parçaya değil piksele bakılır. Dither: her pikseli ya tam çizer ya hiç çizmez; kısmen silinmiş noktalar uzaktan
// yarı saydam görünür (gerçek saydamlıktaki sıralama sorunları olmadan). Değerleri levels/village.gd her kare verir.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_orm : filter_linear_mipmap, repeat_enable; // g = pürüz, b = metal (glTF düzeni)
uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;

uniform vec3 hole_center = vec3(0.0, -1000.0, 0.0); // karakterin göğsü (dünyada)
uniform float hole_floor = 0.0; // karakterin bastığı zeminin yüksekliği
uniform float hole_strength = 0.0; // 0 = pencere kapalı, 1 = açık
uniform float hole_radius = 3.2; // pencerenin ekrandaki yarıçapı (metre)
uniform float hole_faded = 0.8; // pencerenin ortasında silinen piksel oranı
uniform vec3 camera_forward = vec3(0.577, 0.577, 0.577); // kameranın baktığı yönün tersi (kameraya doğru)

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 4x4 Bayer matrisi: dither için piksel başına 0..1 eşik
float bayer4(vec2 pixel) {
	ivec2 p = ivec2(mod(pixel, 4.0));
	int index = p.x + p.y * 4;
	const float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[index] + 0.5) / 16.0;
}

void fragment() {
	// Gölge çiziminde (ışığın gözünden) pencere açılmaz: gölgeler delinmesin. Kameranın yönüne bakarak anlarız.
	bool from_camera = dot(INV_VIEW_MATRIX[2].xyz, camera_forward) > 0.99;
	if (from_camera && hole_strength > 0.0 && world_pos.y > hole_floor + 0.4) {
		vec3 center_view = (VIEW_MATRIX * vec4(hole_center, 1.0)).xyz;
		// Ortografik kamerada görüş uzayının x, y'si ekrandaki konum (metre), z'si derinlik (büyük = kameraya yakın)
		float reach = length(VERTEX.xy - center_view.xy) / hole_radius;
		if (reach < 1.0 && VERTEX.z > center_view.z + 0.3) {
			float hidden = hole_strength * hole_faded * (1.0 - smoothstep(0.6, 1.0, reach));
			if (hidden > bayer4(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
	ALBEDO = texture(texture_albedo, UV).rgb;
	vec4 orm = texture(texture_orm, UV);
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	SPECULAR = 0.5;
	NORMAL_MAP = texture(texture_normal, UV).rgb;
}
