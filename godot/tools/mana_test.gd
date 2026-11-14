# Mana ve yenilenme denemesi: mızrak ve iskelet kaldırma mana harcar, mana yetmeyince büyü başlamaz ve
# "Manam yetmiyor" çıkar; mana kendiliğinden dolar; can son hasardan 5 sn sonra dolmaya başlar.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/mana_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	var hud = main.get_node("HUD")
	for i in 40:
		await process_frame
	print("Başta: mana %.0f / %.0f, küre sayısı %s" % [player.mana, player.max_mana, hud.get_node("ManaKuresi/Sayi").text])
	var ahead: Vector3 = player.global_position + Vector3(0, 0, -5)
	print("Mızrak atıldı mı: %s, mana %.1f" % [player.start_spear(ahead), player.mana])
	while player.is_busy():
		await process_frame
	# Manayı bitir: mızrak yetmemeli
	player.mana = 5.0
	player.spear_ready_at = 0.0
	print("Mana 5'ken mızrak atıldı mı: %s, mana %.1f, söz: '%s'" % [player.start_spear(ahead), player.mana, hud.get_node("Konusma").text])
	# İskelet kaldırma: ceset koy, mana yetmezken ve yeterken dene
	main.on_buried(player.global_position + Vector3(2, 0, 0))
	await process_frame
	print("Mana 5'ken kaldırma başladı mı: %s" % main.raise_dead())
	player.mana = 30.0
	print("Mana 30'ken kaldırma başladı mı: %s, mana %.1f" % [main.raise_dead(), player.mana])
	while player.is_busy():
		await process_frame
	await create_timer(1.0).timeout
	print("İskelet sayısı: %d" % main.minions.size())
	# Yenilenme
	var before: float = player.mana
	await create_timer(2.0).timeout
	print("2 sn'de mana %.1f → %.1f (beklenen ~+10)" % [before, player.mana])
	player.take_damage(30)
	var hurt: float = player.health
	await create_timer(3.0).timeout
	print("Hasardan 3 sn sonra can %.1f → %.1f (dolmamalı)" % [hurt, player.health])
	await create_timer(4.0).timeout
	print("Hasardan 7 sn sonra can %.1f (~2 dolmuş olmalı)" % player.health)
	player.mana = 20.0
	player.mana_changed.emit(player.mana, player.max_mana)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/mana.png")
	quit()
