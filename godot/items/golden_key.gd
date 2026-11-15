# Altın anahtar: Altın Şampiyon'un mührü kırılınca düşer (main.gd). Model dosyası yok, kodla kurulur (halka, sap,
# iki diş; parlak altın). İksir gibi yanına sıçrar, yerde dönüp süzülür, altın ışığı vardır. Oyuncu yanına gelince
# kendiliğinden alınır; main.gd picked sinyalini dinler (görev ilerler).

class_name GoldenKey
extends Node3D

signal picked

const PICKUP_RADIUS := 1.2
const POP_TIME := 0.5
const POP_HEIGHT := 1.4
const HOVER := 0.45
const SPIN := 1.8
const GOLD := Color(1.0, 0.78, 0.3)

var body := Node3D.new()
var light := OmniLight3D.new()
var pop_from := Vector3.ZERO
var pop_to := Vector3.ZERO
var pop_time := -1.0
var age := 0.0
var taken := false


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = GOLD
	material.metallic = 0.9
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = GOLD
	material.emission_energy_multiplier = 0.5
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.07
	torus.outer_radius = 0.12
	ring.mesh = torus
	ring.rotation.x = PI / 2 # halka dik dursun
	ring.position.y = 0.2
	var shaft := MeshInstance3D.new()
	var shaft_box := BoxMesh.new()
	shaft_box.size = Vector3(0.035, 0.32, 0.035)
	shaft.mesh = shaft_box
	shaft.position.y = -0.02
	body.add_child(ring)
	body.add_child(shaft)
	for i in 2:
		var tooth := MeshInstance3D.new()
		var tooth_box := BoxMesh.new()
		tooth_box.size = Vector3(0.08, 0.035, 0.03)
		tooth.mesh = tooth_box
		tooth.position = Vector3(0.05, -0.12 + i * 0.07, 0)
		body.add_child(tooth)
	for part in body.get_children():
		(part as MeshInstance3D).material_override = material
	body.scale = Vector3.ONE * 1.6
	add_child(body)
	light.light_color = GOLD
	light.light_energy = 1.2
	light.omni_range = 2.5
	light.position.y = 0.6
	add_child(light)


## Şampiyonun düştüğü yerden yanındaki bir noktaya sıçra
func drop(from: Vector3, to: Vector3) -> void:
	pop_from = from
	pop_to = to
	pop_time = 0.0
	global_position = from


func _process(delta: float) -> void:
	age += delta
	body.rotation.y += SPIN * delta
	if pop_time >= 0:
		pop_time += delta
		var t := minf(pop_time / POP_TIME, 1.0)
		global_position = pop_from.lerp(pop_to, t) + Vector3.UP * (4.0 * t * (1.0 - t) * POP_HEIGHT)
		if t >= 1.0:
			pop_time = -1.0
		return
	body.position.y = HOVER + sin(age * 2.2) * 0.07
	if taken:
		return
	var player := get_tree().get_first_node_in_group("oyuncu") as Node3D
	if player == null or not player.alive:
		return
	var to_player := player.global_position - global_position
	if Vector2(to_player.x, to_player.z).length() <= PICKUP_RADIUS:
		taken = true
		picked.emit()
		var tween := create_tween().set_parallel()
		tween.tween_property(body, "scale", Vector3.ONE * 0.01, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "global_position", Terrain.on_ground(player.global_position) + Vector3.UP * 1.2, 0.3)
		tween.tween_property(light, "light_energy", 0.0, 0.3)
		tween.chain().tween_callback(queue_free)
