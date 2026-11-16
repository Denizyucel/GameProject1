# Gotik binanın içinde merdivenlerle katları dolaşır (gerçek yol bulmayla yürüyerek): kat 0 → kat 1 → kat 2 → kat 1 →
# kat 0 → mahzen → kat 0. Her varışta hangi katta olduğunu yazar ve ekran görüntüsü alır (kat-<ad>.png).
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/stairs_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var ici = main.get_node("Gezinme/BinaIci")
	await create_timer(1.0).timeout
	for e in main.get_node("Dusmanlar").get_children():
		e.queue_free()
	await ici.enter()
	await create_timer(0.3).timeout
	print("Başlangıç: %s" % which(ici, player))
	await shot(out_dir + "/kat-Kat0.png")
	# [şu anki kattaki geçidin indeksi PORTALS içinde]
	var route := [1, 4, 5, 3, 2, 6]
	for index in route:
		var portal: Array = ici.PORTALS[index]
		var at: Vector3 = ici.floor_point(portal[0], portal[1])
		player.agent.target_position = at
		var t := 0.0
		var before: String = which(ici, player)
		while which(ici, player) == before and t < 20.0:
			await create_timer(0.25).timeout
			t += 0.25
		await create_timer(1.2).timeout
		var now: String = which(ici, player)
		print("%s → %s: %s (%.1f sn)" % [portal[0], portal[2], "VARDI" if now == portal[2] else "TAKILDI, " + now + " " + str(player.global_position), t])
		await shot(out_dir + "/kat-%s.png" % now)
	quit()


func which(ici: Node, player: Node3D) -> String:
	if not ici.is_inside(player.global_position):
		return "disari"
	var best := ""
	var best_d := INF
	for name in ["KatEksi1", "Kat0", "Kat1", "Kat2"]:
		var d: float = (ici.get_node(name) as Node3D).global_position.distance_to(Vector3(player.global_position.x, (ici.get_node(name) as Node3D).global_position.y, player.global_position.z))
		if d < best_d:
			best_d = d
			best = name
	return best


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
