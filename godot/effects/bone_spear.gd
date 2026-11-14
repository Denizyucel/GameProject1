# Kemik mızrağı: Necromancer'ın uzaktan saldırısı. Fırlatıldığı yönde düz uçar, yolundaki her düşmanı
# delip geçer (her birine bir kez vurur). Menzili bitince ya da duvara çarpınca kırılır, izi söner, silinir.
# Görsel dil (Hikaye.md): kemik beyazı mızrak, arkasında oyuncunun tarafının rengi kırmızı köz izi.

extends Node3D

const SPEED := 16.0 # metre / saniye
const RANGE := 14.0 # en fazla bu kadar uçar
const DAMAGE := 15.0
const HIT_RADIUS := 0.7 # düşmanın gövdesine bu kadar yaklaşınca vurur (metre)
const WALL_MARGIN := 0.6 # navmesh'ten bu kadar uzaklaşınca duvara çarpmış sayılır
const FADE_TIME := 0.4 # kırıldıktan sonra izin sönmesi

var direction := Vector3.FORWARD # fırlatan ayarlar (yatay, birim uzunlukta)
var travelled := 0.0
var height_above_ground := 1.0 # zeminden yüksekliği (fırlatılırken ayarlanır)
var broken := false
var fade_left := FADE_TIME
var already_hit: Array[Node3D] = []

@onready var spear: MeshInstance3D = $Mizrak
@onready var trail: GPUParticles3D = $Iz
@onready var light: OmniLight3D = $Isik


## Sahneye eklendikten sonra çağrılır: from noktasından, yatay toward yönüne fırlat
func launch(from: Vector3, toward: Vector3) -> void:
	direction = Vector3(toward.x, 0, toward.z).normalized()
	height_above_ground = from.y
	global_position = from + Vector3.UP * Terrain.height_at(from)
	# Mızrak +z ekseni boyunca çizildi: uçtuğu yöne çevir (look_at -z'yi hedefe çevirir)
	look_at(global_position - direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	if broken:
		fade_left -= delta
		light.light_energy = maxf(0.0, light.light_energy - delta * 8.0)
		if fade_left <= 0:
			queue_free()
		return

	var step := SPEED * delta
	global_position += direction * step
	global_position.y = height_above_ground + Terrain.height_at(global_position) # engebeli zemini izler
	travelled += step

	# Yolundaki düşmanlar: gövdesine yeterince yakın olan her birine bir kez vur, uçmaya devam et
	for enemy in get_tree().get_nodes_in_group("dusman"):
		if enemy in already_hit:
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		if Vector2(to_enemy.x, to_enemy.z).length() <= HIT_RADIUS:
			already_hit.append(enemy)
			enemy.hit(global_position - direction, DAMAGE)

	if travelled >= RANGE or hit_wall():
		break_apart()


# Duvar ya da büyük bir parça: mızrağın altındaki nokta yürünebilir zeminden (navmesh) uzaksa çarptı
func hit_wall() -> bool:
	var map := get_world_3d().navigation_map
	var ground := Vector3(global_position.x, 0.5, global_position.z)
	var closest := NavigationServer3D.map_get_closest_point(map, ground)
	return Vector2(closest.x - ground.x, closest.z - ground.z).length() > WALL_MARGIN


func break_apart() -> void:
	broken = true
	spear.visible = false
	trail.emitting = false
