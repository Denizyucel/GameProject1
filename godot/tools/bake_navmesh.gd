# Ana sahnedeki "Gezinme" (NavigationRegion3D) bölgesinin navmesh'ini, içindeki şekillerden çıkarıp
# levels/yanik_kutuphane_nav.tres dosyasına kaydeder. Bölgede parça taşıyınca yeniden çalıştır
# (ya da editörde Gezinme düğümünü seçip üstteki "Bake NavigationMesh" düğmesine bas).
#
# Çalıştırma (pencere kısa süre açılır; şekil verisi için gerçek çizici gerekir):
#   godot --path godot -s tools/bake_navmesh.gd

extends SceneTree


func _initialize() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var region: NavigationRegion3D = main.get_node("Gezinme")
	var started := Time.get_ticks_msec()
	region.bake_navigation_mesh(false) # false: beklet, bitince devam et
	var mesh := region.navigation_mesh
	print("Navmesh: %d çokgen, %d köşe, %d ms" % [mesh.get_polygon_count(), mesh.get_vertices().size(), Time.get_ticks_msec() - started])
	var error := ResourceSaver.save(mesh, mesh.resource_path)
	print("Kaydedildi: ", mesh.resource_path, " (", error_string(error), ")")
	quit()
