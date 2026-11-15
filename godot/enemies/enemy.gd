# Düşman (şimdilik assets/enemies/enemy1.glb: gümüş zırhlı, pençeli şövalye). Vampirlerin yerini aldı.
# Evinin çevresinde dolaşır, oyuncuyu ya da bir iskeleti (en yakınını) fark edince kovalayıp pençesiyle vurur. Vurulunca kırmızı parlar,
# kızar ve daha uzaktan kovalar. Canı bitince ölüm animasyonuyla yıkılır, toprağa gömülür ve silinir.
# Dövüş tarzı (STYLES) karıştırılmış bir torbadan dağıtılır: 4 düşmanda 4 tarzın hepsi çıkar.

extends Node3D

## Canı bittiği an gönderilir (mühür kırma efekti buna bağlanacak)
signal seal_broken(enemy: Node3D)
## Bedeni toprağa gömülüp silinmeden hemen önce gönderilir (yerinde ceset kalır)
signal buried(at: Vector3)

# Dolaşma
const WALK_SPEED := 1.2 # metre / saniye
const WANDER_RADIUS := 5.0
const WAIT_MIN := 1.5
const WAIT_MAX := 4.0
# Fark etme ve kovalama
const AGGRO_RANGE := 5.0 # oyuncuyu bu kadar yakından fark eder
const ANGER_TIME := 6.0 # vurulunca bu kadar saniye kızgın kalır
const GIVE_UP_RANGE := 12.0 # kızgınken bu kadar uzağa kadar kovalar
const CHASE_REPATH := 0.4 # kovalarken yolu kaç saniyede bir yeniler
const FOE_SCAN := 0.3 # kime saldıracağına (oyuncu ya da iskelet) kaç saniyede bir yeniden bakar
const FOE_STICK := 1.0 # şu anki rakibi, bundan fazla yakın biri çıkmadıkça bırakmaz (metre)
# Saldırı
const ATTACK_RANGE := 1.6 # bu kadar yakına gelince vurmaya başlar
const HIT_REACH := 2.2 # darbe anında oyuncu bu kadar yakındaysa hasar alır
# Vurulma ve ölüm
const HIT_FLASH := 0.3 # kırmızı parlamanın süresi
const STUN_TIME := 0.4 # vurulunca şaşırıp durduğu süre
const STUN_MIN_DAMAGE := 8.0 # bundan hafif vuruşlar (iskeletinki, 5) şaşırtmaz: 5 iskelet düşmanı kilitlemesin
const DEATH_SPEED := 1.5 # devrilme animasyonu kaç kat hızlı oynasın
const FADE_OUT := 0.7 # yere düşünce bedenin yumuşakça kaybolma süresi (ceset aynı anda belirir)
const TURN_SPEED := 10.0
const ANIMATION_BLEND := 0.2

const STYLES := [
	{"name": "Avcı", "health": 30.0, "damage": 6.0, "size": 1.0, "chase": "walk", "chase_speed": 2.0,
		"attack_speed": 1.15, "cooldown": 0.7, "taunts": false}, # dengeli
	{"name": "Vahşi", "health": 40.0, "damage": 10.0, "size": 1.12, "chase": "run", "chase_speed": 2.6,
		"attack_speed": 0.85, "cooldown": 1.2, "taunts": true}, # iri, ağır vurur, kas gösterir
	{"name": "Çevik", "health": 22.0, "damage": 4.0, "size": 0.92, "chase": "run", "chase_speed": 2.8,
		"attack_speed": 1.6, "cooldown": 0.3, "taunts": false}, # zayıf ama seri
	{"name": "Muhafız", "health": 50.0, "damage": 7.0, "size": 1.05, "chase": "walk", "chase_speed": 1.6,
		"attack_speed": 0.95, "cooldown": 0.9, "taunts": true}, # çok dayanıklı, yavaş
]

