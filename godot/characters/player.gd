# Oyuncu karakteri (Ruh Kıran): tıklanan yere navmesh üzerinden ya da WASD ile yürür, Shift + tıkla
# kılıç sallar; darbe anında önündeki düşmana vurur. Canı biterse ölür, biraz sonra doğuş noktasında kalkar.
# Model: player.tscn'deki "Model" düğümü (Mixamo kemik adlı herhangi bir karakter). Animasyonlar başka
# dosyalardan gelip bu modele uyarlanır (RigAnimations). Ayarlar editörde, Player'ın Inspector'ında.

extends Node3D

## Can değişince gönderilir (HUD'daki can küresi dinler)
signal health_changed(health: float, max_health: float)
## Ölünce ve yeniden doğunca gönderilir (HUD "Öldün" yazısını gösterir/gizler)
signal died
signal respawned

const MOVE_SPEED := 3.0 # metre / saniye
const TURN_SPEED := 12.0 # dönüşün ne kadar hızlı yetiştiği (büyüdükçe daha keskin)
const ANIMATION_BLEND := 0.2 # bekleme ↔ yürüme geçişinin süresi (saniye)

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
const ATTACK_DAMAGE := 10.0
const HIT_REACH := 2.2 # darbe anında düşman en fazla bu kadar uzakta olabilir (metre)
const HIT_ARC := 0.3 # düşman ne kadar önde olmalı (1 = tam önde, 0 = yanda; kosinüs)

const DEATH_FILE := "res://assets/animations/creature/mutant-dying.fbx"

# Büyü (iskelet kaldırma): Mixamo "Magic Spell Pack"ten rastgele biri, 1.5 kat hızlı
const SPELL_COUNT := 12
const SPELL_FILE := "res://assets/animations/spell/spell%d.fbx"
const SPELL_TIME_SCALE := 1.5
const RESPAWN_DELAY := 4.0

# Bekleme ve yürüme animasyonlarının dosyası ve dosyadaki adı
@export_file("*.fbx", "*.glb") var idle_file := "res://assets/character/idle.fbx"
@export var idle_name := "mixamo_com"
@export_file("*.fbx", "*.glb") var walk_file := "res://assets/character/walk.fbx"
@export var walk_name := "mixamo_com"
@export var max_health := 100.0

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = model.find_child("AnimationPlayer")
@onready var skeleton: Skeleton3D = model.find_child("Skeleton3D")

var health := max_health
var alive := true
var spawn_point := Vector3.ZERO
var walk_clip_speed := 0.0 # yürüme animasyonunda ayakların ilerlediği hız (metre / saniye, oyundaki ölçekte)
var walking := false
var attack_moves: Array[Dictionary] = [] # her vuruş: {name, hit_moment}
var attack: Dictionary = {} # süren vuruş; boşsa vurmuyor
var attack_time := 0.0 # süren vuruşun kaç saniyedir sürdüğü
var attack_has_hit := false
var death_time := 0.0
var spell_names: Array[String] = []
var cast_time := -1.0 # büyü başladıysa kaç saniyedir sürdüğü; -1 ise büyü yapmıyor
var cast_duration := 1.0


