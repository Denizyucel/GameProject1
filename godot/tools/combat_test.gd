# Dövüşü deneyen yardımcı betik: bir düşmanı oyuncunun yanına getirir, düşmanın fark edip saldırmasını,
# oyuncunun canının azalmasını izler; sonra oyuncu düşmana kılıçla vurur, ta ki düşman ölene kadar.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/combat_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var camera := main.get_node("Kamera")
	camera.zoom = 2.2
	camera.zoom_target = 2.2
	var player = main.get_node("Player")
	for i in 40:
		await process_frame
	var enemies := main.get_node("Dusmanlar").get_children()
	for e in enemies:
		print("%s: tarz %s, can %d, konum %s" % [e.name, e.style["name"], e.health, e.global_position])

	# 1. Düşmanı oyuncunun 3.5 m önüne getir: fark edip yaklaşmalı ve vurmalı
	var enemy = enemies[0]
	enemy.global_position = player.global_position + Vector3(2.5, 0, 2.5)
	enemy.home = enemy.global_position
	await create_timer(2.5).timeout
	print("2.5 sn sonra: oyuncu canı %d, düşman uzaklığı %.2f, düşman animasyonu %s" % [
		player.health, enemy.ground_distance(player.global_position), enemy.animation_player.current_animation])
	await save(out_dir + "/1-saldiri.png")

	# 2. Oyuncu düşmana dönüp vursun, ölene kadar
	var swings := 0
	while is_instance_valid(enemy) and enemy.alive and swings < 12 and player.alive:
		player.start_attack(enemy.global_position)
		swings += 1
		if swings == 1:
			# Darbe anı: kıvılcım ve donma (hit stop) görünmeli
			while not player.attack_has_hit:
				await process_frame
			print("Darbe anında oyun hızı (Engine.time_scale): %.2f" % Engine.time_scale)
			await save(out_dir + "/1b-kivilcim.png")
			await create_timer(0.3, true, false, true).timeout
			print("0.3 sn (gerçek) sonra oyun hızı: %.2f" % Engine.time_scale)
		while not player.attack.is_empty():
			await physics_frame
		print("Vuruş %d: düşman canı %d" % [swings, enemy.health if is_instance_valid(enemy) else -1])
	await create_timer(0.8).timeout
	await save(out_dir + "/2-olum.png")
	print("Düşman yaşıyor mu: ", enemy.alive, ", oyuncu canı: ", player.health, ", oyuncu yaşıyor: ", player.alive)
	await create_timer(5.0).timeout
	print("5 sn sonra düşman sahnede mi: ", is_instance_valid(enemy), ", kalan düşman: ", get_nodes_in_group("dusman").size())
	quit()


func save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
