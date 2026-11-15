# İskelet minion (Hikaye.md: mührü kırılan düşmanın kemikleri gönüllü olarak kalkar). Model: Mixamo'da
# riglenmiş skeleton.fbx; sağ elinde kılıç (sword2.glb), sol ön kolunda kalkan (kalkan.glb).
# Topraktan mavi ışıkla yükselir, efendisini (oyuncuyu) takip eder; yakındaki düşmana koşup kılıçla vurur.
# Canı var: düşmanlar iskeletlere de saldırır (enemy.gd, en yakın rakip). Vurulunca kırmızı parlar; canı bitince
# fell sinyali gider, main.gd onu serbest bırakır (mavi ruh efekti, MAX_MINIONS dolunca olanla aynı).

extends Node3D

signal fell(minion: Node3D)

const MOVE_SPEED := 3.4 # metre / saniye (oyuncudan biraz hızlı ki yetişsin)
const FOLLOW_START := 3.0 # efendisinden bu kadar uzaklaşınca peşinden gider
const SLOT_DISTANCE := 1.6 # efendisinin çevresindeki yerinin uzaklığı
const REPATH := 0.4 # yolu kaç saniyede bir yeniler
const SIGHT_RANGE := 6.0 # bu kadar yakındaki düşmanı görür
const LEASH_RANGE := 10.0 # efendisinden bu kadar uzaktaki düşmanı kovalamaz
const SCAN_INTERVAL := 0.5
const ATTACK_RANGE := 1.5
const HIT_REACH := 2.1
const DAMAGE := 5.0
const MAX_HEALTH := 40.0 # düşmanın vuruşu 4-10: Vahşi'nin 4, Çevik'in 10 vuruşu
const HURT_FLASH := 0.3 # vurulunca kırmızı parlama süresi
const HURT_COLOR := Color(1, 0.15, 0.1)
const ATTACK_TIME_SCALE := 1.5
const ATTACK_COOLDOWN := 0.5
const RISE_TIME := 0.9 # topraktan çıkış süresi
const RISE_DEPTH := 1.8
const GLOW := Color(0.49, 0.77, 1.0) # kalkarken mavi parıltı (özgür ruhun rengi)
const TURN_SPEED := 12.0
const ANIMATION_BLEND := 0.2

# Kılıç ve kalkan (koyu dokulu oldukları için parlatılır)
const SWORD_FILE := "res://assets/weapons/sword2.glb"
const SWORD_LENGTH := 1.0
const SWORD_GRIP := 0.89
const SHIELD_FILE := "res://assets/weapons/kalkan.glb"
const SHIELD_HEIGHT := 0.8
const SHIELD_FACING := -1.0 # 1 iken süslü yüz gövdeye bakıyordu
const SHIELD_TOWARD_ELBOW := 0.12
const GEAR_BRIGHTNESS := 1.8
const GEAR_METALLIC := 0.5

const ANIMATIONS := [
	["idle", "res://assets/character/idle.fbx", "mixamo_com", true],
	["run", "res://assets/character/necromancer-kadin.glb", "Running", true],
	["vurus1", "res://assets/animations/sword/attack.fbx", "mixamo_com", false],
	["vurus2", "res://assets/animations/sword/attack2.fbx", "mixamo_com", false],
	["vurus3", "res://assets/animations/sword/attack3.fbx", "mixamo_com", false],
	["vurus4", "res://assets/animations/sword/attack4.fbx", "mixamo_com", false],
]

# Bütün iskeletlerin paylaştığı animasyonlar ve ölçümler (ilk iskelet hazırlar)
static var shared_library: AnimationLibrary
static var run_clip_speed := 0.0
static var attack_moves: Array[Dictionary] = []

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model
var rise_offset := 0.0 # topraktan çıkarken modelin zemine göre yüksekliği (eksi = toprağın altında)
@onready var animation_player: AnimationPlayer = model.find_child("AnimationPlayer")
@onready var skeleton: Skeleton3D = model.find_child("Skeleton3D")

