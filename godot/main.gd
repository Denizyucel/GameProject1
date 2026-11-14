# Ana sahne: oyunun parçalarını birbirine bağlar (Hikaye.md, çekirdek döngü).
#   - Düşmanın mührü kırılınca (canı bitince): mühür kırma efekti ve "Teşekkür ederiz…" fısıltısı
#   - Bedeni gömülünce: yerinde ceset (et yığını); ara sıra can iksiri de düşer (alınınca can verir)
#   - 1 tuşu: oyuncu 8 m içindeki en yakın cesede büyü yapar; büyünün yarısında cesetten iskelet kalkar
#   - Harita tek parça: Yanık Kütüphane (düşmansız), güneyinde Kül Yolu, onun güneyinde Harabe Köy.
#     Düşmanlar ENEMY_SPAWNS'taki yerlere kodla konur.
#   - Kütüphane yanıyor: açılışta X'in tutuşturduğu raflar oyunda da yanmaya devam eder
#   - En fazla 5 iskelet: sınır doluyken yenisi kalkarsa rastgele biri ruhunu serbest bırakıp yok olur

class_name MainScene
extends Node3D

## Açılış ara sahnesinden gelindiyse true: Ruh Kıran kapıdan yürüyerek girer
static var after_intro := false

const SEAL_BREAK := preload("res://effects/seal_break.tscn")
const FIRE := preload("res://effects/fire.tscn")
# Açılışta X'in kıvılcımlarının tutuşturduğu raflar (en yakından uzağa); oyunda da yanmaya devam ederler
const FIRE_POINTS := [
	Vector3(-4, 0.4, -12.3), Vector3(4, 0.4, -12.3), Vector3(-7.5, 0.3, -8.5), Vector3(7.5, 0.3, -7.5),
	Vector3(-8, 0.4, -12.3), Vector3(8, 0.4, -12.3), Vector3(-7.5, 0.3, -6), Vector3(7.5, 0.3, -4.5),
	Vector3(-7.5, 0.3, -2), Vector3(7.5, 0.3, 1),
]
const ENEMY := preload("res://enemies/enemy.tscn")
const CORPSE := preload("res://minions/corpse.tscn")
const MINION := preload("res://minions/minion.tscn")
const POTION := preload("res://items/health_potion.tscn")
const POTION_CHANCE := 0.2 # ölen düşmanın can iksiri düşürme olasılığı (0..1)
const POTION_GAP := 2 # bir iksir düştükten sonra en az bu kadar ölümde iksir düşmez (art arda gelmesin)
const POTION_DISTANCE := 1.0 # iksir cesedin bu kadar yanına düşer (üstüne değil)
const THANKS_WHISPER := "Teşekkür ederiz…"
# Düşmanların yerleri (evleri; Hikaye.md): Kül Yolu'nda önce tek devriye, sonra iki;
# Harabe Köy'de 3, 4 ve 5'lik gruplar (köy girişi, meydan, batıdaki yokuş)
const ENEMY_SPAWNS := [
	Vector3(0.5, 0, 36), Vector3(-1.5, 0, 48), Vector3(2, 0, 50),
	Vector3(2, 0, 67), Vector3(5, 0, 68.5), Vector3(0, 0, 70.5),
	Vector3(0, 0, 75), Vector3(4, 0, 74.5), Vector3(2, 0, 77.5), Vector3(7, 0, 76.5),
	Vector3(-10, 0, 75.5), Vector3(-8, 0, 77.5), Vector3(-10, 0, 85), Vector3(-8, 0, 85.5), Vector3(-6.5, 0, 84.5),
]
const ENTER_FROM := Vector3(0, 0, 8) # güney kapı (X'in de girdiği yer)
const ENTER_TO := Vector3(0, 0, -5) # salonun ortası; yanmış raflara bakar
const ENTER_LINE := "Buraya ne oldu böyle?"
const RAISE_KEYS := [KEY_1, KEY_KP_1] # üst sıradaki 1 ve sayı tuş takımındaki 1
const RAISE_RANGE := 8.0 # oyuncudan en fazla bu uzaklıktaki ceset kaldırılabilir
const RAISE_MOMENT := 0.5 # iskeletin büyünün hangi anında (0..1) kalktığı
const MAX_MINIONS := 5
# Altın açı (≈137.5°): her yeni iskelet oyuncunun çevresinde bir öncekinden bu kadar dönük yere
# yerleşir; kaç iskelet olursa olsun çembere eşit dağılırlar
const GOLDEN_ANGLE := PI * (3.0 - sqrt(5.0))

@onready var hud = $HUD
@onready var player = $Player
@onready var enemies_root: Node3D = $Dusmanlar

var minions: Array[Node3D] = []
var raised_count := 0 # şimdiye kadar kaldırılan iskelet sayısı (yerlerini seçer)
var kills_since_potion := POTION_GAP # son iksirden beri ölen düşman sayısı (ilk ölümde düşebilir)
var cast_target: Node3D # bu büyüyle kalkacak ceset; kalkınca null


