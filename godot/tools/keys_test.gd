# WASD yürümeyi deneyen yardımcı betik: tuşlara sahte olarak basıp bırakır, karakterin konumunu yazdırır.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/keys_test.gd -- <klasör>

extends SceneTree

# [tuş, kaç saniye basılı]: W yukarı, D sağ, sonra uzun süre S (güney duvarına kadar gidip durmalı)
const PRESSES := [[KEY_W, 1.0], [KEY_D, 1.0], [KEY_A, 1.0], [KEY_S, 6.0]]


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var player: Node3D = main.get_node("Player")
	for i in 30:
		await process_frame
	print("Başlangıç: ", player.global_position)
	for press in PRESSES:
		send_key(press[0], true)
		var moving := ""
		var steps := int(press[1] / 0.5)
		for step in steps:
			await create_timer(0.5).timeout
			if step == steps / 2:
				moving = player.animation_player.current_animation
			if press[1] > 2:
				print("   %.1f sn: %s tuş basılı=%s" % [(step + 1) * 0.5, player.global_position, Input.is_physical_key_pressed(press[0])])
		send_key(press[0], false)
		print("%s %.1f sn: konum %s, basılıyken animasyon %s" % [OS.get_keycode_string(press[0]), press[1], player.global_position, moving])
	await create_timer(0.5).timeout
	print("Bırakınca animasyon: ", player.animation_player.current_animation)
	root.get_texture().get_image().save_png(out_dir + "/tuslar.png")
	quit()


func send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
