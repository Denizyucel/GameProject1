# İçe aktarılmış bir modelin düğüm ağacını, sınır kutusunu ve animasyonlarını yazdıran yardımcı betik.
# Çalıştırma:  godot --headless --path godot -s tools/inspect.gd -- res://assets/.../dosya.fbx

extends SceneTree


func _initialize() -> void:
	for path in OS.get_cmdline_user_args():
		print("=== ", path)
		var scene: PackedScene = load(path)
		var node := scene.instantiate()
		dump(node, 0)
		print("Sınır kutusu: ", aabb(node, Transform3D.IDENTITY))
		for player in node.find_children("*", "AnimationPlayer", true, false):
			var ap := player as AnimationPlayer
			for anim_name in ap.get_animation_list():
				var anim := ap.get_animation(anim_name)
				print("Animasyon '%s' %.2f sn, %d iz; ilk izler:" % [anim_name, anim.length, anim.get_track_count()])
				for i in mini(3, anim.get_track_count()):
					print("   ", anim.track_get_type(i), " ", anim.track_get_path(i))
		node.free()
	quit()


func dump(node: Node, depth: int) -> void:
	if depth > 4:
		return
	var extra := ""
	if node is Node3D:
		extra = " scale=%s" % (node as Node3D).scale
	if node is Skeleton3D:
		var sk := node as Skeleton3D
		extra += " kemik=%d ilk=%s" % [sk.get_bone_count(), sk.get_bone_name(0)]
	print("  ".repeat(depth), node.name, " (", node.get_class(), ")", extra)
	for child in node.get_children():
		dump(child, depth + 1)


func aabb(node: Node, parent: Transform3D) -> AABB:
	var xform := parent
	if node is Node3D:
		xform = parent * (node as Node3D).transform
	var box := AABB()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		box = xform * (node as MeshInstance3D).mesh.get_aabb()
	for child in node.get_children():
		var b := aabb(child, xform)
		if b.size != Vector3.ZERO:
			box = b if box.size == Vector3.ZERO else box.merge(b)
	return box
