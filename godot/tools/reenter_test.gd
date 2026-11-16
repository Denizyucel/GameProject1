# Gotik binaya iskeletlerle girip çıkmayı, sonra yeniden girmeyi dener: iskeletler oyuncuyla birlikte taşınmalı;
# dışarı çıkınca kapıdan biraz uzaklaşıp geri gelince yeniden içeri girilebilmeli.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/reenter_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var inside = main.get_node("Gezinme/BinaIci")
	var door = main.get_node("Gezinme/GotikBina/Kapi")
	await create_timer(1.0).timeout
	for e in main.get_node("Dusmanlar").get_children():
		e.queue_free()
	# Kapının yanında iki iskelet kaldır
	player.global_position = Vector3(-21, 0, 40)
	player.agent.target_position = player.global_position
	await physics_frame
	for i in 2:
		main.on_buried(player.global_position + Vector3(1.0, 0, -0.5 + i))
		await physics_frame
		while not main.raise_dead():
			await physics_frame
		while player.cast_progress() >= 0:
			await physics_frame
	await create_timer(1.5).timeout
	report("İskeletler kalktı", main, inside, player)
	main.has_golden_key = true
	main.quests.start(main.DOOR_QUEST, main.DOOR_TITLE)

	# 1. Kapıya yürü → içeri
	await walk_until(player, Vector3(-24.6, 0, 40), func(): return inside.is_inside(player.global_position), 8.0)
	await create_timer(2.0).timeout
	report("İçeri girince", main, inside, player)
	# 2. Kapıdan çık
	player.agent.target_position = inside.floor_point("Kat0", inside.PORTALS[0][1])
	await walk_until(player, inside.floor_point("Kat0", inside.PORTALS[0][1]), func(): return not inside.is_inside(player.global_position), 8.0)
	await create_timer(2.0).timeout
	report("Dışarı çıkınca", main, inside, player)
	# 3. Kapıdan 3 m uzaklaş, sonra yeniden kapıya yürü
	await walk_until(player, Vector3(-21.5, 0, 40), func(): return false, 2.5)
	print("Kapı hazır mı (armed): %s, kapıya uzaklık %.1f" % [door.armed, Vector2(player.global_position.x - door.global_position.x, player.global_position.z - door.global_position.z).length()])
	await walk_until(player, Vector3(-24.6, 0, 40), func(): return inside.is_inside(player.global_position), 8.0)
	await create_timer(2.0).timeout
	report("Yeniden kapıya gelince", main, inside, player)
	# 4. İçerideyken oyuncu birden kütüphanede (ölüp doğmuş gibi): iskeletler yanına gelmeli
	player.global_position = Vector3(0, 0, -9.25)
	player.agent.target_position = player.global_position
	await create_timer(1.0).timeout
	report("Oyuncu kütüphanede doğunca", main, inside, player)
	quit()


func walk_until(player, at: Vector3, done: Callable, limit: float) -> void:
	player.agent.target_position = at
	var t := 0.0
	while not done.call() and t < limit:
		await create_timer(0.2).timeout
		t += 0.2


func report(label: String, main, inside, player) -> void:
	var where := []
	for m in main.minions:
		where.append("%s %s" % ["içeride" if inside.is_inside(m.global_position) else "dışarıda", Vector3(snappedf(m.global_position.x, 0.1), 0, snappedf(m.global_position.z, 0.1))])
	print("%s: oyuncu %s %s; iskeletler %s" % [label, "içeride" if inside.is_inside(player.global_position) else "dışarıda", Vector3(snappedf(player.global_position.x, 0.1), 0, snappedf(player.global_position.z, 0.1)), where])