var leader: Node3D # efendisi (oyuncu)
var slot_angle := 0.0 # efendisinin çevresindeki yeri (açı); her iskelet farklı yerde dursun
var glow_material := StandardMaterial3D.new()
var rise_time := 0.0
var repath_timer := 0.0
var scan_timer := 0.0
var target: Node3D
var attack: Dictionary = {}
var attack_time := 0.0
var attack_has_hit := false
var cooldown := 0.0
var current := ""
var health := MAX_HEALTH
var alive := false # topraktan çıkınca true; düşmanlar yalnızca ayaktaki canlı iskelete saldırır (enemy.is_foe_valid)
var hurt := 0.0 # kırmızı parlamanın kalan gücü (0..1)


func _ready() -> void:
	add_to_group("iskelet")
	if shared_library == null:
		prepare_shared_animations()
	animation_player.add_animation_library("hareket", shared_library)
	play("hareket/idle")
	attach_gear()

	# Kalkarken mavi parıltı: modelin üstüne eklenen, yavaşça sönen bir katman
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_material.albedo_color = Color(GLOW, 0.8)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = glow_material
	rise_offset = -RISE_DEPTH


func prepare_shared_animations() -> void:
	shared_library = AnimationLibrary.new()
	for spec in ANIMATIONS:
		if ResourceLoader.exists(spec[1]):
			var animation := RigAnimations.take(spec[1], spec[2], animation_player, skeleton, spec[3])
			RigAnimations.remove_root_motion(animation)
			shared_library.add_animation(spec[0], animation)
	animation_player.add_animation_library("hareket", shared_library)
	run_clip_speed = RigAnimations.stride_speed(animation_player, skeleton, "hareket/run")
	for i in 4:
		var animation_name := "hareket/vurus%d" % (i + 1)
		if animation_player.has_animation(animation_name):
			var moment := RigAnimations.fastest_hand_moment(animation_player, skeleton, animation_name)
			attack_moves.append({"name": animation_name, "hit_moment": moment})
	animation_player.remove_animation_library("hareket")


func attach_gear() -> void:
	if ResourceLoader.exists(SWORD_FILE):
		var sword_model: Node3D = (load(SWORD_FILE) as PackedScene).instantiate()
		Weapon.brighten(sword_model, GEAR_BRIGHTNESS, GEAR_METALLIC)
		var sword := Weapon.prepare_sword(sword_model, SWORD_LENGTH, SWORD_GRIP)
		if not Weapon.attach_to_hand(skeleton, "Right", sword):
			sword.free()
	if ResourceLoader.exists(SHIELD_FILE):
		var shield_model: Node3D = (load(SHIELD_FILE) as PackedScene).instantiate()
		Weapon.brighten(shield_model, GEAR_BRIGHTNESS, GEAR_METALLIC)
		var shield := Weapon.prepare_shield(shield_model, SHIELD_HEIGHT, SHIELD_FACING, SHIELD_TOWARD_ELBOW)
		if not Weapon.attach_to_hand(skeleton, "Left", shield):
			shield.free()


func _physics_process(delta: float) -> void:
	# Topraktan çıkış: yavaş başlayıp hızlanır, mavi parıltı söner
	if rise_time < RISE_TIME:
		rise_time += delta
		var t := minf(rise_time / RISE_TIME, 1.0)
		rise_offset = -RISE_DEPTH * (1.0 - t * t * (3.0 - 2.0 * t))
		glow_material.albedo_color.a = 0.8 * (1.0 - t)
		if t >= 1.0:
			alive = true
			glow_material.albedo_color = Color(HURT_COLOR, 0.0) # bundan sonra katman vurulma parlaması için
		return
	if hurt > 0:
		hurt = maxf(0.0, hurt - delta / HURT_FLASH)
		glow_material.albedo_color.a = 0.6 * hurt
	if leader == null:
		return

	if not attack.is_empty():
		update_attack(delta)
		return
	cooldown -= delta

	# Düşman ara: kendine 6 m'den yakın, efendisine 10 m'den yakın en yakın canlı düşman
	scan_timer -= delta
	if scan_timer <= 0:
		scan_timer = SCAN_INTERVAL
		target = find_target()
	if target and (not is_instance_valid(target) or not target.alive or ground_distance(leader.global_position, target.global_position) > LEASH_RANGE):
		target = null

	if target:
		var distance := ground_distance(global_position, target.global_position)
		if distance <= ATTACK_RANGE:
			agent.target_position = global_position
			face_now(target.global_position)
			if cooldown <= 0:
				start_attack()
			else:
				play("hareket/idle")
				animation_player.speed_scale = 1.0
			return
		chase(target.global_position, delta, 1.0)
		return

	# Efendisini takip et: uzaklaşınca kendi yerine (efendisinin çevresinde) koş
	if ground_distance(global_position, leader.global_position) > FOLLOW_START or not agent.is_navigation_finished():
		var slot := leader.global_position + Vector3(sin(slot_angle), 0, cos(slot_angle)) * SLOT_DISTANCE
		chase(slot, delta, 0.0)
	else:
		play("hareket/idle")
		animation_player.speed_scale = 1.0


