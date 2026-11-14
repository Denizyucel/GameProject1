# Ceset ve iskelet kaldırmayı deneyen yardımcı betik: düşman öldürür, cesedi bekler, 1 tuşuna basar,
# iskeletin kalkıp düşmana saldırmasını izler, sonra 5 iskelet sınırını dener.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/minion_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var camera := main.get_node("Kamera")
	camera.zoom = 2.0
	camera.zoom_target = 2.0
	var player = main.get_node("Player")
	for i in 40:
		await process_frame
	var enemies := main.get_node("Dusmanlar").get_children()

	# 1. Bir düşmanı öldür, gömülüp ceset bırakmasını bekle
	var first = enemies[0]
	first.global_position = player.global_position + Vector3(2.0, 0, 1.0)
	first.home = first.global_position
	await physics_frame
	first.hit(player.global_position, 999)
	while get_nodes_in_group("ceset").is_empty():
		await physics_frame
	print("Ceset belirdi: ", get_first_node_in_group("ceset").global_position)

	# 2. 1 tuşuna bas
	send_key(KEY_1)
	await physics_frame
	print("Büyü başladı mı: ", player.cast_progress() >= 0, ", animasyon: ", player.animation_player.current_animation)
	while player.cast_progress() >= 0 and player.cast_progress() < 0.35:
		await physics_frame
	await save(out_dir + "/1-buyu.png")
	while main.minions.is_empty():
		await physics_frame
	var minion = main.minions[0]
	await create_timer(0.45).timeout
	await save(out_dir + "/2-kalkis.png")
	await create_timer(1.0).timeout
	await save(out_dir + "/3-iskelet.png")
	print("İskelet: konum %s, HUD '%s'" % [minion.global_position, main.get_node("HUD/ManaKuresi/Rozet").text])

	# 3. Bir düşmanı iskeletin yakınına getir: iskelet saldırmalı
	var second = enemies[1]
	second.global_position = player.global_position + Vector3(-3.0, 0, 1.5)
	second.home = second.global_position
	var start_health: float = second.health
	await create_timer(4.0).timeout
	await save(out_dir + "/4-dovus.png")
	print("İskeletin hedefi: %s, düşman canı %d → %d" % [minion.target.name if minion.target else "yok", start_health, second.health if is_instance_valid(second) else -1])

	# 4. 5 iskelet sınırı: ceset ekleyip arka arkaya kaldır
	for i in 5:
		main.on_buried(player.global_position + Vector3(1.5, 0, -1.0 + i * 0.5))
		await physics_frame
		while not main.raise_dead():
			await physics_frame
		while player.cast_progress() >= 0:
			await physics_frame
		print("Kaldırma %d: iskelet sayısı %d, HUD '%s'" % [i + 2, main.minions.size(), main.get_node("HUD/ManaKuresi/Rozet").text])
	await save(out_dir + "/5-bes.png")
	quit()


func send_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


func save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
