# Harabe Köy'ü dener: Kül Yolu'nun ortasından köyün güney ucuna navmesh'te yol var mı, düşmanlar yerinde mi;
# köyün üç yerinden ekran görüntüsü alır.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/village_test.gd -- <klasör>

extends SceneTree

const FROM := Vector3(0, 0, 40) # Kül Yolu'nun ortası
const TO := Vector3(0, 0, 98) # köyün güney ucu


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var camera = main.get_node("Kamera")
	await create_timer(1.0).timeout
	var enemies := main.get_node("Dusmanlar").get_children()
	print("Düşman sayısı: %d, köyde (z > 60): %d" % [enemies.size(), enemies.filter(func(e): return e.global_position.z > 60).size()])
	var path := NavigationServer3D.map_get_path(player.get_world_3d().navigation_map, FROM, TO, true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	print("Yol: %d nokta, %.1f m, bitiş %s (hedef %s)" % [path.size(), length, path[-1] if path.size() > 0 else "yok", TO])
	var number := 1
	for spot in [[Vector3(0, 0, 62), 1.0], [Vector3(0, 0, 80), 0.6], [Vector3(0, 0, 97), 0.6]]:
		player.global_position = spot[0]
		camera.zoom = spot[1]
		camera.zoom_target = spot[1]
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir + "/koy-%d.png" % number)
		print("%s: %d kare/sn" % [spot[0], Engine.get_frames_per_second()])
		number += 1
	quit()
