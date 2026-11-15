# Harabe Köy'ün modeli (koy.glb) ve zemin bilgisi. Model tek parça ve zemini engebeli; sahneye girince
# zemin verisini Terrain'e verir, çıkınca geri alır. Model Gezinme'nin DIŞINDA durur: navmesh düz kalır,
# evlerin yeri navmesh'ten tools/bake_navmesh.gd ile (zemin verisindeki "yürünemez" karelere göre) oyulur.
# Modeli taşır ya da ölçeklersen: tools/build_village_terrain.gd, sonra tools/bake_navmesh.gd.
#
# Görüş penceresi: karakter köyün içindeyken önünde kalan evler (çatı, duvar) karakterin çevresinde noktalı
# olarak silinir (materials/koy.gdshader). Modelin kendi malzemesi açılışta aynı dokularla bu shader'a çevrilir.

extends Node3D

const TERRAIN_FILE := "res://levels/harabe_koy_terrain.res"
const SHADER := preload("res://materials/koy.gdshader")
const AREA := Rect2(-20, 60, 40, 44) # köyün dünyadaki alanı (x, z); karakter buradayken pencere açılır
const CHEST := 1.0 # pencerenin merkezi: karakterin bastığı yerden bu kadar yukarısı
const OPEN_SPEED := 3.0 # pencerenin açılıp kapanma hızı (saniyede)

@onready var mesh: MeshInstance3D = $Model/Mesh
var material: ShaderMaterial
var strength := 0.0


func _enter_tree() -> void:
	if ResourceLoader.exists(TERRAIN_FILE):
		Terrain.data = load(TERRAIN_FILE)


func _exit_tree() -> void:
	Terrain.data = null


func _ready() -> void:
	var original := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("texture_albedo", original.albedo_texture)
	material.set_shader_parameter("texture_orm", original.roughness_texture)
	material.set_shader_parameter("texture_normal", original.normal_texture)
	mesh.material_override = material


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("oyuncu") as Node3D
	var camera := get_viewport().get_camera_3d()
	if player == null or camera == null:
		return
	var at := player.global_position
	var inside := AREA.has_point(Vector2(at.x, at.z))
	strength = move_toward(strength, 1.0 if inside else 0.0, OPEN_SPEED * delta)
	var feet := Terrain.on_ground(at)
	material.set_shader_parameter("hole_strength", strength)
	material.set_shader_parameter("hole_center", feet + Vector3.UP * CHEST)
	material.set_shader_parameter("hole_floor", feet.y)
	material.set_shader_parameter("camera_forward", camera.global_transform.basis.z)
