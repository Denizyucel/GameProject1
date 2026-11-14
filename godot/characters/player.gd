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
const ENGAGE_RANGE := 1.7 # kovalanan düşmana bu kadar yaklaşınca vurmaya başlar (metre)
const CHASE_REPATH := 0.3 # kovalarken yolu kaç saniyede bir yeniler
# Tıklamayla düşman seçme: düşmanın ayağından bu yüksekliğe kadar, bu yarıçapta bir alan tıklanabilir
const PICK_HEIGHT := 2.0
const PICK_RADIUS := 0.6

const DEATH_FILE := "res://assets/animations/creature/mutant-dying.fbx"

# Büyü (iskelet kaldırma): Mixamo "Magic Spell Pack"ten rastgele biri, 1.5 kat hızlı
const SPELL_COUNT := 12
const SPELL_FILE := "res://assets/animations/spell/spell%d.fbx"
const SPELL_TIME_SCALE := 1.5

# Kemik mızrağı (sağ tık ya da Ctrl + tık): tek elle büyü hareketi, elin en hızlı ileri gittiği an fırlar
const BONE_SPEAR := preload("res://effects/bone_spear.tscn")
const SPEAR_SPELLS := [1, 2, 3] # Magic Spell Pack'in "Standing 1H Magic Attack 01-03"ü
const SPEAR_TIME_SCALE := 1.8
const SPEAR_COOLDOWN := 0.8 # iki mızrak arasında en az bu kadar saniye
const SPEAR_HEIGHT := 1.3 # mızrağın çıktığı yükseklik (göğüs)
const SPEAR_FORWARD := 0.6 # karakterin ne kadar önünden çıktığı
const RESPAWN_DELAY := 4.0
const WAKE_SPEED := 1.4 # uyanırken yerden kalkma hızı (ölüm animasyonu tersten, bu kat hızlı)

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
var wake_left := 0.0 # yerden kalkmanın bitmesine kalan süre (saniye)
var attack_target: Node3D # tıklanıp kovalanan düşman; null ise kimseyi kovalamıyor
var chase_timer := 0.0
var spell_names: Array[String] = []
var spear_moves: Array[Dictionary] = [] # her mızrak hareketi: {name, release}
var spear: Dictionary = {} # süren mızrak büyüsü; boşsa yok
var spear_time := 0.0
var spear_released := false
var spear_direction := Vector3.FORWARD
var spear_ready_at := 0.0 # bir sonraki mızrağın atılabileceği an (saniye)
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
	for index in SPEAR_SPELLS:
		var spell_name := "hareket/buyu%d" % index
		if animation_player.has_animation(spell_name):
			var release := RigAnimations.fastest_hand_moment(animation_player, skeleton, spell_name, 0.4)
			spear_moves.append({"name": spell_name, "release": release})
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


func is_target_valid() -> bool:
	return attack_target != null and is_instance_valid(attack_target) and attack_target.alive


func ground_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## Vuruş, büyü ya da ölüm sürerken yeni bir şey başlamaz
func is_busy() -> bool:
	return not alive or not attack.is_empty() or cast_time >= 0 or not spear.is_empty() or wake_left > 0


## Yerde yatarken kalk (açılış ara sahnesinden sonra): ölüm animasyonu tersten oynar, bitene kadar kontrol yok
func wake_up() -> void:
	if not animation_player.has_animation("hareket/olum"):
		return
	animation_player.play_backwards("hareket/olum")
	animation_player.speed_scale = WAKE_SPEED
	wake_left = animation_player.get_animation("hareket/olum").length / WAKE_SPEED


## Kemik mızrağı büyüsünü başlat: hedefe dön, el hareketi oynar, fırlatma anında mızrak çıkar
func start_spear(toward: Vector3) -> bool:
	if is_busy() or spear_moves.is_empty() or Time.get_ticks_msec() / 1000.0 < spear_ready_at:
		return false
	agent.target_position = global_position # yürümeyi bırak
	attack_target = null
	walking = false
	var to_target := Vector3(toward.x - global_position.x, 0, toward.z - global_position.z)
	spear_direction = to_target.normalized() if to_target.length() > 0.01 else Vector3(sin(rotation.y), 0, cos(rotation.y))
	rotation.y = atan2(spear_direction.x, spear_direction.z)
	spear = spear_moves.pick_random()
	spear_time = 0.0
	spear_released = false
	spear_ready_at = Time.get_ticks_msec() / 1000.0 + SPEAR_COOLDOWN
	animation_player.play(spear["name"], ATTACK_BLEND)
	animation_player.seek(0.0, true)
	animation_player.speed_scale = SPEAR_TIME_SCALE
	return true


