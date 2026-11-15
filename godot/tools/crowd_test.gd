# Hareketli çarpışmayı (characters/crowd.gd) dener: 4 iskelet kaldırır, yanlarına 2 düşman getirir, dövüş sürerken
# her karede en yakın iki karakterin arasını ölçer (iç içe girmemeli); sonra oyuncu iskeletlerin arasından
# yürür (yolu kapanmamalı). Ekran görüntüsü: kalabalik-dovus.png.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/crowd_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var camera := main.get_node("Kamera")
	camera.zoom = 2.0
	camera.zoom_target = 2.0
	var player = main.get_node("Player")
	await create_timer(0.5).timeout
	var enemies := main.get_node("Dusmanlar").get_children()
	for i in range(2, enemies.size()):
		enemies[i].queue_free()

	# 4 iskelet
	for i in 4:
		main.on_buried(player.global_position + Vector3(1.2, 0, -1.0 + i * 0.6))
		await physics_frame
		while not main.raise_dead():
			await physics_frame
		while player.cast_progress() >= 0:
			await physics_frame
	await create_timer(1.0).timeout

	# 2 düşman: oyuncunun 3 m önüne, aynı noktaya (üst üste başlasınlar)
	for i in 2:
		enemies[i].global_position = player.global_position + Vector3(2.5, 0, 2.5)
		enemies[i].home = enemies[i].global_position
		enemies[i].health = 200.0 # dövüş uzun sürsün
	var closest := INF
	var closest_pair := ""
	var overlap_frames := 0
	var frames := 0
	for k in 360: # ~6 sn
		await physics_frame
		var bodies: Array = [player]
		bodies.append_array(get_nodes_in_group("dusman"))
		for m in get_nodes_in_group("iskelet"):
			if m.alive:
				bodies.append(m)
		var frame_closest := INF
		for i in bodies.size():
			for j in range(i + 1, bodies.size()):
				var a: Vector3 = bodies[i].global_position
				var b: Vector3 = bodies[j].global_position
				var d := Vector2(a.x - b.x, a.z - b.z).length()
				frame_closest = minf(frame_closest, d)
				if d < closest:
					closest = d
					closest_pair = "%s - %s" % [bodies[i].name, bodies[j].name]
		frames += 1
		if frame_closest < 0.5:
			overlap_frames += 1
		if k == 180:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out_dir + "/kalabalik-dovus.png")
	print("Dövüşte en yakın iki karakter: %.2f m (%s); 0.5 m'den yakın kare: %d / %d" % [closest, closest_pair, overlap_frames, frames])
	print("Düşman canları: ", enemies[0].health if is_instance_valid(enemies[0]) else -1, ", ", enemies[1].health if is_instance_valid(enemies[1]) else -1)

	# Oyuncu iskeletlerin arasından geçsin
	for e in get_nodes_in_group("dusman"):
		e.queue_free()
	await create_timer(1.5).timeout
	var goal: Vector3 = player.global_position + Vector3(-4, 0, 0)
	player.agent.target_position = goal
	await create_timer(3.0).timeout
	print("Oyuncu iskeletlerin arasından yürüdü: hedefe uzaklık %.2f m" % Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length())
	quit()
