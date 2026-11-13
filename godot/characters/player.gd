# Oyuncu karakteri (Ruh Kıran): tıklanan yere navmesh üzerinden yürür.
# Model: player.tscn'deki "Model" düğümü (Mixamo kemik adlı herhangi bir karakter). Bekleme ve yürüme
# animasyonları aşağıdaki dosyalardan alınır; başka bir modelden geliyorsa yeni modelin iskeletine
# uyarlanır (iz yolları ve kalça yüksekliği). Ayarlar editörde, Player düğümünün Inspector'ında.

extends Node3D

const MOVE_SPEED := 3.0 # metre / saniye
const TURN_SPEED := 12.0 # dönüşün ne kadar hızlı yetiştiği (büyüdükçe daha keskin)
const ANIMATION_BLEND := 0.2 # bekleme ↔ yürüme geçişinin süresi (saniye)
const HIPS_BONE := "mixamorig_Hips"

# Kılıç: sağ elde. Boyu (metre) ve elin tuttuğu yer (bıçak ucundan ölçülen boy oranı)
const SWORD_FILE := "res://assets/weapons/sword.glb"
const SWORD_LENGTH := 1.1
const SWORD_GRIP := 0.89

# Kılıç vuruşları (Mixamo "Lite Sword and Shield Pack"): her vuruşta rastgele biri oynar
const ATTACK_FILES := [
	"res://assets/animations/sword/attack.fbx",
	"res://assets/animations/sword/attack2.fbx",
	"res://assets/animations/sword/attack3.fbx",
	"res://assets/animations/sword/attack4.fbx",
]
const ATTACK_TIME_SCALE := 1.3 # vuruşlar kaç kat hızlı oynasın
const ATTACK_BLEND := 0.1

# Bekleme ve yürüme animasyonlarının dosyası ve dosyadaki adı
@export_file("*.fbx", "*.glb") var idle_file := "res://assets/character/idle.fbx"
@export var idle_name := "mixamo_com"
@export_file("*.fbx", "*.glb") var walk_file := "res://assets/character/walk.fbx"
@export var walk_name := "mixamo_com"

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = model.find_child("AnimationPlayer")
@onready var skeleton: Skeleton3D = model.find_child("Skeleton3D")

var walk_clip_speed := 0.0 # yürüme animasyonunda ayakların ilerlediği hız (metre / saniye, oyundaki ölçekte)
var walking := false
var attack_names: Array[String] = [] # yüklenen vuruş animasyonlarının adları
var attack_time_left := 0.0 # süren vuruşun bitmesine kalan süre (saniye); 0 ise vurmuyor


func _ready() -> void:
	var library := AnimationLibrary.new()
	library.add_animation("idle", take_animation(idle_file, idle_name))
	var walk := take_animation(walk_file, walk_name)
	walk_clip_speed = remove_root_motion(walk) * model.scale.x
	library.add_animation("walk", walk)
	for i in ATTACK_FILES.size():
		if not ResourceLoader.exists(ATTACK_FILES[i]):
			continue
		var attack := take_animation(ATTACK_FILES[i], "mixamo_com")
		attack.loop_mode = Animation.LOOP_NONE # bir kez oynar
		remove_root_motion(attack) # vururken öne kaymasın
		library.add_animation("vurus%d" % (i + 1), attack)
		attack_names.append("hareket/vurus%d" % (i + 1))
	animation_player.add_animation_library("hareket", library)
	animation_player.play("hareket/idle")

	var sword_scene := load(SWORD_FILE) as PackedScene
	if sword_scene:
		var sword := Weapon.prepare_sword(sword_scene.instantiate(), SWORD_LENGTH, SWORD_GRIP)
		if not Weapon.attach_to_hand(skeleton, "Right", sword):
			push_warning("Kılıç takılamadı: modelin sağ elinde gerekli kemikler yok")
			sword.free()


