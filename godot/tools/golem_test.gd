# Kemik golemini dener: hak kazanılmadan 2 tuşu çalışmaz; görev açıkken mahzendeki rün halkasına yürüyünce golem kalkar
# (görev biter, hak kazanılır); oyuncuyu takip eder; binadan çıkınca birlikte taşınır; düşmanla dövüşür (vurur, vurulur);
# canı bitince serbest kalır; 2 tuşuyla (50 mana) yeniden çağrılır; ayaktayken ya da mana yetmezken çağrılmaz.
# Görüntüler: golem-kalkis.png (halkada yükselirken), golem-halka.png, golem-disarida.png, golem-dovus.png, golem-cagri.png.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/golem_test.gd -- <klasör>

extends SceneTree

var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var ici = main.get_node("Gezinme/BinaIci")
	await create_timer(1.0).timeout
	var map: RID = player.get_world_3d().navigation_map
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await physics_frame
	for e in main.get_node("Dusmanlar").get_children():
		e.queue_free()

	# 1. Hak yokken 2 tuşu
	print("1. Hak yokken çağırma: %s (false olmalı), golem %s" % [main.summon_golem(), main.golem])

	# 2. Görev açık (mektup okunmuş gibi); mahzene in, halkaya yürü
	main.quests.start(main.GOLEM_QUEST, main.GOLEM_TITLE)
	await ici.travel(ici.floor_point("KatEksi1", Vector2(0.0, -2.2)))
	await create_timer(0.3).timeout
	print("2. Görevler: %s" % [main.quests.lines()])
	player.agent.target_position = ici.floor_point("KatEksi1", Vector2(4.5, 1.0))
	var waited := 0.0
	while not is_instance_valid(main.golem) and waited < 15.0:
		await create_timer(0.1).timeout
		waited += 0.1
	print("   Halkada golem kalktı mı: %s (%.1f sn), hak %s, görevler %s" % [is_instance_valid(main.golem), waited, main.has_golem, main.quests.lines()])
	if not is_instance_valid(main.golem):
		print("   TAKILDI: oyuncu %s" % player.global_position)
		quit()
		return
	var golem = main.golem
	await create_timer(0.7).timeout
	await shot("golem-kalkis.png")
	await create_timer(2.5).timeout
	var center: Vector3 = ici.floor_point("KatEksi1", ici.CIRCLE_AT)
	print("   Ayakta mı %s, can %d, halkanın ortasına %.2f m, oyuncuya %.2f m" % [golem.alive, golem.health, flat(golem.global_position, center), flat(golem.global_position, player.global_position)])
	await shot("golem-halka.png")

	# 3. Takip: merdiven koridoruna yürü
	player.agent.target_position = ici.floor_point("KatEksi1", Vector2(1.0, -0.8))
	await create_timer(4.0).timeout
	print("3. Takip: oyuncuya %.2f m (4 m'den az olmalı)" % flat(golem.global_position, player.global_position))

	# 4. Binadan çık: golem de taşınmalı
	await ici.travel(ici.OUTSIDE, true)
	await create_timer(0.5).timeout
	print("4. Dışarıda: oyuncu %s, golem içeride mi %s, oyuncuya %.2f m" % [player.global_position, ici.is_inside(golem.global_position), flat(golem.global_position, player.global_position)])
	player.agent.target_position = Vector3(-17, 0, 40)
	await create_timer(3.0).timeout
	GameCamera.active.zoom = 1.6
	GameCamera.active.zoom_target = 1.6
	await create_timer(0.3).timeout
	await shot("golem-disarida.png")
	GameCamera.active.zoom = 1.0
	GameCamera.active.zoom_target = 1.0

	# 5. Dövüş: yakına bir düşman
	var enemy = main.ENEMY.instantiate()
	var beyond: Vector3 = golem.global_position - player.global_position # golemin öte yanına: önce onu görsün
	enemy.position = golem.global_position + Vector3(beyond.x, 0, beyond.z).normalized() * 4.0
	main.enemies_root.add_child(enemy)
	enemy.seal_broken.connect(main.on_seal_broken)
	enemy.buried.connect(main.on_enemy_fell)
	await create_timer(0.2).timeout
	var enemy_health: float = enemy.health
	var enemy_name: String = enemy.style["name"]
	var golem_health: float = golem.health
	var fought := 0.0
	var shot_taken := false
	var foe_was_golem := false
	while is_instance_valid(enemy) and enemy.alive and fought < 25.0:
		await create_timer(0.1).timeout
		fought += 0.1
		if is_instance_valid(enemy) and enemy.foe == golem:
			foe_was_golem = true
		if not shot_taken and not golem.attack.is_empty() and golem.attack_time > 0.25:
			shot_taken = true
			await shot("golem-dovus.png")
	print("5. Dövüş: düşman (%s, %d can) %.1f sn'de %s; golemin canı %d → %d; düşman goleme saldırdı mı %s; oyuncunun canı %d" % [enemy_name, enemy_health, fought, "öldü" if not is_instance_valid(enemy) or not enemy.alive else "ÖLMEDİ", golem_health, golem.health, foe_was_golem, player.health])

	# 6. Golem ayaktayken çağırma: olmaz, mana gitmez
	await create_timer(3.0).timeout
	player.mana = player.max_mana
	print("6. Ayaktayken çağırma: %s (false olmalı), mana %d, alt yazı '%s'" % [main.summon_golem(), player.mana, main.hud.say_label.text])

	# 7. Golemin canı biter → serbest kalır; 2 tuşuyla yeniden çağır
	golem.take_damage(9999)
	await create_timer(0.3).timeout
	print("7. Canı bitince: golem %s" % ["yok" if not is_instance_valid(main.golem) else "HÂLÂ VAR"])
	var key := InputEventKey.new()
	key.physical_keycode = KEY_2
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.2).timeout
	print("   2 tuşu: büyü başladı mı %s, mana %d (50 azalmalı)" % [player.cast_progress() >= 0, player.mana])
	var summon_wait := 0.0
	while not is_instance_valid(main.golem) and summon_wait < 5.0:
		await create_timer(0.1).timeout
		summon_wait += 0.1
	print("   Golem yeniden kalktı mı: %s (%.1f sn)" % [is_instance_valid(main.golem), summon_wait])
	await create_timer(0.8).timeout
	GameCamera.active.zoom = 1.6
	GameCamera.active.zoom_target = 1.6
	await create_timer(0.2).timeout
	await shot("golem-cagri.png")
	await create_timer(2.0).timeout

	# 8. Mana yetmezken
	main.golem.take_damage(9999)
	await create_timer(0.3).timeout
	player.mana = 20.0
	print("8. Mana 20 iken çağırma: %s (false olmalı), golem %s" % [main.summon_golem(), "yok" if not is_instance_valid(main.golem) else "VAR"])
	quit()


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/" + file)
