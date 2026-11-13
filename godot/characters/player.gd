# Oyuncu karakteri (Ruh Kıran): tıklanan yere navmesh üzerinden yürür.
# Model: Mixamo "Nightshade" (assets/character/nightshade.fbx); bekleme ve yürüme animasyonları ayrı
# dosyalardan (idle.fbx, walk.fbx) alınıp modelin AnimationPlayer'ına eklenir.

extends Node3D

const MOVE_SPEED := 3.0 # metre / saniye
const TURN_SPEED := 12.0 # dönüşün ne kadar hızlı yetiştiği (büyüdükçe daha keskin)
const ANIMATION_BLEND := 0.2 # bekleme ↔ yürüme geçişinin süresi (saniye)

const IDLE_FILE := "res://assets/character/idle.fbx"
const WALK_FILE := "res://assets/character/walk.fbx"
# Mixamo animasyon dosyalarında animasyonun adı hep bu
const MIXAMO_ANIMATION := "mixamo_com"
const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer

var walk_clip_speed := 0.0 # yürüme animasyonunda ayakların ilerlediği hız (metre / saniye, model ölçeğinde)
var walking := false


func _ready() -> void:
	var library := AnimationLibrary.new()
	library.add_animation("idle", take_animation(IDLE_FILE))
	var walk := take_animation(WALK_FILE)
	walk_clip_speed = remove_root_motion(walk) * model.scale.x
	library.add_animation("walk", walk)
	animation_player.add_animation_library("hareket", library)
	# Yürüme animasyonunu karakterin hızına uydur, ayaklar yerde kaymasın
	animation_player.speed_scale = 1.0
	animation_player.play("hareket/idle")


# Bir Mixamo dosyasındaki animasyonu kopyalayıp al (dosyanın kendi modeli atılır)
func take_animation(path: String) -> Animation:
	var source: Node = (load(path) as PackedScene).instantiate()
	var player: AnimationPlayer = source.find_child("AnimationPlayer")
	var animation: Animation = player.get_animation(MIXAMO_ANIMATION).duplicate()
	source.free()
	animation.loop_mode = Animation.LOOP_LINEAR
	return animation


# Yürüme animasyonu kalçayı ileri taşır (root motion); karakteri biz yürüttüğümüz için kalçayı
# yerinde tut. Animasyonun kendi ilerleme hızını döndürür (metre / saniye).
func remove_root_motion(animation: Animation) -> float:
	var track := animation.find_track(NodePath(HIPS_TRACK), Animation.TYPE_POSITION_3D)
	if track == -1:
		return 0.0
	var count := animation.track_get_key_count(track)
	var first: Vector3 = animation.track_get_key_value(track, 0)
	var last: Vector3 = animation.track_get_key_value(track, count - 1)
	for i in count:
		var value: Vector3 = animation.track_get_key_value(track, i)
		animation.track_set_key_value(track, i, Vector3(first.x, value.y, first.z))
	return Vector2(last.x - first.x, last.z - first.z).length() / animation.length


# Sol tık: tıklanan zemin noktasına yürü
func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var camera := get_viewport().get_camera_3d()
	# Kameradan farenin altına doğru bir ışın gönder, zemin düzlemine (y = 0) çarptığı yeri bul
	var origin := camera.project_ray_origin(click.position)
	var direction := camera.project_ray_normal(click.position)
	var hit = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	if hit != null:
		agent.target_position = hit # navmesh dışına tıklanırsa ajan en yakın yürünebilir noktaya gider


func _physics_process(delta: float) -> void:
	var was_walking := walking
	walking = not agent.is_navigation_finished()
	if walking:
		# Ajan yolun bir sonraki köşesini söyler; oraya doğru düz yürü
		var next := agent.get_next_path_position()
		var to_next := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
		var step := MOVE_SPEED * delta
		if to_next.length() <= step:
			global_position = Vector3(next.x, global_position.y, next.z)
		else:
			global_position += to_next.normalized() * step
		if to_next.length() > 0.01:
			# Model +z yönüne bakıyor: yürüme yönüne yumuşakça dön
			var target_angle := atan2(to_next.x, to_next.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 1.0 - exp(-TURN_SPEED * delta))

	if walking != was_walking:
		if walking:
			animation_player.play("hareket/walk", ANIMATION_BLEND)
			animation_player.speed_scale = MOVE_SPEED / walk_clip_speed if walk_clip_speed > 0 else 1.0
		else:
			animation_player.play("hareket/idle", ANIMATION_BLEND)
			animation_player.speed_scale = 1.0
