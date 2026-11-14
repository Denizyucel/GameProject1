// Dış zemin: her yer çimen (Grass001), üstünde toprak (Ground110) bir yol.
// Yol road_points'teki noktaları sırayla birleştiren bir çizgi (dünya x, z; metre); genişliği road_width.
// Kenarlar road_softness kadar yumuşak, ve gürültüyle (edge_noise) düzensiz: düz bir şerit değil, çiğnenmiş
// bir patika gibi. Dokular dünya konumuna göre döşendiği için yan yana duran zeminler dikişsiz birleşir.
shader_type spatial;

const int MAX_POINTS = 16;

uniform sampler2D ground_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_roughness : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_ao : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 ground_tint : source_color = vec3(0.553, 0.533, 0.518);
uniform float ground_tile = 3.0; // bir toprak doku karesinin dünyada kapladığı alan (metre)

uniform sampler2D grass_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_roughness : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_ao : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 grass_tint : source_color = vec3(0.45, 0.5, 0.4);
uniform float grass_tile = 2.5;

uniform vec2 road_points[MAX_POINTS]; // yolun noktaları, sırayla (kullanılmayanlar sonda)
uniform int road_count = 0; // kaç nokta kullanılıyor
uniform float road_width = 3.6; // metre
uniform float road_softness = 0.6; // kenar geçişinin genişliği (metre)
uniform sampler2D edge_noise : repeat_enable; // kenar düzensizliği için gürültü (0..1, dikişsiz)
uniform float edge_wobble = 1.2; // kenarın içe/dışa en fazla ne kadar oynadığı (metre)

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

// p noktasının a-b doğru parçasına uzaklığı
float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	return length(p - (a + ab * t));
}

void fragment() {
	float distance_to_road = 1e6;
	for (int i = 0; i < MAX_POINTS - 1; i++) {
		if (i + 1 >= road_count) {
			break;
		}
		distance_to_road = min(distance_to_road, segment_distance(world_xz, road_points[i], road_points[i + 1]));
	}
	float wobble = (texture(edge_noise, world_xz / 9.0).r - 0.5) * 2.0 * edge_wobble;
	float edge = road_width * 0.5 + wobble;
	float road = 1.0 - smoothstep(edge - road_softness, edge + road_softness, distance_to_road);

	vec2 g_uv = world_xz / ground_tile;
	vec2 c_uv = world_xz / grass_tile;
	ALBEDO = mix(texture(grass_color, c_uv).rgb * grass_tint, texture(ground_color, g_uv).rgb * ground_tint, road);
	NORMAL_MAP = mix(texture(grass_normal, c_uv).rgb, texture(ground_normal, g_uv).rgb, road);
	ROUGHNESS = mix(texture(grass_roughness, c_uv).g, texture(ground_roughness, g_uv).g, road);
	AO = mix(texture(grass_ao, c_uv).r, texture(ground_ao, g_uv).r, road);
	METALLIC = 0.0;
}
