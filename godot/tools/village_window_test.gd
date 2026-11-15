# Harabe Köy'ün görüş penceresini dener: karakteri köyde evlerin arkasında kalabilecek yerlere koyar, her yerde
# pencere kapalı ve açık iki ekran görüntüsü alır (koy-pencere-N-kapali.png / -acik.png).
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/village_window_test.gd -- <klasör>

extends SceneTree

const SPOTS := [Vector3(3, 0, 76), Vector3(-4, 0, 74), Vector3(6, 0, 80), Vector3(-9, 0, 76.5), Vector3(0, 0, 86)]


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var village = main.get_node("Koy")
	await create_timer(1.0).timeout
	for enemy in main.get_node("Dusmanlar").get_children():
		enemy.queue_free() # görüntü alırken dövüş başlamasın
	var number := 1
	for spot in SPOTS:
		player.global_position = spot
		player.agent.target_position = spot
		for open in [false, true]:
			village.set_process(open)
			if not open:
				village.material.set_shader_parameter("hole_strength", 0.0)
			village.strength = 0.0
			await create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out_dir + "/koy-pencere-%d-%s.png" % [number, "acik" if open else "kapali"])
		print("%s: pencere gücü %.2f" % [spot, village.strength])
		number += 1
	quit()
