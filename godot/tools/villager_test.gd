# Harabe Köy'deki köylüyü (saklanan anne, npcs/villager.gd) dener: köyün girişinden ona yol var mı, en yakın düşman ne
# kadar uzakta, oyuncu yaklaşınca ona dönüyor mu, içinden geçilmiyor mu. Görüntüler: anne-uzak.png, anne-yakin.png, anne-yakin-zoom.png.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/villager_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	await create_timer(1.0).timeout
	var mother = main.get_node("Anne")
	var map: RID = player.get_world_3d().navigation_map
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await physics_frame
	# Köyün girişinden yol
	var path := NavigationServer3D.map_get_path(map, Vector3(3, 0.25, 64), mother.global_position, true)
	var end: Vector3 = path[path.size() - 1] if path.size() > 0 else Vector3.ZERO
	print("Girişten anneye yol: %d nokta, sonu anneye %.2f m" % [path.size(), Vector2(end.x - mother.global_position.x, end.z - mother.global_position.z).length()])
	var nearest := INF
	for e in main.get_node("Dusmanlar").get_children():
		nearest = minf(nearest, Vector2(e.global_position.x - mother.global_position.x, e.global_position.z - mother.global_position.z).length())
	print("En yakın düşman: %.1f m" % nearest)
	print("Anne başta yönü: %.0f°" % rad_to_deg(mother.rotation.y))

	# Oyuncu 6 m doğuda, yolda (anne ona dönmez), sonra yanına yürür
	player.global_position = mother.global_position + Vector3(6, 0, 0)
	player.agent.target_position = player.global_position
	await create_timer(0.8).timeout
	await shot(out_dir + "/anne-uzak.png")
	player.agent.target_position = mother.global_position # içine yürümeye çalışır: kalabalık itmeli
	await create_timer(3.0).timeout
	var gap := Vector2(player.global_position.x - mother.global_position.x, player.global_position.z - mother.global_position.z)
	var facing := Vector2(sin(mother.rotation.y), cos(mother.rotation.y))
	print("Oyuncu anneye %.2f m (içinden geçmemeli, >= 0.7), anne konumu %s (yerinden oynamamalı)" % [gap.length(), mother.global_position])
	print("Anne oyuncuya dönük mü: %s (açı farkı %.0f°)" % [facing.angle_to(gap.normalized()) < 0.35, rad_to_deg(absf(facing.angle_to(gap.normalized())))])
	await shot(out_dir + "/anne-yakin.png")
	# Yakın plan: oyuncu 2 m geri çekilir, kamera en yakına
	player.agent.target_position = mother.global_position + Vector3(2.0, 0, 0.4)
	GameCamera.active.zoom = 2.6
	GameCamera.active.zoom_target = 2.6
	await create_timer(1.5).timeout
	await shot(out_dir + "/anne-yakin-zoom.png")
	quit()


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
