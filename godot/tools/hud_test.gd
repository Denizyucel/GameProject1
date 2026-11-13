# Can küresini deneyen yardımcı betik: tam can, hasar anı (parlama + kayıp can), indikten sonra ve
# fare üstündeyken (sayı) ekran görüntüleri alır.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/hud_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	for i in 40:
		await process_frame
	await save(out_dir + "/hud1-tam.png")

	player.take_damage(40)
	await create_timer(0.12).timeout
	await save(out_dir + "/hud2-darbe.png")
	await create_timer(1.5).timeout
	await save(out_dir + "/hud3-indi.png")

	# Fareyi kürenin ortasına getir: can sayısı görünmeli
	var globe: Control = main.get_node("HUD/CanKuresi")
	var motion := InputEventMouseMotion.new()
	motion.position = globe.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await create_timer(0.3).timeout
	await save(out_dir + "/hud4-sayi.png")
	print("Can: ", player.health, " / ", player.max_health, ", küre alanı: ", globe.get_global_rect())
	print("HUD oyuncusu: ", main.get_node("HUD").player, ", sinyal bağlı: ", player.health_changed.get_connections().size())
	print("Sıvı fill: ", globe.get_node("Sivi").material.get_shader_parameter("fill"),
		", kayıp fill: ", globe.get_node("KayipCan").material.get_shader_parameter("fill"),
		", sayı görünür: ", globe.get_node("Sayi").visible, ", sayı: ", globe.get_node("Sayi").text)
	quit()


func save(path: String) -> void:
	await RenderingServer.frame_post_draw # o karenin çizimi bitsin, yoksa eski kare kaydedilebilir
	root.get_texture().get_image().save_png(path)
