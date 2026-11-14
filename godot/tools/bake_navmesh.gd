# Ana sahnedeki "Gezinme" (NavigationRegion3D) bölgesinin navmesh'ini çıkarıp levels/act1_nav.tres dosyasına
# kaydeder (Yanık Kütüphane + Kül Yolu + Harabe Köy). Bölgede parça taşıyınca yeniden çalıştır.
# Harabe Köy'ün zemini engebeli tek bir model olduğu için navmesh'e modelin kendisi girmez: köy bölgesine,
# zemin verisinde (levels/harabe_koy_terrain.res) yürünebilir işaretli karelerden düz bir zemin eklenir.
# Bu yüzden editördeki "Bake NavigationMesh" düğmesi köyü yürünemez bırakır; hep bu betiği kullan.
#
# Çalıştırma (pencere kısa süre açılır; şekil verisi için gerçek çizici gerekir):
#   godot --path godot -s tools/bake_navmesh.gd

extends SceneTree

const TERRAIN_FILE := "res://levels/harabe_koy_terrain.res"


func _initialize() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var region: NavigationRegion3D = main.get_node("Gezinme")
	var started := Time.get_ticks_msec()
	var mesh := region.navigation_mesh
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	if ResourceLoader.exists(TERRAIN_FILE):
		source.add_faces(walkable_faces(load(TERRAIN_FILE)), Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	print("Navmesh: %d çokgen, %d köşe, %d ms" % [mesh.get_polygon_count(), mesh.get_vertices().size(), Time.get_ticks_msec() - started])
	var error := ResourceSaver.save(mesh, mesh.resource_path)
	print("Kaydedildi: ", mesh.resource_path, " (", error_string(error), ")")
	quit()


## Zemin verisindeki yürünebilir kareler, y = 0'da düz üçgenler olarak (her satırda yan yana kareler tek şerit)
func walkable_faces(data: TerrainData) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for z in data.size_z:
		var run_start := -1
		for x in data.size_x + 1:
			var free := x < data.size_x and data.blocked[z * data.size_x + x] == 0
			if free and run_start == -1:
				run_start = x
			elif not free and run_start != -1:
				var x0 := data.origin.x + run_start * data.cell
				var x1 := data.origin.x + x * data.cell
				var z0 := data.origin.y + z * data.cell
				var z1 := z0 + data.cell
				faces.append_array([
					Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x0, 0, z1),
					Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1),
				])
				run_start = -1
	return faces
