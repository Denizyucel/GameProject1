# Harabe Köy'ün modeli (koy.glb) ve zemin bilgisi. Model tek parça ve zemini engebeli; sahneye girince
# zemin verisini Terrain'e verir, çıkınca geri alır. Model Gezinme'nin DIŞINDA durur: navmesh düz kalır,
# evlerin yeri navmesh'ten tools/bake_navmesh.gd ile (zemin verisindeki "yürünemez" karelere göre) oyulur.
# Modeli taşır ya da ölçeklersen: tools/build_village_terrain.gd, sonra tools/bake_navmesh.gd.

extends Node3D

const TERRAIN_FILE := "res://levels/harabe_koy_terrain.res"


func _enter_tree() -> void:
	if ResourceLoader.exists(TERRAIN_FILE):
		Terrain.data = load(TERRAIN_FILE)


func _exit_tree() -> void:
	Terrain.data = null
