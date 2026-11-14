# Kütüphaneden Kül Yolu'na yürüyerek geçişi dener (harita tek parça): oyuncu kütüphanenin güneyinden
# Kül Yolu'nun kemerinin içine tıklanmış gibi yürür; yol bulunmalı ve oraya varmalı.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/level_test.gd -- <klasör>

extends SceneTree

const FROM := Vector3(0, 0, 12) # kütüphanenin güney kapısının dışı
const TO := Vector3(0, 0, 27) # Kül Yolu'nun kemerinin içi

var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	await create_timer(1.0).timeout
	print("Düşmanlar: ", main.get_node("Dusmanlar").get_children().map(func(e): return e.global_position))
	player.global_position = FROM
	player.agent.target_position = TO
	await create_timer(1.5).timeout
	await shot("10-gecis")
	var started := Time.get_ticks_msec()
	while not player.agent.is_navigation_finished() and Time.get_ticks_msec() - started < 10000:
		await physics_frame
	print("Vardı mı: %s, oyuncu %s (hedef %s)" % [player.agent.is_navigation_finished(), player.global_position, TO])
	await shot("11-kul-yolu")
	main.get_node("Kamera").zoom_target = 0.4
	main.get_node("Kamera").zoom = 0.4
	await create_timer(0.3).timeout
	await shot("12-harita")
	quit()


func shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s.png" % file_name)
