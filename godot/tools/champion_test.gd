# Altın Şampiyon zincirini dener: şampiyon yerinde mi, oyuncu yaklaşınca görev açılıyor mu, mührü kırılınca görev
# bitip altın anahtar düşüyor mu, anahtar alınınca kapı görevi başlıyor mu. Görüntüler: sampiyon.png, anahtar.png
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/champion_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var camera := main.get_node("Kamera")
	camera.zoom = 1.6
	camera.zoom_target = 1.6
	await create_timer(1.0).timeout
	var champion = main.champion
	for e in main.get_node("Dusmanlar").get_children():
		if e != champion:
			e.queue_free()
	print("Şampiyon: %s, can %d, boy %.2f, konum %s" % [champion.style["name"], champion.health, champion.style["size"], champion.global_position])

	# 1. Uzaktayken görev yok; 10 m'ye gel
	print("Uzaktayken görev: ", main.quests.lines())
	player.global_position = champion.global_position + Vector3(7, 0, 7)
	player.agent.target_position = player.global_position
	await create_timer(0.6).timeout
	print("Yaklaşınca görev: ", main.quests.lines())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/sampiyon.png")

	# 2. Mührünü kır
	champion.hit(player.global_position, 9999)
	await create_timer(1.2).timeout
	var keys := main.get_children().filter(func(n): return n is GoldenKey)
	print("Kırılınca görev: %s, anahtar sayısı %d" % [main.quests.lines(), keys.size()])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/anahtar.png")

	# 3. Anahtarı al
	if keys.size() > 0:
		player.global_position = keys[0].global_position
		player.agent.target_position = player.global_position
		await create_timer(0.6).timeout
	print("Anahtar alındı mı: %s, görev: %s" % [main.has_golden_key, main.quests.lines()])
	quit()
