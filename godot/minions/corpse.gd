# Ceset: mührü kırılan düşmanın geride bıraktığı et yığını (flesh.glb). Oyuncu 1 tuşuyla iskeleti bunun
# içinden kaldırır: büyü sırasında mavi parlar, iskelet kalkınca toprağa gömülüp silinir.

extends Node3D

const FLESH_FILE := "res://assets/minion/flesh.glb"
const SIZE := 1.1 # yerde kapladığı en uzun kenar (metre)
const GLOW := Color(0.49, 0.77, 1.0)
const MAX_GLOW := 0.5
const SINK_TIME := 1.2
const SINK_DEPTH := 0.45
const FADE_IN := 0.7 # düşmanın bedeni kaybolurken ceset bu sürede belirir

var glow_material := StandardMaterial3D.new()
var sink_time := -1.0 # gömülmeye başladıysa kaç saniyedir; -1 ise yerinde duruyor
var model: Node3D


func _ready() -> void:
	add_to_group("ceset")
	rotation.y = randf() * TAU
	model = (load(FLESH_FILE) as PackedScene).instantiate()
	var box := Weapon.scene_aabb(model, Transform3D.IDENTITY)
	var scale_factor := SIZE / maxf(box.size.x, box.size.z)
	model.scale = Vector3.ONE * scale_factor
	var center := box.get_center()
	model.position = Vector3(-center.x, -box.position.y, -center.z) * scale_factor # ortası burada, tabanı yerde
	add_child(model)

	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_material.albedo_color = Color(GLOW, 0.0)
	var tween := create_tween().set_parallel()
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = glow_material
		mesh.transparency = 1.0 # görünmez başla, yumuşakça belir
		tween.tween_property(mesh, "transparency", 0.0, FADE_IN)


## Parlama: 0 = yok, 1 = en parlak
func set_glow(amount: float) -> void:
	glow_material.albedo_color.a = clampf(amount, 0.0, 1.0) * MAX_GLOW


## İskelet kalktı: yavaşça gömül ve silin
func sink() -> void:
	remove_from_group("ceset")
	sink_time = 0.0


func _process(delta: float) -> void:
	if sink_time < 0:
		return
	sink_time += delta
	var t := minf(sink_time / SINK_TIME, 1.0)
	position.y = -t * t * SINK_DEPTH
	set_glow(1.0 - t)
	if t >= 1.0:
		queue_free()
