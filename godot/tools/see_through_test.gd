# Parça saydamlaşmasını dener: oyuncuyu bir ağacın, sonra kütüphanenin güney duvarının arkasına koyar
# (kameraya göre arkası = kuzeybatısı); parça saydamlaşmalı, oyuncu uzaklaşınca yeniden belirmeli.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/see_through_test.gd -- <klasör>

extends SceneTree


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	var see_through = main.get_node("Saydamlik")
	await create_timer(1.0).timeout
	print("Parça sayısı: ", see_through.pieces.size())
	var tree: Node3D = main.get_node("Gezinme/KulYolu/Parcalar/kuru-agac-1")
	var wall: Node3D = main.get_node("Gezinme/YanikKutuphane/Parcalar/yikik-duvar-1")
	var number := 1
	for target in [tree, wall]:
		player.global_position = target.global_position + Vector3(-1.2, 0, -1.2)
		await create_timer(0.8).timeout
		print("%s arkasında: saydamlık %.2f, saydam parça sayısı %d" % [target.name, transparency_of(target), see_through.faded.size()])
		await shot(out_dir, "saydam-%d-arkada" % number)
		player.global_position = target.global_position + Vector3(4, 0, 4)
		await create_timer(0.8).timeout
		print("%s önünde: saydamlık %.2f" % [target.name, transparency_of(target)])
		number += 1
	await shot(out_dir, "saydam-3-onde")
	quit()


func transparency_of(piece: Node3D) -> float:
	return (piece.find_children("*", "GeometryInstance3D", true, false)[0] as GeometryInstance3D).transparency


func shot(out_dir: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s.png" % file_name)
