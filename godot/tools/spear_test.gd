# Kemik mızrağını deneyen yardımcı betik: aynı hizada iki düşman koyar, ilkinin üstüne GERÇEK bir sağ tık
# gönderir; mızrağın ikisini de delip geçtiğini, uçarken görüntüsünü ve duvara çarpınca kırıldığını dener.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/spear_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var camera: Camera3D = main.get_node("Kamera")
	camera.zoom = 1.6
	camera.zoom_target = 1.6
	var player = main.get_node("Player")
	for i in 40:
		await process_frame

	# İki düşman: oyuncunun 4 m ve 7 m güneydoğusunda, aynı çizgide; kıpırdamasınlar diye çok uzaktan getiriyoruz
	var enemies := main.get_node("Dusmanlar").get_children()
	var direction := Vector3(1, 0, 1).normalized()
	var near_enemy = enemies[0]
	var far_enemy = enemies[1]
	near_enemy.global_position = player.global_position + direction * 4.0
	far_enemy.global_position = player.global_position + direction * 7.0
	for e in [near_enemy, far_enemy]:
		e.home = e.global_position
		e.set_physics_process(false) # deneme boyunca yerinde dursunlar
	await physics_frame
	var health_before := [near_enemy.health, far_enemy.health]

	right_click(camera.unproject_position(near_enemy.global_position + Vector3.UP * 1.2))
	await physics_frame
	await physics_frame
	print("Mızrak büyüsü başladı mı: ", not player.spear.is_empty(), " (", player.spear.get("name", "-"), ")")
	var spear: Node3D = null
	while spear == null:
		await physics_frame
		for child in main.get_children():
			if child.name.begins_with("KemikMizragi"):
				spear = child
	print("Mızrak fırladı: ", spear.global_position)
	while is_instance_valid(spear) and spear.travelled < 3.0:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/mizrak-ucus.png")
	while is_instance_valid(spear) and not spear.broken:
		await physics_frame
	print("Yakın düşman canı %d → %d, uzak düşman canı %d → %d" % [health_before[0], near_enemy.health, health_before[1], far_enemy.health])

	# Duvar: kuzeye (ekranın sol üstü) at, 14 m'den önce kırılmalı
	await create_timer(1.0).timeout
	player.start_spear(player.global_position + Vector3(0, 0, -10))
	spear = null
	while spear == null:
		await physics_frame
		for child in main.get_children():
			if child.name.begins_with("KemikMizragi") and not child.broken:
				spear = child
	while is_instance_valid(spear) and not spear.broken:
		await physics_frame
	print("Kuzeye atılan mızrak %.1f m uçup kırıldı (duvar oyuncudan ~3 m ötede)" % spear.travelled)
	quit()


func right_click(at: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