# Bir noktaya koş; yolu belli aralıklarla yenile. stop_short: hedefin ne kadar önünde durulacağı
func chase(point: Vector3, delta: float, stop_short: float) -> void:
	repath_timer -= delta
	if repath_timer <= 0:
		repath_timer = REPATH
		var away := global_position - point
		away.y = 0
		agent.target_position = point + (away.normalized() * stop_short if away.length() > 0.01 else Vector3.ZERO)
	var direction := RigAnimations.step_along_path(agent, self, MOVE_SPEED, delta)
	if direction == Vector3.ZERO:
		play("hareket/idle")
		animation_player.speed_scale = 1.0
		return
	if Vector2(direction.x, direction.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-TURN_SPEED * delta))
	play("hareket/run")
	animation_player.speed_scale = MOVE_SPEED / run_clip_speed if run_clip_speed > 0 else 1.0


func find_target() -> Node3D:
	var best: Node3D = null
	var best_distance := SIGHT_RANGE
	for enemy in get_tree().get_nodes_in_group("dusman"):
		if ground_distance(leader.global_position, enemy.global_position) > LEASH_RANGE:
			continue
		var distance := ground_distance(global_position, enemy.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


func start_attack() -> void:
	if attack_moves.is_empty():
		return
	attack = attack_moves.pick_random()
	attack_time = 0.0
	attack_has_hit = false
	current = "" # aynı vuruş art arda gelirse baştan başlasın
	play(attack["name"])
	animation_player.seek(0.0, true)
	animation_player.speed_scale = ATTACK_TIME_SCALE


func update_attack(delta: float) -> void:
	attack_time += delta
	var duration: float = animation_player.get_animation(attack["name"]).length / ATTACK_TIME_SCALE
	var progress := attack_time / duration
	if not attack_has_hit and progress >= attack["hit_moment"]:
		attack_has_hit = true
		if target and is_instance_valid(target) and target.alive and ground_distance(global_position, target.global_position) <= HIT_REACH:
			target.hit(global_position, DAMAGE)
	if progress >= 1.0:
		attack = {}
		cooldown = ATTACK_COOLDOWN


## Düşman vurdu: canı azalt, kırmızı parla. Can biterse fell gönderir (main.gd serbest bırakır).
func take_damage(amount: float) -> void:
	if not alive:
		return
	health -= amount
	hurt = 1.0
	if health <= 0:
		alive = false
		remove_from_group("iskelet")
		fell.emit(self)


func play(animation: String) -> void:
	if current == animation:
		return
	current = animation
	animation_player.play(animation, ANIMATION_BLEND)


func face_now(point: Vector3) -> void:
	var to_point := point - global_position
	if Vector2(to_point.x, to_point.z).length() > 0.01:
		rotation.y = atan2(to_point.x, to_point.z)


func ground_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# Engebeli zeminde (Harabe Köy) yalnızca görüntü kalkar: konum (global_position) hep y = 0'da kalır,
# model zeminin yüksekliği kadar yukarı çizilir (levels/terrain.gd)
func _process(_delta: float) -> void:
	model.position.y = rise_offset + Terrain.height_at(global_position)
