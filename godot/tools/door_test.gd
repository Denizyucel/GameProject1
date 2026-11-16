# Gotik binanın kapısını ve iç mekânı dener: anahtarsız "kilitli"; anahtarla kapı açılıp içeri (kat 0) girilir;
# merdivenlerle kat 2'ye çıkılır, mektup alınınca not açılır (oyun durur), tıklayınca kapanır, görev biter, en fazla mana +20; kapıdan çıkınca dışarı.
# Görüntüler: ic-giris.png (içeri girince), kapi-not.png (mektup), ic-cikis.png (dışarı çıkınca).
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/door_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var door = main.get_node("Gezinme/GotikBina/Kapi")
	var inside = main.get_node("Gezinme/BinaIci")
	await create_timer(1.0).timeout
	for e in main.get_node("Dusmanlar").get_children():
		e.queue_free()

	# 1. Anahtarsız
	await go(player, Vector3(-24.5, 0, 40))
	await create_timer(0.4).timeout
	print("Anahtarsız: kilitli dedi mi %s, alt yazı '%s'" % [door.said_locked, main.hud.say_label.text])

	# 2. Anahtarla: uzaklaşıp geri gel → içeri girmeli
	await go(player, Vector3(-19, 0, 40))
	main.has_golden_key = true
	main.quests.start(main.DOOR_QUEST, main.DOOR_TITLE)
	var mana_before: float = player.max_mana
	await create_timer(0.3).timeout
	await go(player, Vector3(-24.5, 0, 40))
	await create_timer(3.0).timeout
	print("İçeri girdi mi: %s, konum %s, görev %s" % [inside.is_inside(player.global_position), player.global_position, main.quests.lines()])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/ic-giris.png")

	# 3. Merdivenlerle kat 2'ye çık (kat 0 → kat 1 → kat 2), mektuba yürü (gerçek yol bulmayla)
	for index in [1, 4]:
		var portal: Array = inside.PORTALS[index]
		player.agent.target_position = inside.floor_point(portal[0], portal[1])
		var waited_stairs := 0.0
		while inside.floor_point(portal[2], Vector2.ZERO).distance_to(Vector3(player.global_position.x, 0, player.global_position.z)) > 9.0 and waited_stairs < 15.0:
			await create_timer(0.25).timeout
			waited_stairs += 0.25
		await create_timer(1.2).timeout
		print("Merdiven %s → %s: %.1f sn" % [portal[0], portal[2], waited_stairs])
	var letter = inside.get_node_or_null("Mektup")
	print("Mektup: %s" % [letter.global_position if letter else "yok"])
	if letter:
		player.agent.target_position = letter.global_position
		var waited := 0.0
		while not main.hud.note_open and waited < 12.0:
			await create_timer(0.1, true).timeout
			waited += 0.1
		print("Mektuba vardı mı (not açık): %s, %.1f sn, oyuncu %s" % [main.hud.note_open, waited, player.global_position])
		await create_timer(0.6, true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir + "/kapi-not.png")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Vector2(640, 360)
		Input.parse_input_event(click)
		await create_timer(1.6, true).timeout
		print("Sonra: not açık mı %s, durdu mu %s, görev %s, en fazla mana %d → %d" % [main.hud.note_open, paused, main.quests.lines(), mana_before, player.max_mana])

	# 4. Kat 0'a dön (kısayol: doğrudan girişe), kapıya yürü: dışarı çıkmalı
	await inside.travel(inside.floor_point("Kat0", inside.ENTRY))
	await create_timer(0.3).timeout
	var exit_at: Vector3 = inside.floor_point("Kat0", inside.PORTALS[0][1])
	player.agent.target_position = exit_at
	var t := 0.0
	while inside.is_inside(player.global_position) and t < 12.0:
		await create_timer(0.2).timeout
		t += 0.2
	await create_timer(1.2).timeout
	print("Dışarı çıktı mı: %s, konum %s; kapı yeniden içeri aldı mı: %s" % [not inside.is_inside(player.global_position), player.global_position, inside.is_inside(player.global_position)])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/ic-cikis.png")
	# Mektuptan birkaç saniye sonra zincirin son görevi (mahzendeki rün halkası, kemik golemi) açılmış olmalı
	await create_timer(3.0).timeout
	print("Mektuptan sonra görevler: %s, alt yazı '%s'" % [main.quests.lines(), main.hud.say_label.text])
	quit()


func go(player: Node3D, at: Vector3) -> void:
	player.global_position = at
	player.agent.target_position = at
	await physics_frame
