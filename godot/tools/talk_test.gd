# Saklanan Anne'yle konuşmayı dener (quests/hidden_mother.gd, HUD.talk): başında "!" işareti var; oyuncu yanına yürüyünce
# konuşma kutusu açılır ve oyun durur; tık önce sözü tamamlar, sonra sıradakine geçer; son sözden sonra kutu kapanır,
# oyun sürer, görev açılır, işaret kalkar. Uzaklaşıp geri gelince kutu açılmaz, kadın kısa sözünü yineler.
# Esc konuşmanın tamamını geçer. Görüntüler: konusma-isaret.png, konusma-1.png (kadın), konusma-2.png (Ruh Kıran),
# konusma-son.png (görev açılmış).
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/talk_test.gd -- <klasör>

extends SceneTree

var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	await create_timer(1.0).timeout
	var mother = main.get_node("Anne")
	var quest = main.get_node("SaklananAnne")
	var hud = main.hud
	var map: RID = player.get_world_3d().navigation_map
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await physics_frame
	for e in main.get_node("Dusmanlar").get_children():
		e.queue_free()

	# 1. Uzaktan: işaret görünür, kutu kapalı
	player.global_position = mother.global_position + Vector3(6, 0, 1)
	player.agent.target_position = player.global_position
	await create_timer(0.8).timeout
	print("1. Başta: işaret %s (true olmalı), kutu açık mı %s, görevler %s" % [mother.marker != null and mother.marker.visible, hud.talk_open, main.quests.lines()])
	await shot("konusma-isaret.png")

	# 2. Yanına yürü: konuşma açılmalı, oyun durmalı
	player.agent.target_position = mother.global_position
	var waited := 0.0
	while not hud.talk_open and waited < 8.0:
		await create_timer(0.1, true).timeout
		waited += 0.1
	await create_timer(0.3, true).timeout
	var gap := Vector2(player.global_position.x - mother.global_position.x, player.global_position.z - mother.global_position.z)
	print("2. Kutu açıldı mı %s (%.1f sn), oyun durdu mu %s, kadına %.2f m, söz %d / %d: %s: «%s»" % [hud.talk_open, waited, paused, gap.length(), hud.talk_index + 1, hud.talk_lines.size(), hud.talk_name.text, hud.talk_text.text])
	var facing := Vector2(sin(player.rotation.y), cos(player.rotation.y))
	print("   Ruh Kıran kadına dönük mü %s; yazı henüz tamam mı %s (false olmalı: harf harf yazılıyor)" % [facing.angle_to(-gap.normalized()) < 0.2 and facing.angle_to(-gap.normalized()) > -0.2, hud.talk_text.visible_ratio >= 1.0])
	# Beklerken animasyon sürüyor mu: kadının bir kemiği iki an arasında oynamalı
	var bone: int = mother.skeleton.find_bone("mixamorig_Spine2")
	var pose_a: Quaternion = mother.skeleton.get_bone_pose_rotation(bone)
	await create_timer(0.8, true).timeout
	print("   Oyun durmuşken kadın nefes alıyor mu (animasyon sürüyor): %s" % [not pose_a.is_equal_approx(mother.skeleton.get_bone_pose_rotation(bone))])

	# 3. Tık: önce yazıyı tamamlar (aynı söz), sonra sıradaki
	await create_timer(1.5, true).timeout # ilk söz kendiliğinden tamamlansın
	await shot("konusma-1.png")
	await click()
	print("3. Tık (yazı tamamken): söz %d, konuşan %s" % [hud.talk_index + 1, hud.talk_name.text])
	await click() # ikinci söz daha yazılırken: tamamlar
	print("   Tık (yazılırken): söz %d (hâlâ 2 olmalı), yazı tamam mı %s" % [hud.talk_index + 1, hud.talk_text.visible_ratio >= 1.0])
	await shot("konusma-2.png")
	var clicks := 0
	while hud.talk_open and clicks < 40:
		await click()
		clicks += 1
	await create_timer(0.5, true).timeout
	print("   Kalan sözler %d tıkla bitti; kutu açık mı %s, oyun durdu mu %s" % [clicks, hud.talk_open, paused])
	await create_timer(0.3).timeout
	print("   Görevler %s, işaret %s (false olmalı), beceri simgeleri geri geldi mi %s" % [main.quests.lines(), mother.marker.visible, hud.get_node("Beceriler").modulate.a > 0.9])
	await shot("konusma-son.png")

	# 4. Uzaklaş, geri gel: kutu açılmaz, kısa söz
	player.agent.target_position = mother.global_position + Vector3(7, 0, 1)
	await create_timer(3.5).timeout
	player.agent.target_position = mother.global_position
	await create_timer(3.5).timeout
	print("4. Yeniden gelince: kutu açık mı %s (false olmalı), alt yazı '%s'" % [hud.talk_open, hud.say_label.text])

	# 5. Esc: konuşmayı baştan açıp tek tuşla geç
	quest.talked = false
	quest.near = false
	player.global_position = mother.global_position + Vector3(6, 0, 1)
	player.agent.target_position = mother.global_position
	waited = 0.0
	while not hud.talk_open and waited < 8.0:
		await create_timer(0.1, true).timeout
		waited += 0.1
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.6, true).timeout
	print("5. Esc: kutu açıldı (%.1f sn), Esc'ten sonra açık mı %s (false olmalı), oyun durdu mu %s (false olmalı)" % [waited, hud.talk_open, paused])
	quit()


func click() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(640, 300)
	Input.parse_input_event(press)
	await create_timer(0.15, true).timeout


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/" + file)