# Animasyonlar: [kütüphanedeki ad, dosya, dosyadaki ad, döngü mü]
const ANIMATIONS := [
	["idle", "res://assets/character/idle.fbx", "mixamo_com", true],
	["idle2", "res://assets/animations/creature/mutant-breathing-idle.fbx", "mixamo_com", true],
	["idle3", "res://assets/animations/creature/mutant-idle.fbx", "mixamo_com", true],
	["walk", "res://assets/enemies/enemy1.glb", "Walking", true],
	["run", "res://assets/enemies/enemy1.glb", "Running", true],
	["pence", "res://assets/animations/creature/mutant-swiping.fbx", "mixamo_com", false],
	["gosteri", "res://assets/animations/creature/mutant-flexing-muscles.fbx", "mixamo_com", false],
	["olum", "res://assets/animations/creature/mutant-dying.fbx", "mixamo_com", false],
]

# Bütün düşmanların paylaştığı animasyonlar ve ölçümler (ilk düşman hazırlar)
static var shared_library: AnimationLibrary
static var clip_speeds := {} # yürüme/koşmanın ayak hızı, boy 1 iken (metre / saniye)
static var claw_hit_moment := 0.45
static var landing_moment := 1.0 # ölüm animasyonunda bedenin yere vardığı an (saniye); o an cesede döner
static var style_bag: Array = []

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = model.find_child("AnimationPlayer")
@onready var skeleton: Skeleton3D = model.find_child("Skeleton3D")

var style: Dictionary
var health := 1.0
var alive := true
var home := Vector3.ZERO
var player: Node3D
var foe: Node3D # saldırdığı: oyuncu ya da bir iskelet (en yakındaki)
var foe_timer := 0.0
var flash_material := StandardMaterial3D.new()

var wait_time := 0.0
var chasing := false
var repath_timer := 0.0
var angry_until := 0.0
var cooldown := 0.0
var stun_time := 0.0
var taunt_time := 0.0
var attack_time := -1.0 # vuruş başladıysa kaç saniyedir sürdüğü; -1 ise vurmuyor
var attack_has_hit := false
var hit_time := -10.0
var last_damage := 0.0 # son vuruşun hasarı (can barı ilk açıldığında kayıp kısmı göstermek için)
var death_time := -1.0
var idle_animation := "hareket/idle"
var current := ""


func _ready() -> void:
	add_to_group("dusman")
	home = global_position
	style = next_style()
	health = style["health"]
	model.scale *= style["size"]
	wait_time = randf_range(0.0, WAIT_MAX)

	if shared_library == null:
		prepare_shared_animations()
	animation_player.add_animation_library("hareket", shared_library)
	idle_animation = ["hareket/idle", "hareket/idle2", "hareket/idle3"].pick_random()
	play(idle_animation)
	animation_player.seek(randf() * animation_player.current_animation_length) # hepsi aynı anda kıpırdamasın

	# Vurulunca kırmızı parlama: modelin üstüne çizilen, normalde görünmez bir katman
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_material.albedo_color = Color(1, 0.15, 0.1, 0)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = flash_material


func prepare_shared_animations() -> void:
	shared_library = AnimationLibrary.new()
	for spec in ANIMATIONS:
		if ResourceLoader.exists(spec[1]):
			var animation := RigAnimations.take(spec[1], spec[2], animation_player, skeleton, spec[3])
			RigAnimations.remove_root_motion(animation)
			shared_library.add_animation(spec[0], animation)
	animation_player.add_animation_library("hareket", shared_library)
	# Ölçülen hız bu düşmanın boyuna göre; boy 1 iken olacak hıza çevirip sakla
	for move in ["walk", "run"]:
		clip_speeds[move] = RigAnimations.stride_speed(animation_player, skeleton, "hareket/" + move) / style["size"]
	claw_hit_moment = RigAnimations.fastest_hand_moment(animation_player, skeleton, "hareket/pence", 0.45)
	if shared_library.has_animation("olum"):
		landing_moment = RigAnimations.landing_moment(animation_player, skeleton, "hareket/olum")
	animation_player.remove_animation_library("hareket")


func next_style() -> Dictionary:
	if style_bag.is_empty():
		style_bag = STYLES.duplicate()
		style_bag.shuffle()
	return style_bag.pop_back()


