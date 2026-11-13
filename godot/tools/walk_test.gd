# Tıklayarak yürümeyi deneyen yardımcı betik: ekrana bir sol tık gönderir, karakterin yürüyüşünü
# izler ve iki ekran görüntüsü alır (yürürken ve vardıktan sonra).
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/walk_test.gd -- <klasör> <tık x> <tık y>

extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var click_at := Vector2(float(args[1]), float(args[2]))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var player: Node3D = main.get_node("Player")
	for i in 30:
		await process_frame
	print("Başlangıç: ", player.global_position)

	# Gerçek bir fare tıklaması gibi: basma ve bırakma olayları
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = click_at
		click.global_position = click_at
		Input.parse_input_event(click)
	await physics_frame
	await physics_frame
	var agent: NavigationAgent3D = player.get_node("NavigationAgent3D")
	print("Hedef: ", agent.target_position)
	var map := agent.get_navigation_map()
	print("Harita: bölge sayısı=", NavigationServer3D.map_get_regions(map).size(),
		" hücre=", NavigationServer3D.map_get_cell_size(map), "/", NavigationServer3D.map_get_cell_height(map),
		" iterasyon=", NavigationServer3D.map_get_iteration_id(map))
	print("En yakın nokta (başlangıç): ", NavigationServer3D.map_get_closest_point(map, player.global_position))
	print("Yol: ", agent.get_current_navigation_path(), " sıradaki: ", agent.get_next_path_position())

	await create_timer(1.2).timeout
	print("1.2 sn sonra: ", player.global_position, " animasyon: ", player.animation_player.current_animation)
	root.get_texture().get_image().save_png(out_dir + "/walk1.png")
	await create_timer(6.0).timeout
	print("7.2 sn sonra: ", player.global_position, " animasyon: ", player.animation_player.current_animation,
		" vardı: ", agent.is_navigation_finished())
	root.get_texture().get_image().save_png(out_dir + "/walk2.png")
	quit()