func _ready() -> void:
	add_to_group("oyuncu") # düşmanlar oyuncuyu bu grupla bulur
	spawn_point = global_position
	var library := AnimationLibrary.new()
	library.add_animation("idle", RigAnimations.take(idle_file, idle_name, animation_player, skeleton))
	var walk := RigAnimations.take(walk_file, walk_name, animation_player, skeleton)
	RigAnimations.remove_root_motion(walk)
	library.add_animation("walk", walk)
	for i in ATTACK_FILES.size():
		if not ResourceLoader.exists(ATTACK_FILES[i]):
			continue
		var move := RigAnimations.take(ATTACK_FILES[i], "mixamo_com", animation_player, skeleton, false)
		RigAnimations.remove_root_motion(move) # vururken öne kaymasın
		library.add_animation("vurus%d" % (i + 1), move)
	for i in range(1, SPELL_COUNT + 1):
		var path := SPELL_FILE % i
		if ResourceLoader.exists(path):
			var spell := RigAnimations.take(path, "mixamo_com", animation_player, skeleton, false)
			RigAnimations.remove_root_motion(spell)
			library.add_animation("buyu%d" % i, spell)
			spell_names.append("hareket/buyu%d" % i)
	if ResourceLoader.exists(DEATH_FILE):
		library.add_animation("olum", RigAnimations.take(DEATH_FILE, "mixamo_com", animation_player, skeleton, false))
	animation_player.add_animation_library("hareket", library)

	# Ölçümler (bir kez): yürümenin ayak hızı ve her vuruşun darbe anı
	walk_clip_speed = RigAnimations.stride_speed(animation_player, skeleton, "hareket/walk")
	for i in ATTACK_FILES.size():
		var animation_name := "hareket/vurus%d" % (i + 1)
		if animation_player.has_animation(animation_name):
			var moment := RigAnimations.fastest_hand_moment(animation_player, skeleton, animation_name)
			attack_moves.append({"name": animation_name, "hit_moment": moment})
	animation_player.play("hareket/idle")

	var sword_scene := load(SWORD_FILE) as PackedScene
	if sword_scene:
		var sword := Weapon.prepare_sword(sword_scene.instantiate(), SWORD_LENGTH, SWORD_GRIP)
		if not Weapon.attach_to_hand(skeleton, "Right", sword):
			push_warning("Kılıç takılamadı: modelin sağ elinde gerekli kemikler yok")
			sword.free()


## Canı azalt (eksi değer canı artırır). Can biterse ölür.
func take_damage(amount: float) -> void:
	if not alive:
		return
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0:
		die()


## Vuruş, büyü ya da ölüm sürerken yeni bir şey başlamaz
func is_busy() -> bool:
	return not alive or not attack.is_empty() or cast_time >= 0


## Hedefe dön ve rastgele bir büyü animasyonu başlat. Büyünün süresini döndürür (başlayamazsa -1).
func start_cast(toward: Vector3) -> float:
	if is_busy():
		return -1.0
	agent.target_position = global_position # yürümeyi bırak
	walking = false
	var to_target := toward - global_position
	if Vector2(to_target.x, to_target.z).length() > 0.01:
		rotation.y = atan2(to_target.x, to_target.z)
	cast_time = 0.0
	cast_duration = 1.0
	if not spell_names.is_empty():
		var spell: String = spell_names.pick_random()
		animation_player.play(spell, ATTACK_BLEND)
		animation_player.seek(0.0, true)
		animation_player.speed_scale = SPELL_TIME_SCALE
		cast_duration = animation_player.get_animation(spell).length / SPELL_TIME_SCALE
	return cast_duration


## Süren büyünün ilerlemesi (0..1); büyü yapmıyorsa -1
func cast_progress() -> float:
	return minf(cast_time / cast_duration, 1.0) if cast_time >= 0 else -1.0


func die() -> void:
	alive = false
	attack = {}
	cast_time = -1.0
	walking = false
	agent.target_position = global_position
	death_time = 0.0
	if animation_player.has_animation("hareket/olum"):
		animation_player.play("hareket/olum", ANIMATION_BLEND)
		animation_player.speed_scale = 1.0
	died.emit()


func respawn() -> void:
	alive = true
	health = max_health
	global_position = spawn_point
	agent.target_position = spawn_point
	animation_player.play("hareket/idle", ANIMATION_BLEND)
	health_changed.emit(health, max_health)
	respawned.emit()


# Sol tık: tıklanan zemin noktasına yürü. Shift + sol tık: olduğun yerde o yöne kılıç salla.
func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if is_busy():
		return # ölüyken, vururken ya da büyü yaparken yeni bir şey başlamaz
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
	if attack_moves.is_empty():
		return
	agent.target_position = global_position # yürümeyi bırak
	walking = false
	var to_target := toward - global_position
	if Vector2(to_target.x, to_target.z).length() > 0.01:
		rotation.y = atan2(to_target.x, to_target.z) # vuruşta beklemeden hedefe dön
	attack = attack_moves.pick_random()
	attack_time = 0.0
	attack_has_hit = false
	animation_player.play(attack["name"], ATTACK_BLEND)
	animation_player.seek(0.0, true) # aynı vuruş arka arkaya seçildiyse baştan başlasın
	animation_player.speed_scale = ATTACK_TIME_SCALE


