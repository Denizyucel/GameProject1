// Görüş penceresi, düz renkli/dokulu basit malzemeler için (gotik binanın malzemeleri: renk dokusu x renk,
// pürüz, metal, ışıma). koy.gdshader'daki pencerenin aynısı: karakterle kamera arasında kalan kısım, karakterin
// çevresinde ekranda yuvarlak bir alanda noktalı (dither) silinir. Değerleri levels/building_window.gd her kare verir.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0); // ışıyan malzemelerde (pencere ışığı, köz)
uniform float emission_energy = 0.0;

uniform vec3 hole_center = vec3(0.0, -1000.0, 0.0); // karakterin göğsü (dünyada)
uniform float hole_floor = 0.0; // karakterin bastığı zeminin yüksekliği
uniform float hole_strength = 0.0; // 0 = pencere kapalı, 1 = açık
uniform float hole_radius = 3.2; // pencerenin ekrandaki yarıçapı (metre)
uniform float hole_faded = 0.8; // pencerenin ortasında silinen piksel oranı
uniform vec3 camera_forward = vec3(0.577, 0.577, 0.577); // kameraya doğru yön

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float bayer4(vec2 pixel) {
	ivec2 p = ivec2(mod(pixel, 4.0));
	int index = p.x + p.y * 4;
	const float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[index] + 0.5) / 16.0;
}

void fragment() {
	bool from_camera = dot(INV_VIEW_MATRIX[2].xyz, camera_forward) > 0.99;
	if (from_camera && hole_strength > 0.0 && world_pos.y > hole_floor + 0.4) {
		vec3 center_view = (VIEW_MATRIX * vec4(hole_center, 1.0)).xyz;
		float reach = length(VERTEX.xy - center_view.xy) / hole_radius;
		if (reach < 1.0 && VERTEX.z > center_view.z + 0.3) {
			float hidden = hole_strength * hole_faded * (1.0 - smoothstep(0.6, 1.0, reach));
			if (hidden > bayer4(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
	ALBEDO = texture(texture_albedo, UV).rgb * albedo_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.5;
	EMISSION = emission.rgb * emission_energy;
}
