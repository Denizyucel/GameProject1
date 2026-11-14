# Diablo tarzı küre (can ve mana için aynı betik). Katmanlar (alttan üste): boş küre, kayıp kısım, sıvı,
# çerçeve ve kafatası. Sıvı globe_fill.gdshader ile üstten kesilerek boşalır. Görseller: assets/hud (asılları
# public/models/hud/health-globe). Mana küresi aynı görselleri kullanır; shader sıvıyı maviye çevirir.
# Boyut ve yer hud.tscn'de editörden.
#
# Sıvı her karede hedef seviyeye doğru kendisi akar (Tween yerine): böylece yenilenme her kare küçük bir
# artış gönderse de süren bir boşalma animasyonu kesilmez.

extends Control

const DRAIN_TIME := 0.12 # sıvının yeni seviyeye yetişme hızı (küçüldükçe hızlı; saniye)
const LOST_DELAY := 0.4 # kayıp kısmın açık renkte bekleme süresi
const LOST_SPEED := 1.2 # kayıp kısmın inme hızı (küre / saniye)
const FLASH_TIME := 0.35 # parlamanın sönme süresi

@onready var liquid: TextureRect = $Sivi
@onready var lost: TextureRect = $KayipCan
@onready var number: Label = $Sayi

var target := 1.0 # gösterilmesi gereken doluluk (0..1)
var liquid_fill := 1.0
var lost_fill := 1.0
var lost_wait := 0.0
var flash := 0.0


func _ready() -> void:
	number.visible = false
	mouse_entered.connect(func(): number.visible = true)
	mouse_exited.connect(func(): number.visible = false)


## Değeri göster. animate false ise beklemeden (oyun başında) ayarlar. Azalınca küre bir an parlar.
func set_health(value: float, max_value: float, animate := true) -> void:
	var fill := clampf(value / max_value, 0.0, 1.0)
	number.text = "%d / %d" % [roundi(value), roundi(max_value)]
	if not animate:
		liquid_fill = fill
		lost_fill = fill
	elif fill < target - 0.001:
		# Kayıp: kayıp kısım bir an açık renkte kalır, sonra iner; küre bir an parlar
		lost_fill = maxf(lost_fill, liquid_fill)
		lost_wait = LOST_DELAY
		flash = 1.0
	target = fill
	update_layers()


## Değer değişmeden küreyi parlat (mana yetmediğinde)
func blink() -> void:
	flash = 1.0


func _process(delta: float) -> void:
	liquid_fill = lerpf(liquid_fill, target, 1.0 - exp(-delta / DRAIN_TIME))
	if lost_wait > 0:
		lost_wait -= delta
	else:
		lost_fill = move_toward(lost_fill, liquid_fill, LOST_SPEED * delta)
	lost_fill = maxf(lost_fill, liquid_fill)
	flash = move_toward(flash, 0.0, delta / FLASH_TIME)
	update_layers()


func update_layers() -> void:
	liquid.material.set_shader_parameter("fill", liquid_fill)
	liquid.material.set_shader_parameter("flash", flash)
	lost.material.set_shader_parameter("fill", lost_fill)