# Vuruşu ilerlet: darbe anında önündeki en yakın düşmana vur, bitince beklemeye dön
func update_attack(delta: float) -> void:
	attack_time += delta
	var duration: float = animation_player.get_animation(attack["name"]).length / ATTACK_TIME_SCALE
	var progress := attack_time / duration
	if not attack_has_hit and progress >= attack["hit_moment"]:
		attack_has_hit = true
		var target := enemy_in_front()
		if target:
			target.hit(global_position, ATTACK_DAMAGE)
	if progress >= 1.0:
		attack = {}
		animation_player.play("hareket/idle", ANIMATION_BLEND)
		animation_player.speed_scale = 1.0


# Kılıcın erişebileceği, önündeki en yakın canlı düşman (yoksa null)
func enemy_in_front() -> Node3D:
	var forward := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var best: Node3D = null
	var best_distance := HIT_REACH
	for enemy in get_tree().get_nodes_in_group("dusman"):
		if not enemy.alive:
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0
		var distance := to_enemy.length()
		if distance > best_distance:
			continue
		if distance > 0.3 and forward.dot(to_enemy / distance) < HIT_ARC:
			continue # arkada ya da çok yanda
		best = enemy
		best_distance = distance
	return best


# WASD ya da ok tuşları: ekrana göre yön (W = ekranın yukarısı). Tuşların klavyedeki yerine bakılır,
# ki Türkçe ya da başka bir klavye düzeninde de aynı tuşlar çalışsın. Basılı değilse sıfır.
func keyboard_direction() -> Vector3:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1
	if input == Vector2.ZERO:
		return Vector3.ZERO
	# Kameranın sağı ve ileri yönü, yere düzleştirilmiş: ekranın sağı ve yukarısı dünyada nereye düşüyor
	var camera := get_viewport().get_camera_3d()
	var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	var up := Vector3(-camera.global_basis.z.x, 0, -camera.global_basis.z.z).normalized()
	return (right * input.x - up * input.y).normalized()


# Klavyeyle bir adım: istenen noktaya en yakın yürünebilir noktaya git. Duvara doğru yürürken navmesh'in
# kenarına yapışıp boyunca kayar (tarayıcıdaki "çarpışmalı yürüme"nin karşılığı).
func walk_with_keys(direction: Vector3, delta: float) -> void:
	var wanted := global_position + direction * MOVE_SPEED * delta
	var map := agent.get_navigation_map()
	# Navmesh zeminden path_height_offset kadar yukarıda; aynı yükseklikte sor
	var allowed := NavigationServer3D.map_get_closest_point(map, wanted + Vector3.UP * agent.path_height_offset)
	global_position = Vector3(allowed.x, global_position.y, allowed.z)
	face(direction, delta)


# Model +z yönüne bakıyor: verilen yöne yumuşakça dön
func face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() > 0.01:
		var target_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 1.0 - exp(-TURN_SPEED * delta))


func _physics_process(delta: float) -> void:
	if not alive:
		death_time += delta
		if death_time >= RESPAWN_DELAY:
			respawn()
		return
	if not attack.is_empty():
		update_attack(delta)
		return # vururken yürümez
	if cast_time >= 0:
		cast_time += delta
		if cast_time >= cast_duration:
			cast_time = -1.0
			animation_player.play("hareket/idle", ANIMATION_BLEND)
			animation_player.speed_scale = 1.0
		return # büyü yaparken yürümez

	var was_walking := walking
	var key_direction := keyboard_direction()
	if key_direction != Vector3.ZERO:
		# Klavyeyle yürürken tıklanan hedef unutulur
		if not agent.is_navigation_finished():
			agent.target_position = global_position
		walk_with_keys(key_direction, delta)
		walking = true
	else:
		walking = not agent.is_navigation_finished()
		if walking:
			face(RigAnimations.step_along_path(agent, self, MOVE_SPEED, delta), delta)

	if walking != was_walking:
		if walking:
			animation_player.play("hareket/walk", ANIMATION_BLEND)
			# Yürüme animasyonunu karakterin hızına uydur, ayaklar yerde kaymasın
			animation_player.speed_scale = MOVE_SPEED / walk_clip_speed if walk_clip_speed > 0 else 1.0
		else:
			animation_player.play("hareket/idle", ANIMATION_BLEND)
			animation_player.speed_scale = 1.0
