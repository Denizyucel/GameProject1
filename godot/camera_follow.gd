# İzometrik kamera: hedefi (karakteri) yumuşakça takip eder, hiç dönmez; tekerlekle yakınlaşır.
# Ekran sarsıntısı: GameCamera.shake(miktar) her yerden çağrılır (vuruş, hasar, mühür kırılması). Miktarlar
# "sarsıntı"da (0..1) birikir, hızla söner; kamera ekran düzleminde (sağ/yukarı) rastgele kayar. Kayma
# sarsıntının karesiyle orantılı: küçük darbeler hafif, üst üste gelenler belirgin olur.

class_name GameCamera
extends Camera3D

static var active: GameCamera # sahnedeki oyun kamerası (ara sahnede yok: shake hiçbir şey yapmaz)

@export var target: Node3D
const OFFSET := Vector3(20, 20, 20) # hedefe göre konumu; üç eksende eşit = izometrik açı
const FOLLOW := 5.0 # takip sıkılığı (büyüdükçe daha hızlı yetişir)
const VIEW_HEIGHT := 18.0 # yakınlaşma 1 iken ekranda görünen yükseklik (metre)
const MIN_ZOOM := 0.6
const MAX_ZOOM := 3.0
const ZOOM_STEP := 1.15 # tekerleğin her tıkında yakınlaşma oranı
const ZOOM_SMOOTH := 12.0
const SHAKE_REACH := 1.0 # sarsıntı 1 iken en fazla kayma (metre, yakınlaşma 1'de; ekranda ~40 piksel). Kılıç ~5, mühür ~14 piksel
const SHAKE_FADE := 2.0 # sarsıntının saniyede sönen miktarı (kılıç ~0.17 sn, mühür ~0.3 sn sürer)

var focus := Vector3.ZERO
var zoom := 1.0
var zoom_target := 1.0
var trauma := 0.0 # şu anki sarsıntı (0 = yok, 1 = en güçlü)


## Ekranı sars: amount 0..1 (kılıç darbesi ~0.35, hasar almak ~0.5, mühür kırılması ~0.6)
static func shake(amount: float) -> void:
	if active:
		active.trauma = minf(active.trauma + amount, 1.0)


func _enter_tree() -> void:
	active = self


func _exit_tree() -> void:
	if active == self:
		active = null


func _ready() -> void:
	if target:
		focus = Terrain.on_ground(target.global_position)
	global_position = focus + OFFSET


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = clampf(zoom_target * ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = clampf(zoom_target / ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
	var pinch := event as InputEventMagnifyGesture # trackpad'de iki parmakla yakınlaşma
	if pinch:
		zoom_target = clampf(zoom_target * pinch.factor, MIN_ZOOM, MAX_ZOOM)


func _process(delta: float) -> void:
	if target:
		# Hedefin konumu hep y = 0'da; engebeli zeminde göründüğü yükseklik eklenir (levels/terrain.gd)
		focus = focus.lerp(Terrain.on_ground(target.global_position), 1.0 - exp(-FOLLOW * delta))
	trauma = maxf(trauma - SHAKE_FADE * delta, 0.0)
	var reach := SHAKE_REACH * trauma * trauma / zoom # yakınlaşınca metre küçülür: ekrandaki kayma aynı kalır
	var axes := global_transform.basis
	global_position = focus + OFFSET + (axes.x * randf_range(-1, 1) + axes.y * randf_range(-1, 1)) * reach
	zoom = lerpf(zoom, zoom_target, 1.0 - exp(-ZOOM_SMOOTH * delta))
	size = VIEW_HEIGHT / zoom