func _ready() -> void:
	hud.set_minions(0)
	for point in FIRE_POINTS:
		var fire := FIRE.instantiate()
		add_child(fire)
		fire.global_position = point
		fire.ignite()
	for point in ENEMY_SPAWNS:
		var enemy := ENEMY.instantiate()
		enemy.position = point # evi burası olur (_ready'de)
		enemies_root.add_child(enemy)
		enemy.seal_broken.connect(on_seal_broken)
		enemy.buried.connect(on_enemy_fell)
	# Açılıştan geldiyse: Ruh Kıran kapıdan girer, salonun ortasında durup yangının izlerine bakar
	if after_intro:
		after_intro = false
		player.enter_scene(ENTER_FROM, ENTER_TO)
		player.arrived.connect(func(): hud.say(ENTER_LINE), CONNECT_ONE_SHOT)


func on_seal_broken(enemy: Node3D) -> void:
	spawn_effect(enemy.global_position, false)
	hud.whisper(THANKS_WHISPER)
	GameCamera.shake(0.6)


func spawn_effect(at: Vector3, release: bool) -> void:
	var effect := SEAL_BREAK.instantiate()
	effect.release = release
	add_child(effect)
	effect.global_position = Terrain.on_ground(at)


## Düşman yere düştü: yerinde ceset kalır, ara sıra da can iksiri düşer
func on_enemy_fell(at: Vector3) -> void:
	on_buried(at)
	if kills_since_potion >= POTION_GAP and randf() < POTION_CHANCE:
		kills_since_potion = 0
		drop_potion(at)
	else:
		kills_since_potion += 1


## at noktasından yanındaki rastgele bir yere can iksiri düşür (yürünebilir zemine çekilir)
func drop_potion(at: Vector3) -> Node3D:
	var angle := randf() * TAU
	var wanted := at + Vector3(sin(angle), 0, cos(angle)) * POTION_DISTANCE
	var landing := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, wanted)
	var potion := POTION.instantiate()
	add_child(potion)
	potion.drop(Terrain.on_ground(at) + Vector3.UP * 0.5, Terrain.on_ground(landing))
	return potion


func on_buried(at: Vector3) -> void:
	var corpse := CORPSE.instantiate()
	add_child(corpse)
	corpse.global_position = Terrain.on_ground(at)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode in RAISE_KEYS:
		raise_dead()


## 1 tuşu: en yakın cesede büyü yapmaya başla
func raise_dead() -> bool:
	if player.is_busy():
		return false
	var corpse := nearest_corpse()
	if corpse == null:
		return false
	if player.mana < player.RAISE_MANA:
		player.not_enough_mana.emit()
		return false
	if player.start_cast(corpse.global_position) < 0:
		return false
	player.spend_mana(player.RAISE_MANA)
	cast_target = corpse
	return true


func nearest_corpse() -> Node3D:
	var best: Node3D = null
	var best_distance := RAISE_RANGE
	for corpse in get_tree().get_nodes_in_group("ceset"):
		var distance: float = Vector2(corpse.global_position.x - player.global_position.x,
			corpse.global_position.z - player.global_position.z).length()
		if distance <= best_distance:
			best = corpse
			best_distance = distance
	return best


func _process(_delta: float) -> void:
	if cast_target == null:
		return
	var progress: float = player.cast_progress()
	if progress < 0 or not is_instance_valid(cast_target):
		# Büyü yarıda kaldı (oyuncu öldü): ceset parlamayı bıraksın
		if is_instance_valid(cast_target):
			cast_target.set_glow(0.0)
		cast_target = null
		return
	# Ceset büyünün ilk yarısında giderek parlar; yarısında iskelet kalkar
	cast_target.set_glow(progress / RAISE_MOMENT)
	if progress >= RAISE_MOMENT:
		raise_skeleton(cast_target)
		cast_target = null


func raise_skeleton(corpse: Node3D) -> void:
	if minions.size() >= MAX_MINIONS:
		release_minion(minions.pick_random())
	corpse.sink()
	var minion := MINION.instantiate()
	minion.leader = player
	minion.slot_angle = raised_count * GOLDEN_ANGLE
	raised_count += 1
	add_child(minion)
	var at: Vector3 = corpse.global_position
	minion.global_position = Vector3(at.x, 0, at.z)
	var to_player: Vector3 = player.global_position - minion.global_position
	minion.rotation.y = atan2(to_player.x, to_player.z) # efendisine dönük kalksın
	minions.append(minion)
	hud.set_minions(minions.size())


## İskeleti serbest bırak: ruhu mavi ışıkla yükselir, kemikleri yok olur
func release_minion(minion: Node3D) -> void:
	spawn_effect(minion.global_position, true)
	minions.erase(minion)
	minion.queue_free()
	hud.set_minions(minions.size())
