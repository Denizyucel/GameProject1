# Düşman can barını (hud/enemy_bar.gd) dener: fare düşmanın üzerine gelince bar görünmeli; oyuncu vurdukça bar
# azalmalı; düşman ölünce bar boşalıp sönmeli. Ekran görüntüleri: bar-1-uzerinde.png, bar-2-vurulmus.png, bar-3-olum.png
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/enemy_bar_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var bar = main.get_node("HUD/DusmanCani")
	var camera: Camera3D = main.get_node("Kamera")
	await create_timer(1.0).timeout
	var enemy = main.get_node("Dusmanlar").get_child(0)
	enemy.global_position = player.global_position + Vector3(1.2, 0, 1.2)
	enemy.home = enemy.global_position
	await create_timer(0.5).timeout

	# 1. Fare düşmanın göğsünün üzerinde
	var chest := camera.unproject_position(Terrain.on_ground(enemy.global_position) + Vector3.UP * 1.0)
	Input.warp_mouse(chest)
	await create_timer(0.4).timeout
	await save(out_dir + "/bar-1-uzerinde.png")
	print("Fare üzerinde: gösterilen %s, görünürlük %.2f, ad '%s'" % [bar.shown == enemy, bar.modulate.a, bar.name_label.text])

	# 2. Fareyi uzağa götür, oyuncu vursun
	Input.warp_mouse(Vector2(100, 600))
	player.start_attack(enemy.global_position)
	while not player.attack_has_hit:
		await process_frame
	await create_timer(0.15).timeout
	await save(out_dir + "/bar-2-vurulmus.png")
	print("Vurulunca: gösterilen %s, dolu %.2f, kayıp %.2f (can %d / %d)" % [bar.shown == enemy, bar.fill, bar.lost, enemy.health, enemy.style["health"]])

	# 3. Öldür
	enemy.hit(player.global_position, 999)
	await create_timer(0.3).timeout
	await save(out_dir + "/bar-3-olum.png")
	print("Ölünce: dolu %.2f, görünürlük %.2f" % [bar.fill, bar.modulate.a])
	await create_timer(1.5).timeout
	print("1.5 sn sonra görünürlük %.2f" % bar.modulate.a)
	quit()


func save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
