# İzometrik kamera: hedefi (karakteri) yumuşakça takip eder, hiç dönmez; tekerlekle yakınlaşır.

extends Camera3D

@export var target: Node3D
const OFFSET := Vector3(20, 20, 20) # hedefe göre konumu; üç eksende eşit = izometrik açı
const FOLLOW := 5.0 # takip sıkılığı (büyüdükçe daha hızlı yetişir)
const VIEW_HEIGHT := 18.0 # yakınlaşma 1 iken ekranda görünen yükseklik (metre)
const MIN_ZOOM := 0.6
const MAX_ZOOM := 3.0
const ZOOM_STEP := 1.15 # tekerleğin her tıkında yakınlaşma oranı
const ZOOM_SMOOTH := 12.0

var focus := Vector3.ZERO
var zoom := 1.0
var zoom_target := 1.0


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
	global_position = focus + OFFSET
	zoom = lerpf(zoom, zoom_target, 1.0 - exp(-ZOOM_SMOOTH * delta))
	size = VIEW_HEIGHT / zoom
