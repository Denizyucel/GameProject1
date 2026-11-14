# Harabe Köy'ü dener: Kül Yolu'ndan köydeki her düşmanın yerine navmesh'te yol var mı; oyuncu köyün
# yokuşunda zeminin yüksekliğine çıkıyor mu; köyün üç yerinden ekran görüntüsü alır.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/village_test.gd -- <klasör>

extends SceneTree

const FROM := Vector3(0, 0, 40) # Kül Yolu'nun ortası


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var camera = main.get_node("Kamera")
	await create_timer(1.0).timeout
	var enemies := main.get_node("Dusmanlar").get_children()
	var map: RID = player.get_world_3d().navigation_map
	var reachable := 0
	var in_village := 0
	for enemy in enemies:
		if enemy.global_position.z < 60:
			continue
		in_village += 1
		var path := NavigationServer3D.map_get_path(map, FROM, enemy.home, true)
		var end: Vector3 = path[-1] if path.size() > 0 else Vector3.INF
		var ok := Vector2(end.x - enemy.home.x, end.z - enemy.home.z).length() < 0.5
		reachable += 1 if ok else 0
		print("Düşman evi %s: yol %s, zemin yüksekliği %.2f m" % [enemy.home, "var" if ok else "YOK", Terrain.height_at(enemy.home)])
	print("Köydeki düşman: %d, ulaşılabilen: %d" % [in_village, reachable])
	for enemy in enemies:
		enemy.set_physics_process(false) # görüntü alırken dövüş başlamasın
	# Yokuş yukarı yürüyüş: meydandan batıdaki sokağa; varmalı ve zeminle birlikte yükselmeli
	player.global_position = Vector3(3, 0, 76)
	player.agent.target_position = Vector3(-9, 0, 76.5)
	var started := Time.get_ticks_msec()
	await physics_frame
	await physics_frame
	while not player.agent.is_navigation_finished() and Time.get_ticks_msec() - started < 15000:
		await physics_frame
	print("Yokuş: vardı mı %s, konum %s, modelin yüksekliği %.2f m, kamera odağı y %.2f" % [player.agent.is_navigation_finished(), player.global_position, player.model.position.y, camera.focus.y])
	# Zemine tıklama: yokuştaki bir noktanın ekrandaki yerinden geri ışın atınca aynı (x, z) bulunmalı
	var uphill := Vector3(-9, 0, 76.5)
	var on_screen: Vector2 = camera.unproject_position(Terrain.on_ground(uphill))
	var hit = Terrain.ray_to_ground(camera.project_ray_origin(on_screen), camera.project_ray_normal(on_screen))
	print("Tıklama: istenen %s, bulunan %s" % [uphill, hit])
	var number := 1
	for spot in [[Vector3(2, 0, 64), 1.0], [Vector3(3, 0, 76), 1.0], [Vector3(-9, 0, 76.5), 1.0], [Vector3(3, 0, 76), 0.6]]:
		player.global_position = spot[0]
		player.agent.target_position = spot[0]
		camera.zoom = spot[1]
		camera.zoom_target = spot[1]
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir + "/koy-%d.png" % number)
		print("%s: zemin %.2f m, modelin yüksekliği %.2f m, %d kare/sn" % [spot[0], Terrain.height_at(spot[0]), player.model.position.y, Engine.get_frames_per_second()])
		number += 1
	quit()
