# Fare basılı tutunca sürekli yürümeyi ve tıklama halkasını dener: zemine basar (halka çıkmalı), fareyi basılı tutup
# başka yere götürür (karakter farenin peşinden gitmeli), bırakır (son hedefte durmalı).
# Ekran görüntüsü: halka.png. Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/hold_walk_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var camera: Camera3D = main.get_node("Kamera")
	await create_timer(1.0).timeout
	var start: Vector3 = player.global_position

	# 1. Oyuncunun 3 m sağ-önüne bas: halka çıkmalı, yürümeye başlamalı
	var first := camera.unproject_position(start + Vector3(2.5, 0, -1.5))
	mouse(first, true)
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/halka.png")
	var rings := main.get_children().filter(func(n): return n is ClickRing).size()
	print("Halka sayısı: %d, basılı mı: %s" % [rings, player.holding])

	# 2. Basılı tutarken fareyi sola kaydır: karakter farenin peşinden dönmeli
	var goal := start + Vector3(-4, 0, -3)
	for i in 20:
		await create_timer(0.1).timeout
		var target := camera.unproject_position(goal) # kamera karakteri izliyor: hedefin ekrandaki yeri değişir
		Input.warp_mouse(target)
		var motion := InputEventMouseMotion.new()
		motion.position = target
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
	var reached := Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length()
	print("Basılı tutarken hedefe uzaklık: %.2f m (başlangıçta %.2f m)" % [reached, Vector2(start.x - goal.x, start.z - goal.z).length()])

	# 3. Bırak: holding false, karakter durmalı
	mouse(camera.unproject_position(goal), false)
	await create_timer(1.0).timeout
	print("Bıraktıktan sonra: basılı mı %s, yürüyor mu %s, hedefe uzaklık %.2f m" % [player.holding, player.walking, Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length()])
	quit()


func mouse(at: Vector2, pressed: bool) -> void:
	Input.warp_mouse(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
