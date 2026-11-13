# Mühür kırma anını deneyen yardımcı betik: bir düşmanı oyuncunun yanına getirip tek darbede öldürür,
# efektin kendi saatine göre farklı anlarında ekran görüntüsü alır (ekran görüntüsü almak oyunu bir an
# dondurduğu için duvar saatine göre beklemek yanıltır).
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/seal_test.gd -- <klasör>

extends SceneTree

const MOMENTS := [0.1, 0.35, 0.9, 1.6, 2.4]


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var camera := main.get_node("Kamera")
	camera.zoom = 2.0
	camera.zoom_target = 2.0
	var player = main.get_node("Player")
	for i in 40:
		await process_frame
	var enemy = main.get_node("Dusmanlar").get_child(0)
	enemy.global_position = player.global_position + Vector3(2.5, 0, 0.5)
	enemy.home = enemy.global_position
	await create_timer(0.3).timeout
	enemy.hit(player.global_position, 999)
	await process_frame
	var fx = main.get_children().filter(func(n): return n.name.begins_with("MuhurKirilmasi"))[0]
	var started := Time.get_ticks_msec()
	for moment in MOMENTS:
		while fx.time < moment:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir + "/muhur-%.2f.png" % moment)
	print("Fısıltı: '", main.get_node("HUD/Fisilti").text, "'")
	# Efekt 3.2 sn'de kendini silmeli
	while is_instance_valid(fx):
		await process_frame
	print("Efekt silindi; ilk görüntüden beri geçen gerçek süre %.1f sn (görüntü alma süreleri dahil)" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()
