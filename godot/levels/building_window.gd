# Gotik binanın görüş penceresi: karakter binanın arkasındayken (kuzey/batı yanında) binanın önünde kalan kısmı
# karakterin çevresinde noktalı olarak silinir (Harabe Köy'deki gibi; materials/pencere.gdshader). Binanın kendi
# malzemeleri (taş, ahşap, pencere ışığı...) açılışta aynı renk ve dokularla bu shader'a çevrilir.
# Bina see_through.gd'ye eklenmedi: kutusu meydanı da kapsadığından meydandaki oyuncu bütün binayı saydamlaştırıyordu.

extends Node3D

const SHADER := preload("res://materials/pencere.gdshader")
const REACH := 20.0 # binanın merkezinden bu kadar yakında pencere açılır (bina ~23 m; yanından geçerken de)
const CHEST := 1.0
const OPEN_SPEED := 3.0

@export var building: Node3D
var materials: Array[ShaderMaterial] = []
var strength := 0.0


func _ready() -> void:
	for node in building.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var original := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = SHADER
			if original.albedo_texture:
				material.set_shader_parameter("texture_albedo", original.albedo_texture)
			material.set_shader_parameter("albedo_color", original.albedo_color)
			material.set_shader_parameter("roughness", original.roughness)
			material.set_shader_parameter("metallic", original.metallic)
			if original.emission_enabled:
				material.set_shader_parameter("emission", original.emission)
				material.set_shader_parameter("emission_energy", original.emission_energy_multiplier)
			mesh_instance.set_surface_override_material(surface, material)
			materials.append(material)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("oyuncu") as Node3D
	var camera := get_viewport().get_camera_3d()
	if player == null or camera == null or materials.is_empty():
		return
	var at := player.global_position
	var near := Vector2(at.x - building.global_position.x, at.z - building.global_position.z).length() < REACH
	strength = move_toward(strength, 1.0 if near else 0.0, OPEN_SPEED * delta)
	var feet := Terrain.on_ground(at)
	for material in materials:
		material.set_shader_parameter("hole_strength", strength)
		material.set_shader_parameter("hole_center", feet + Vector3.UP * CHEST)
		material.set_shader_parameter("hole_floor", feet.y)
		material.set_shader_parameter("camera_forward", camera.global_transform.basis.z)
