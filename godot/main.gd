# Ana sahne: oyunun parçalarını birbirine bağlar (Hikaye.md, çekirdek döngü).
#   - Düşmanın mührü kırılınca (canı bitince): mühür kırma efekti ve "Teşekkür ederiz…" fısıltısı
#   - Bedeni gömülünce: yerinde ceset (et yığını)
#   - 1 tuşu: oyuncu 8 m içindeki en yakın cesede büyü yapar; büyünün yarısında cesetten iskelet kalkar
#   - En fazla 5 iskelet: sınır doluyken yenisi kalkarsa rastgele biri ruhunu serbest bırakıp yok olur

extends Node3D

const SEAL_BREAK := preload("res://effects/seal_break.tscn")
const CORPSE := preload("res://minions/corpse.tscn")
const MINION := preload("res://minions/minion.tscn")
const THANKS_WHISPER := "Teşekkür ederiz…"
const RAISE_KEYS := [KEY_1, KEY_KP_1] # üst sıradaki 1 ve sayı tuş takımındaki 1
const RAISE_RANGE := 8.0 # oyuncudan en fazla bu uzaklıktaki ceset kaldırılabilir
const RAISE_MOMENT := 0.5 # iskeletin büyünün hangi anında (0..1) kalktığı
const MAX_MINIONS := 5
# Altın açı (≈137.5°): her yeni iskelet oyuncunun çevresinde bir öncekinden bu kadar dönük yere
# yerleşir; kaç iskelet olursa olsun çembere eşit dağılırlar
const GOLDEN_ANGLE := PI * (3.0 - sqrt(5.0))

@onready var hud = $HUD
@onready var player = $Player

var minions: Array[Node3D] = []
var raised_count := 0 # şimdiye kadar kaldırılan iskelet sayısı (yerlerini seçer)
var cast_target: Node3D # bu büyüyle kalkacak ceset; kalkınca null


func _ready() -> void:
	# Düşmanlar kendi _ready'lerinde "dusman" grubuna girdi (çocuklar ebeveynden önce hazırlanır)
	for enemy in get_tree().get_nodes_in_group("dusman"):
		enemy.seal_broken.connect(on_seal_broken)
		enemy.buried.connect(on_buried)
	hud.set_minions(0)


func on_seal_broken(enemy: Node3D) -> void:
	spawn_effect(enemy.global_position, false)
	hud.whisper(THANKS_WHISPER)


func spawn_effect(at: Vector3, release: bool) -> void:
	var effect := SEAL_BREAK.instantiate()
	effect.release = release
	add_child(effect)
	effect.global_position = Vector3(at.x, 0, at.z)


func on_buried(at: Vector3) -> void:
	var corpse := CORPSE.instantiate()
	add_child(corpse)
	corpse.global_position = at


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
	if player.start_cast(corpse.global_position) < 0:
		return false
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
