# Golem yuvası (HUD, mana küresinin solunda): kemik golemini çağırma hakkı kazanılınca görünür.
# Daire içinde golemin yüzü (assets/hud/golem-icon.png; tools/make_golem_icon.gd üretir), sağ altında tuşu ("2").
#   - Golem ayakta: çevresinde mavi halka canını gösterir (tepeden saat yönünde azalır).
#   - Golem öldü: yüz kararır, ortada geri sayım (saniye), koyu örtü saat yönünde açılır (bekleme süresi).
#   - Çağrılmaya hazır: yüz parlak, halka boş; bekleme bittiği an kısa bir mavi parlama.
# Durumu main.gd'den okur (has_golem, golem, golem_cooldown); fare olaylarını yutmaz.

extends Control

const ICON_FILE := "res://assets/hud/golem-icon.png"
const NUMBER_FONT := preload("res://fonts/AguafinaScript-Regular.ttf") # rozetle aynı yazı tipi
const SEGMENTS := 48
const BACKGROUND := Color(0.04, 0.03, 0.05, 0.85)
const BORDER := Color(0.42, 0.33, 0.2, 1) # can barı ve küçük haritayla aynı bronz
const SOUL := Color(0.49, 0.77, 1.0) # özgür ruhun mavisi: golemin canı
const HURT := Color(1.0, 0.35, 0.25) # canı azken halka kızarır
const SHADE := Color(0.02, 0.02, 0.04, 0.72) # beklerken yüzün üstündeki koyu örtü
const BONE := Color(0.93, 0.9, 0.82)
const RING_WIDTH := 4.0
const FLASH_TIME := 0.6
const KEY_LABEL := "2"

var icon: Texture2D
var earned := false
var alive := false
var health := 1.0 # 0..1
var cooldown := 0.0 # kalan saniye
var cooldown_total := 1.0
var flash := 0.0 # bekleme bitince parlama (1 → 0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if ResourceLoader.exists(ICON_FILE):
		icon = load(ICON_FILE)


func _process(delta: float) -> void:
	var main := get_tree().current_scene
	if main == null or not "has_golem" in main:
		return
	earned = main.has_golem
	visible = earned
	if not earned:
		return
	var golem: Variant = main.golem
	alive = is_instance_valid(golem)
	if alive:
		health = clampf(golem.health / golem.max_health, 0.0, 1.0)
	var was_waiting := cooldown > 0
	cooldown = main.golem_cooldown
	cooldown_total = main.GOLEM_COOLDOWN
	if was_waiting and cooldown <= 0:
		flash = 1.0
	flash = maxf(0.0, flash - delta / FLASH_TIME)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	var waiting := cooldown > 0 and not alive
	draw_circle(center, radius, BACKGROUND)

	# Golemin yüzü, daireye kırpılmış (çember çokgeninin köşelerine resmin karşılık gelen noktası verilir)
	var inner := radius - RING_WIDTH - 1.0
	if icon:
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in SEGMENTS:
			var direction := Vector2(cos(TAU * i / SEGMENTS), sin(TAU * i / SEGMENTS))
			points.append(center + direction * inner)
			uvs.append(Vector2(0.5, 0.5) + direction * 0.5)
		var tint := Color(0.4, 0.4, 0.45) if waiting else Color.WHITE
		draw_colored_polygon(points, tint, uvs, icon)

	# Bekleme: kalan süre kadar koyu dilim (tepeden saat yönünde açılır) ve ortada saniye
	if waiting:
		var left := clampf(cooldown / cooldown_total, 0.0, 1.0)
		var slice := PackedVector2Array([center])
		var steps := maxi(2, int(SEGMENTS * left))
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * (1.0 - left) + TAU * left * i / steps
			slice.append(center + Vector2(cos(angle), sin(angle)) * inner)
		draw_colored_polygon(slice, SHADE)
		var text := str(ceili(cooldown))
		var font_size := int(radius * 0.95)
		var text_size := NUMBER_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(NUMBER_FONT, center + Vector2(-text_size.x * 0.5, text_size.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, BONE)

	# Can halkası: golem ayaktayken, tepeden saat yönünde
	draw_arc(center, radius - RING_WIDTH * 0.5 - 1.0, 0, TAU, SEGMENTS, Color(0, 0, 0, 0.55), RING_WIDTH, true)
	if alive and health > 0:
		var color := SOUL.lerp(HURT, clampf((0.35 - health) / 0.35, 0.0, 1.0)) # canın son üçte birinde kızarır
		draw_arc(center, radius - RING_WIDTH * 0.5 - 1.0, -PI * 0.5, -PI * 0.5 + TAU * health, SEGMENTS, color, RING_WIDTH, true)
	if flash > 0:
		draw_arc(center, radius - RING_WIDTH * 0.5 - 1.0, 0, TAU, SEGMENTS, Color(SOUL, flash), RING_WIDTH + 2.0, true)
	draw_arc(center, radius - 0.5, 0, TAU, SEGMENTS, BORDER, 1.5, true)

	# Tuş: sağ altta küçük rozet
	var badge := center + Vector2(radius, radius) * 0.68
	var badge_radius := radius * 0.34
	draw_circle(badge, badge_radius, Color(0.06, 0.05, 0.08, 0.95))
	draw_arc(badge, badge_radius, 0, TAU, 24, BORDER, 1.2, true)
	var key_size := int(badge_radius * 1.7)
	var key_text_size := NUMBER_FONT.get_string_size(KEY_LABEL, HORIZONTAL_ALIGNMENT_CENTER, -1, key_size)
	draw_string(NUMBER_FONT, badge + Vector2(-key_text_size.x * 0.5, key_text_size.y * 0.28), KEY_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, key_size, BONE)
