# Beceri yuvası: HUD'da alt ortadaki beceri çubuğunun (hud/skill_bar.gd) bir simgesi. Görseli kullanıcı çizdi
# (assets/hud/skills; asılları public/models/hud/Skills: 300 x 300, gotik çerçeve, altında tuşun yazdığı kutu).
# Simgenin üstüne duruma göre şunları çizer:
#   - Kullanılamıyor (mana yetmiyor, yakında ceset yok): görsel solar.
#   - Bekleme süresi: görsel solar, iç resmin üstünde koyu örtü saat yönünde açılır, ortada kalan saniye;
#     süre bittiği an kısa bir mavi parlama.
#   - Çubuk (bar 0..1; golemin canı): çerçevenin hemen üstünde ince bir bar, azaldıkça kızarır.
# Durumu skill_bar.gd yazar; fare olaylarını yutmaz.

extends Control

const NUMBER_FONT := preload("res://fonts/AguafinaScript-Regular.ttf") # rozetle aynı yazı tipi
const DIM := Color(0.42, 0.42, 0.46) # kullanılamazken görselin rengi
const SHADE := Color(0.02, 0.02, 0.04, 0.72) # beklerken iç resmin üstündeki koyu örtü
const BONE := Color(0.93, 0.9, 0.82)
const SOUL := Color(0.49, 0.77, 1.0) # özgür ruhun mavisi
const HURT := Color(1.0, 0.35, 0.25)
const BORDER := Color(0.42, 0.33, 0.2, 1) # can barı ve küçük haritayla aynı bronz
const FLASH_TIME := 0.6
const WIPE_STEPS := 96
const BAR_HEIGHT := 5.0
const BAR_GAP := 4.0 # barın çerçevenin üstünden uzaklığı

@export var icon: Texture2D
## İç resmin (çerçevenin içindeki kare) görseldeki yeri, görselin boyutuna oranla
@export var art := Rect2(0.3, 0.273, 0.4, 0.413)
## Çerçevenin üst kenarı (oran): can barı bunun üstüne çizilir
@export var frame_top := 0.18

var usable := true
var cooldown := 0.0 # kalan saniye
var cooldown_total := 1.0
var bar := -1.0 # 0..1; -1 ise bar yok
var flash := 0.0 # bekleme bitince parlama (1 → 0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Kalan bekleme süresini yaz; süre bittiği an simge parlar
func set_cooldown(left: float, total: float) -> void:
	if cooldown > 0 and left <= 0:
		flash = 1.0
	cooldown = left
	cooldown_total = maxf(total, 0.01)


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta / FLASH_TIME)
	queue_redraw()


func _draw() -> void:
	if icon == null:
		return
	var waiting := cooldown > 0
	draw_texture_rect(icon, Rect2(Vector2.ZERO, size), false, DIM if waiting or not usable else Color.WHITE)
	var inner := Rect2(art.position * size, art.size * size)
	var center := inner.get_center()

	if waiting:
		# Kalan süre kadar koyu dilim: tepeden saat yönünde açılır, iç resmin karesine kırpılır
		var left := clampf(cooldown / cooldown_total, 0.0, 1.0)
		if left > 0.995:
			draw_rect(inner, SHADE)
		else:
			var slice := PackedVector2Array([center])
			var steps := maxi(3, int(WIPE_STEPS * left))
			for i in steps + 1:
				var angle := -PI * 0.5 + TAU * (1.0 - left) + TAU * left * i / steps
				slice.append(center + to_edge(Vector2(cos(angle), sin(angle)), inner.size * 0.5))
			draw_colored_polygon(slice, SHADE)
		var text := str(ceili(cooldown))
		var font_size := int(inner.size.y * 0.62)
		var text_size := NUMBER_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(NUMBER_FONT, center + Vector2(-text_size.x * 0.5, text_size.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, BONE)

	if flash > 0:
		draw_rect(inner, Color(SOUL, flash * 0.55))

	if bar >= 0:
		var track := Rect2(inner.position.x, frame_top * size.y - BAR_GAP - BAR_HEIGHT, inner.size.x, BAR_HEIGHT)
		draw_rect(track.grow(1.0), BORDER)
		draw_rect(track, Color(0.03, 0.03, 0.05))
		var color := SOUL.lerp(HURT, clampf((0.35 - bar) / 0.35, 0.0, 1.0)) # son üçte birde kızarır
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(bar, 0.0, 1.0), track.size.y)), color)


## Merkezden direction yönünde giden ışının, yarı boyutu half olan karenin kenarına vardığı nokta
func to_edge(direction: Vector2, half: Vector2) -> Vector2:
	var reach := INF
	if absf(direction.x) > 0.0001:
		reach = minf(reach, half.x / absf(direction.x))
	if absf(direction.y) > 0.0001:
		reach = minf(reach, half.y / absf(direction.y))
	return direction * reach
