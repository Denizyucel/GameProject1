# Mana küresinin çerçevesini oyuna hazırlar: kafatasının üstündeki rozetteki örnek rakamı ("1") silip
# rozeti düz rengiyle doldurur; rakamı oyun kendisi yazar (HUD: iskelet sayısı, hud.tscn ManaKuresi/Rozet).
# Kaynak: public/models/hud/mana-globe/mana-frame.png  →  Çıktı: assets/hud/mana-frame.png
# Görseli güncelleyince yeniden çalıştır:
#   godot --headless --path godot -s tools/prepare_mana_frame.gd
#   godot --headless --path godot --import

extends SceneTree

const SOURCE := "../public/models/hud/mana-globe/mana-frame.png" # godot/ klasörüne göre
const OUTPUT := "res://assets/hud/mana-frame.png"
# Rozet (320 px'lik görselde ölçüldü): merkezi ve yarıçapı; rakam bu dairenin içinde
const BADGE_CENTER := Vector2(275.5, 190.5)
const BADGE_RADIUS := 23.0
const CLEAR_RADIUS := 19.0 # bunun içindeki, rozet renginden farklı pikseller rakam sayılır (kenar halkası korunur)


func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://").path_join(SOURCE))
	if image == null:
		push_error("Bulunamadı: " + SOURCE)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	# Rozetin rengi: merkezin solunda rakama değmeyen bir nokta
	var badge := image.get_pixelv(Vector2i(BADGE_CENTER + Vector2(-13, 0)))
	var cleared := 0
	for y in range(int(BADGE_CENTER.y - CLEAR_RADIUS), int(BADGE_CENTER.y + CLEAR_RADIUS) + 1):
		for x in range(int(BADGE_CENTER.x - CLEAR_RADIUS), int(BADGE_CENTER.x + CLEAR_RADIUS) + 1):
			if Vector2(x, y).distance_to(BADGE_CENTER) > CLEAR_RADIUS:
				continue
			var color := image.get_pixel(x, y)
			var difference := absf(color.r - badge.r) + absf(color.g - badge.g) + absf(color.b - badge.b)
			if difference > 0.03:
				image.set_pixel(x, y, badge)
				cleared += 1
	image.save_png(OUTPUT)
	print("Rozet rengi %s, silinen piksel %d → %s" % [badge * 255, cleared, OUTPUT])
	quit()
