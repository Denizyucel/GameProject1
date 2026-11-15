# Unutulan İsimler görevini dener: sayfalar yürünebilir yerde mi, oyuncu yanına gidince alınıyor mu, görev listesi
# ilerliyor mu, beşincide en fazla can artıyor mu. Ekran görüntüleri: isim-sayfa.png (alınmadan önce), isim-gorev.png
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/names_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	await create_timer(1.0).timeout
	for e in main.get_node("Dusmanlar").get_children():
		e.queue_free() # sayfa toplarken dövüş başlamasın
	var pages: Array = main.get_children().filter(func(n): return n is NamePage)
	print("Sayfa sayısı: ", pages.size())
	for i in pages.size():
		var spec: Dictionary = main.NAME_PAGES[i]
		var at: Vector3 = spec["at"]
		print("  %s: istenen %s, konan %s (kayma %.2f m), görünen zemin %.2f" % [spec["person"], at, pages[i].position, Vector2(at.x - pages[i].position.x, at.z - pages[i].position.z).length(), pages[i].floor_y])

	# Birinci sayfanın 2 m yanına gel, görüntü al (sayfa görünmeli), sonra üstüne yürü
	var first: Vector3 = pages[0].global_position
	player.global_position = first + Vector3(2.0, 0, 0)
	player.agent.target_position = player.global_position
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/isim-sayfa.png")

	var spots := pages.map(func(p): return p.global_position)
	for i in pages.size():
		var page = pages[i]
		var at: Vector3 = spots[i]
		player.global_position = at + Vector3(0.5, 0, 0)
		player.agent.target_position = player.global_position
		await create_timer(0.5).timeout
		print("Alındı mı: %s, görev: %s" % [not is_instance_valid(page) or page.taken, main.quests.lines()])
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/isim-gorev.png")
	print("Bitti mi: %s, en fazla can: %d, can: %d" % [main.quests.is_done("isimler"), player.max_health, player.health])
	quit()
