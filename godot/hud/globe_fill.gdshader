// Can küresinin sıvısı: görselin, doluluk çizgisinin üstünde kalan kısmı saydam olur.
// Tarayıcı sürümündeki CSS clip-path'in karşılığı. fill: 0 = boş, 1 = dolu.
shader_type canvas_item;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
// Kürenin görsel içindeki yeri (320 px'lik görselde ölçüldü): üst kenarı 81 px, çapı 157 px
uniform float globe_top = 0.2531;
uniform float globe_height = 0.4906;
// Renk ayarları: brightness ile açılır (kayıp can katmanı), flash ile bir an kırmızı parlar (hasar)
uniform float brightness = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float cut = globe_top + globe_height * (1.0 - fill);
	if (UV.y < cut) {
		color.a = 0.0;
	}
	color.rgb *= brightness;
	color.rgb = mix(color.rgb, vec3(1.0, 0.4, 0.3), flash * 0.6);
	COLOR = color * COLOR;
}
