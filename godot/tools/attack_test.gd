# Kılıç vuruşlarını deneyen yardımcı betik: farklı yönlere 4 kez Shift + sol tık gönderir, her vuruşun
# ortasında ekran görüntüsü alır ve oynayan animasyonu yazdırır.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/attack_test.gd -- <klasör>

extends SceneTree

const CLICKS := [Vector2(900, 360), Vector2(380, 360), Vector2(640, 600), Vector2(640, 150)]


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var camera := main.get_node("Kamera")
	camera.zoom = 3.0
	camera.zoom_target = 3.0
	var player: Node3D = main.get_node("Player")
	for i in 30:
		await process_frame
	print("Yüklenen vuruşlar: ", player.attack_names)

	for i in CLICKS.size():
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.shift_pressed = true
			click.position = CLICKS[i]
			click.global_position = CLICKS[i]
			Input.parse_input_event(click)
		await physics_frame
		await physics_frame
		var total: float = player.attack_time_left
		print("Tık %d: %s, süre %.2f sn, konum %s" % [i + 1, player.animation_player.current_animation, total, player.global_position])
		await create_timer(total * 0.45).timeout
		root.get_texture().get_image().save_png(out_dir + "/vurus%d.png" % (i + 1))
		await create_timer(total * 0.55 + 0.3).timeout
		print("   bitince: ", player.animation_player.current_animation)
	quit()
