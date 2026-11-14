# Can iksirini dener: oyuncunun canı tamken iksir alınmamalı; hasar alınca alınmalı ve 25 can vermeli.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/potion_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	var camera = main.get_node("Kamera")
	camera.zoom = 3.0
	camera.zoom_target = 3.0
	await create_timer(1.0).timeout
	var potion: Node3D = main.drop_potion(player.global_position + Vector3(-2.0, 0, 2.5))
	await create_timer(0.2).timeout
	await shot(out_dir, "iksir-1-sicrama")
	await create_timer(1.0).timeout
	await shot(out_dir, "iksir-2-yerde")
	print("İksir yerde: ", potion.global_position, ", oyuncuya uzaklık %.2f" % potion.global_position.distance_to(player.global_position))
	player.global_position = potion.global_position + Vector3(0.5, 0, 0)
	await create_timer(0.5).timeout
	print("Can tam (%d): iksir duruyor mu: %s" % [player.health, is_instance_valid(potion) and not potion.taken])
	player.take_damage(60)
	await create_timer(0.15).timeout
	await shot(out_dir, "iksir-3-aliniyor")
	await create_timer(0.8).timeout
	print("Hasardan sonra can: %d (beklenen 65), iksir silindi mi: %s" % [player.health, not is_instance_valid(potion)])
	await shot(out_dir, "iksir-4-alindi")
	# Düşme sıklığı: 200 ölümde kaç iksir
	var before := main.get_children().filter(func(n): return n.scene_file_path.ends_with("health_potion.tscn")).size()
	for i in 200:
		main.on_enemy_fell(Vector3(0, 0, 30))
	var after := main.get_children().filter(func(n): return n.scene_file_path.ends_with("health_potion.tscn")).size()
	print("200 ölümde düşen iksir: %d" % (after - before))
	quit()


func shot(out_dir: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s.png" % file_name)