func update_spear(delta: float) -> void:
	spear_time += delta
	var duration: float = animation_player.get_animation(spear["name"]).length / SPEAR_TIME_SCALE
	var progress := spear_time / duration
	if not spear_released and progress >= spear["release"]:
		spear_released = true
		var projectile := BONE_SPEAR.instantiate()
		get_parent().add_child(projectile)
		projectile.launch(global_position + Vector3.UP * SPEAR_HEIGHT + spear_direction * SPEAR_FORWARD, spear_direction)
	if progress >= 1.0:
		spear = {}
		animation_player.play("hareket/idle", ANIMATION_BLEND)
		animation_player.speed_scale = 1.0


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
	spear = {}
	attack_target = null
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
	if click == null or not click.pressed:
		return
	if click.button_index != MOUSE_BUTTON_LEFT and click.button_index != MOUSE_BUTTON_RIGHT:
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
	var enemy := enemy_under_cursor(click.position)
	# Sağ tık (Mac'te Ctrl + tık da): kemik mızrağı, düşmanın üstüne tıklandıysa ona
	if click.button_index == MOUSE_BUTTON_RIGHT or click.ctrl_pressed:
		start_spear(enemy.global_position if enemy else hit)
		return
	if click.shift_pressed:
		start_attack(enemy.global_position if enemy else hit)
	elif enemy:
		# Düşmana tıklandı: kovala, yetişince vur, ölene kadar vurmaya devam et
		attack_target = enemy
		chase_timer = 0.0
	else:
		attack_target = null # zemine tıklamak saldırıyı bırakır
		agent.target_position = hit # navmesh dışına tıklanırsa ajan en yakın yürünebilir noktaya gider


# Ekranda tıklanan noktanın altındaki canlı düşman (yoksa null). Her düşmanın ayağından başına uzanan bir
# çizgiye bakılır; tıklama bu çizgiye PICK_RADIUS metreden (ekranda) yakınsa o düşman seçilir.
func enemy_under_cursor(screen_point: Vector2) -> Node3D:
	var camera := get_viewport().get_camera_3d()
	var best: Node3D = null
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("dusman"):
		var feet: Vector3 = enemy.global_position
		var head := feet + Vector3.UP * PICK_HEIGHT
		var feet_on_screen := camera.unproject_position(feet)
		var head_on_screen := camera.unproject_position(head)
		# Ekranda PICK_RADIUS metre kaç piksel: kameranın sağına doğru o kadar ötedeki noktayla ölç
		var radius := (camera.unproject_position(feet + camera.global_basis.x * PICK_RADIUS) - feet_on_screen).length()
		var closest := Geometry2D.get_closest_point_to_segment(screen_point, feet_on_screen, head_on_screen)
		var distance := closest.distance_to(screen_point)
		if distance <= radius and distance < best_distance:
			best = enemy
			best_distance = distance
	return best


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
		# Kovalanan düşman erişimdeyse ona, değilse önündeki en yakın düşmana vur
		var target := enemy_in_front()
		if is_target_valid() and ground_distance(attack_target.global_position) <= HIT_REACH:
			target = attack_target
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
	if wake_left > 0:
		wake_left -= delta
		if wake_left <= 0:
			animation_player.play("hareket/idle", ANIMATION_BLEND)
			animation_player.speed_scale = 1.0
		return # kalkarken yürümez
	if not attack.is_empty():
		update_attack(delta)
		return # vururken yürümez
	if not spear.is_empty():
		update_spear(delta)
		return # mızrak atarken yürümez
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
		# Klavyeyle yürürken tıklanan hedef ve kovalanan düşman unutulur
		attack_target = null
		if not agent.is_navigation_finished():
			agent.target_position = global_position
		walk_with_keys(key_direction, delta)
		walking = true
	elif is_target_valid() and ground_distance(attack_target.global_position) <= ENGAGE_RANGE:
		# Kovalanan düşmana yetişti: vur (vuruş bitince düşman hâlâ yaşıyorsa yine buraya gelir)
		start_attack(attack_target.global_position)
		return
	else:
		if not is_target_valid():
			attack_target = null # öldü (ya da hiç yoktu): kovalamayı bırak
		if attack_target != null:
			# Kovala: hedef yürüdükçe yolu belli aralıklarla yenile
			chase_timer -= delta
			if chase_timer <= 0:
				chase_timer = CHASE_REPATH
				agent.target_position = attack_target.global_position
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
