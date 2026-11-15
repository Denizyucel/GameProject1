# Gotik binanın görüş penceresini dener: karakteri binanın arkasında kalabilecek yerlere koyar, her yerde
# pencere kapalı ve açık iki ekran görüntüsü alır (bina-pencere-N-kapali.png / -acik.png).
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/building_window_test.gd -- <klasör>

extends SceneTree

const SPOTS := [Vector3(-32, 0, 27), Vector3(-45, 0, 40), Vector3(-42, 0, 29), Vector3(-26, 0, 34)]


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var building = main.get_node("Gezinme/GotikBina")
	await create_timer(1.0).timeout
	for enemy in main.get_node("Dusmanlar").get_children():
		enemy.queue_free() # görüntü alırken dövüş başlamasın
	var number := 1
	for spot in SPOTS:
		player.global_position = spot
		player.agent.target_position = spot
		for open in [false, true]:
			building.set_process(open)
			if not open:
				for material in building.materials: material.set_shader_parameter("hole_strength", 0.0)
			building.strength = 0.0
			await create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out_dir + "/bina-pencere-%d-%s.png" % [number, "acik" if open else "kapali"])
		print("%s: pencere gücü %.2f" % [spot, building.strength])
		number += 1
	quit()
