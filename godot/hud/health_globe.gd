# Diablo tarzı can küresi. Katmanlar (alttan üste): boş küre, kayıp can, sıvı, çerçeve ve kafatası.
# Sıvı globe_fill.gdshader ile üstten kesilerek boşalır. Görseller: assets/hud (asılları
# public/models/hud/health-globe). Hızlar aşağıda; boyut ve yer hud.tscn'de editörden.

extends Control

const DRAIN_TIME := 0.3 # sıvının yeni seviyeye inme süresi (saniye)
const LOST_DELAY := 0.4 # kayıp can katmanının açık renkte bekleme süresi
const LOST_TIME := 0.6 # kayıp can katmanının inme süresi
const FLASH_TIME := 0.35 # hasar parlamasının sönme süresi

@onready var liquid: TextureRect = $Sivi
@onready var lost: TextureRect = $KayipCan
@onready var number: Label = $Sayi

var shown_fill := 1.0
var tweens: Array[Tween] = []


func _ready() -> void:
	number.visible = false
	mouse_entered.connect(func(): number.visible = true)
	mouse_exited.connect(func(): number.visible = false)


## Canı göster. animate false ise beklemeden (oyun başında) ayarlar.
func set_health(health: float, max_health: float, animate := true) -> void:
	var fill := clampf(health / max_health, 0.0, 1.0)
	number.text = "%d / %d" % [roundi(health), roundi(max_health)]
	for tween in tweens:
		tween.kill()
	tweens.clear()
	if not animate:
		set_fill(liquid, fill)
		set_fill(lost, fill)
	else:
		# Tween: bir değeri zamanla yumuşakça değiştiren Godot aracı (CSS transition gibi)
		var drain := create_tween()
		drain.tween_property(liquid.material, "shader_parameter/fill", fill, DRAIN_TIME).set_ease(Tween.EASE_OUT)
		tweens.append(drain)
		var behind := create_tween()
		if fill < shown_fill:
			# Hasar: kayıp kısım bir an açık renkte kalır, sonra iner; küre bir an kırmızı parlar
			behind.tween_interval(LOST_DELAY)
			var flash := create_tween()
			liquid.material.set_shader_parameter("flash", 1.0)
			flash.tween_property(liquid.material, "shader_parameter/flash", 0.0, FLASH_TIME)
			tweens.append(flash)
		behind.tween_property(lost.material, "shader_parameter/fill", fill, LOST_TIME).set_ease(Tween.EASE_IN)
		tweens.append(behind)
	shown_fill = fill


func set_fill(layer: TextureRect, fill: float) -> void:
	layer.material.set_shader_parameter("fill", fill)