# Bir dosyadaki animasyonun kopyasını al ve bu modelin iskeletine uyarla
func take_animation(path: String, animation_name: String) -> Animation:
	var source: Node = (load(path) as PackedScene).instantiate()
	var source_player: AnimationPlayer = source.find_child("AnimationPlayer")
	var source_skeleton: Skeleton3D = source.find_child("Skeleton3D")
	var animation: Animation = source_player.get_animation(animation_name).duplicate()

	# İz yolları "iskeletin yolu:kemik" biçiminde; iskeletin bu modeldeki yolunu yaz
	var target_root := animation_player.get_node(animation_player.root_node)
	var target_path := String(target_root.get_path_to(skeleton))
	# Kalça konumunu iki karakterin kalça yüksekliği oranında ölçekle (kısa karakter havada yürümesin)
	var height_ratio := hips_height(skeleton) / hips_height(source_skeleton)
	for track in animation.get_track_count():
		var bone := String(animation.track_get_path(track)).get_slice(":", 1)
		animation.track_set_path(track, NodePath(target_path + ":" + bone))
		if bone == HIPS_BONE and animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
			for key in animation.track_get_key_count(track):
				animation.track_set_key_value(track, key, animation.track_get_key_value(track, key) * height_ratio)
	source.free()
	animation.loop_mode = Animation.LOOP_LINEAR
	return animation


func hips_height(target: Skeleton3D) -> float:
	var bone := target.find_bone(HIPS_BONE)
	return target.get_bone_global_rest(bone).origin.y if bone != -1 else 1.0


# Yürüme animasyonu kalçayı ileri taşır (root motion); karakteri biz yürüttüğümüz için kalçayı
# yerinde tut. Animasyonun kendi ilerleme hızını döndürür (metre / saniye).
func remove_root_motion(animation: Animation) -> float:
	var track := -1
	for i in animation.get_track_count():
		if String(animation.track_get_path(i)).ends_with(":" + HIPS_BONE) and animation.track_get_type(i) == Animation.TYPE_POSITION_3D:
			track = i
	if track == -1:
		return 0.0
	var count := animation.track_get_key_count(track)
	var first: Vector3 = animation.track_get_key_value(track, 0)
	var last: Vector3 = animation.track_get_key_value(track, count - 1)
	for i in count:
		var value: Vector3 = animation.track_get_key_value(track, i)
		animation.track_set_key_value(track, i, Vector3(first.x, value.y, first.z))
	return Vector2(last.x - first.x, last.z - first.z).length() / animation.length


# Sol tık: tıklanan zemin noktasına yürü. Shift + sol tık: olduğun yerde o yöne kılıç salla.
func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if attack_time_left > 0:
		return # vuruş bitmeden yeni bir şey başlamaz
	var camera := get_viewport().get_camera_3d()
	# Kameradan farenin altına doğru bir ışın gönder, zemin düzlemine (y = 0) çarptığı yeri bul
	var origin := camera.project_ray_origin(click.position)
	var direction := camera.project_ray_normal(click.position)
	var hit = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	if hit == null:
		return
	if click.shift_pressed:
		start_attack(hit)
	else:
		agent.target_position = hit # navmesh dışına tıklanırsa ajan en yakın yürünebilir noktaya gider


# Yürümeyi bırak, hedefe dön ve rastgele bir kılıç vuruşu başlat
func start_attack(toward: Vector3) -> void:
	if attack_names.is_empty():
		return
	agent.target_position = global_position # yürümeyi bırak
	walking = false
	var to_target := toward - global_position
	if Vector2(to_target.x, to_target.z).length() > 0.01:
		rotation.y = atan2(to_target.x, to_target.z) # vuruşta beklemeden hedefe dön
	var attack: String = attack_names.pick_random()
	animation_player.play(attack, ATTACK_BLEND)
	animation_player.seek(0.0, true) # aynı vuruş arka arkaya seçildiyse baştan başlasın
	animation_player.speed_scale = ATTACK_TIME_SCALE
	attack_time_left = animation_player.get_animation(attack).length / ATTACK_TIME_SCALE


func _physics_process(delta: float) -> void:
	if attack_time_left > 0:
		attack_time_left -= delta
		if attack_time_left <= 0:
			attack_time_left = 0
			animation_player.play("hareket/idle", ANIMATION_BLEND)
			animation_player.speed_scale = 1.0
		return # vururken yürümez

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
			# Yürüme animasyonunu karakterin hızına uydur, ayaklar yerde kaymasın
			animation_player.speed_scale = MOVE_SPEED / walk_clip_speed if walk_clip_speed > 0 else 1.0
		else:
			animation_player.play("hareket/idle", ANIMATION_BLEND)
			animation_player.speed_scale = 1.0