## Vurul: canı azalt, kıvılcım saç, kırmızı parla, saldırana dön, şaşır ve kız. Öldüyse true döner.
func hit(from: Vector3, damage: float) -> bool:
	if not alive:
		return false
	health -= damage
	hit_time = now()
	last_damage = damage
	HitSpark.burst(get_parent(), from, global_position, clampf(damage / 12.0, 0.3, 1.0))
	angry_until = now() + ANGER_TIME
	face_now(from)
	if health <= 0:
		die()
		return true
	taunt_time = 0.0 # kas gösterisi kesilir; vuruş kesilmez
	if attack_time < 0 and damage >= STUN_MIN_DAMAGE:
		stun_time = STUN_TIME
	return false


func die() -> void:
	alive = false
	death_time = 0.0
	attack_time = -1.0
	agent.target_position = global_position
	remove_from_group("dusman")
	animation_player.speed_scale = DEATH_SPEED
	play("hareket/olum")
	seal_broken.emit(self)


func _physics_process(delta: float) -> void:
	update_flash()
	if not alive:
		update_death(delta)
		return
	if player == null:
		player = get_tree().get_first_node_in_group("oyuncu")
		if player == null:
			return

	if attack_time >= 0:
		update_attack(delta)
		return
	cooldown -= delta
	foe_timer -= delta
	if foe_timer <= 0 or not is_foe_valid(foe):
		foe_timer = FOE_SCAN
		foe = pick_foe()
	if taunt_time > 0:
		taunt_time -= delta
		if is_foe_valid(foe):
			face_now(foe.global_position)
		return
	if stun_time > 0:
		stun_time -= delta
		play(idle_animation)
		return

	if foe == null:
		if chasing:
			chasing = false # kaçtı ya da öldü: evine dön, sonra yine dolaşsın
			agent.target_position = home
		wander(delta)
		return
	var distance := ground_distance(foe.global_position)

	if not chasing:
		chasing = true
		# Yeni fark etti. Gösteri yapan tarzsa (ve vurulup kızmadıysa) önce kaslarını göstersin.
		if style["taunts"] and now() >= angry_until and shared_library.has_animation("gosteri"):
			agent.target_position = global_position
			face_now(foe.global_position)
			animation_player.speed_scale = 1.0
			play("hareket/gosteri")
			taunt_time = animation_player.current_animation_length
			return

	if distance <= ATTACK_RANGE:
		agent.target_position = global_position
		face_now(foe.global_position)
		if cooldown <= 0:
			start_attack()
		else:
			play(idle_animation)
			animation_player.speed_scale = 1.0
		return

	# Kovala: rakibin bana bakan tarafına, ondan 1 m öteye yürü; yolu belli aralıklarla yenile
	repath_timer -= delta
	if repath_timer <= 0:
		repath_timer = CHASE_REPATH
		var away := (global_position - foe.global_position)
		away.y = 0
		agent.target_position = foe.global_position + away.normalized()
	move(style["chase"], style["chase_speed"], delta)


## Rakip seç: oyuncu ve ayaktaki iskeletlerden 5 m içindeki en yakını (şu anki rakip 1 m avantajlı).
## Kızgınsa (yakın zamanda vurulduysa) 12 m'ye kadar bakar. Kimse yoksa null.
func pick_foe() -> Node3D:
	var reach := GIVE_UP_RANGE if now() < angry_until else AGGRO_RANGE
	var candidates: Array = get_tree().get_nodes_in_group("iskelet")
	candidates.append(player)
	var best: Node3D = null
	var best_distance := INF
	for candidate in candidates:
		if not is_foe_valid(candidate):
			continue
		var distance := ground_distance(candidate.global_position)
		if candidate == foe:
			distance -= FOE_STICK
		if distance <= reach and distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func is_foe_valid(candidate) -> bool: # tipsiz: silinmiş bir iskelet de gelebilir
	return is_instance_valid(candidate) and candidate.alive and candidate.global_position.distance_to(global_position) <= GIVE_UP_RANGE + 2.0


