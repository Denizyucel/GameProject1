# Düşmana tıklayarak dövüşü deneyen yardımcı betik: bir düşmanı birkaç metre öteye koyar, ekranda onun
# üstüne GERÇEK bir sol tık gönderir ve başka hiçbir şey yapmadan karakterin kovalayıp öldürmesini izler.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/click_fight_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	for i in 40:
		await process_frame
	var enemy = main.get_node("Dusmanlar").get_child(2)
	enemy.global_position = player.global_position + Vector3(4.5, 0, 3.0)
	enemy.home = enemy.global_position
	for i in 10:
		await physics_frame

	# Düşmanın göğsünün ekrandaki yerine tıkla
	var camera: Camera3D = main.get_node("Kamera")
	var at := camera.unproject_position(enemy.global_position + Vector3.UP * 1.2)
	print("Düşman (%s, can %d) uzaklık %.1f m; tık ekranda %s" % [enemy.style["name"], enemy.health, player.ground_distance(enemy.global_position), at])
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
	await physics_frame
	await physics_frame
	print("Seçilen hedef: ", player.attack_target.name if player.attack_target else "yok")

	var shot := false
	var elapsed := 0.0
	while elapsed < 20.0 and is_instance_valid(enemy) and enemy.alive:
		await physics_frame
		elapsed += 1.0 / 60.0
		if not shot and not player.attack.is_empty():
			shot = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out_dir + "/tik-vurus.png")
			print("Vurmaya başladı: %.1f sn, uzaklık %.1f m" % [elapsed, player.ground_distance(enemy.global_position)])
	print("Sonuç: düşman %s (%.1f sn), oyuncu canı %d, kovalama bitti mi %s" % [
		"öldü" if not enemy.alive else "yaşıyor", elapsed, player.health, player.attack_target == null])
	quit()