# Bekle, sonra evinin çevresinde rastgele bir yere yürü
func wander(delta: float) -> void:
	if agent.is_navigation_finished():
		play(idle_animation)
		animation_player.speed_scale = 1.0
		wait_time -= delta
		if wait_time > 0:
			return
		wait_time = randf_range(WAIT_MIN, WAIT_MAX)
		var angle := randf() * TAU
		var radius := sqrt(randf()) * WANDER_RADIUS # karekök: daire içine eşit dağılsın
		var wanted := home + Vector3(sin(angle), 0, cos(angle)) * radius
		agent.target_position = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), wanted)
		return
	move("walk", WALK_SPEED, delta)


# Yolda yürü; animasyonu gerçek hıza uydur, ayaklar kaymasın
func move(animation: String, speed: float, delta: float) -> void:
	var direction := RigAnimations.step_along_path(agent, self, speed, delta)
	if direction == Vector3.ZERO:
		return
	face(direction, delta)
	play("hareket/" + animation)
	var clip_speed: float = clip_speeds.get(animation, 0.0) * style["size"]
	animation_player.speed_scale = speed / clip_speed if clip_speed > 0 else 1.0


func start_attack() -> void:
	attack_time = 0.0
	attack_has_hit = false
	current = "" # aynı vuruş art arda gelirse baştan başlasın
	play("hareket/pence")
	animation_player.seek(0.0, true)
	animation_player.speed_scale = style["attack_speed"]


# Vuruşu ilerlet; darbe anında rakip (oyuncu ya da iskelet) hâlâ yakındaysa hasar ver
func update_attack(delta: float) -> void:
	attack_time += delta
	var duration := animation_player.get_animation("hareket/pence").length / float(style["attack_speed"])
	var progress := attack_time / duration
	if not attack_has_hit and progress >= claw_hit_moment:
		attack_has_hit = true
		if is_foe_valid(foe) and ground_distance(foe.global_position) <= HIT_REACH:
			foe.take_damage(style["damage"])
	if progress >= 1.0:
		attack_time = -1.0
		cooldown = style["cooldown"]


func update_flash() -> void:
	var t := (now() - hit_time) / HIT_FLASH
	flash_material.albedo_color.a = 0.0 if t >= 1.0 else (1.0 - t) * 0.6


# Devrilir; bedeni yere vardığı an yumuşakça kaybolurken yerinde ceset belirir (main.gd buried'i dinler)
func update_death(delta: float) -> void:
	if death_time < 0:
		return # kayboluyor
	death_time += delta
	if death_time >= landing_moment / animation_player.speed_scale:
		death_time = -1.0
		var hips := skeleton.find_bone(RigAnimations.HIPS_BONE)
		var at := global_position
		if hips != -1:
			at = skeleton.global_transform * skeleton.get_bone_global_pose(hips).origin
		buried.emit(Vector3(at.x, 0, at.z))
		# Saydamlık her şekle ayrı ayrı: 0 = tam görünür, 1 = görünmez
		var tween := create_tween().set_parallel()
		for mesh in model.find_children("*", "GeometryInstance3D", true, false):
			tween.tween_property(mesh, "transparency", 1.0, FADE_OUT)
		tween.chain().tween_callback(queue_free)


func play(animation: String) -> void:
	if current == animation:
		return
	current = animation
	animation_player.play(animation, ANIMATION_BLEND)


func face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-TURN_SPEED * delta))


func face_now(point: Vector3) -> void:
	var to_point := point - global_position
	if Vector2(to_point.x, to_point.z).length() > 0.01:
		rotation.y = atan2(to_point.x, to_point.z)


func ground_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func now() -> float:
	return Time.get_ticks_msec() / 1000.0

# Engebeli zeminde (Harabe Köy) yalnızca görüntü kalkar: konum (global_position) hep y = 0'da kalır,
# model zeminin yüksekliği kadar yukarı çizilir (levels/terrain.gd)
func _process(_delta: float) -> void:
	model.position.y = Terrain.height_at(global_position)
