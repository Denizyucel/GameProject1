# Kül Yolu'nu (Act I, 2. bölge; Hikaye.md) aşağıdaki plandan Godot sahnesine dönüştüren BİR KERELİK betik.
# Sonuç: res://levels/kul_yolu.tscn. Bundan sonra bölge editörde düzenlenir; betiği yeniden çalıştırmak
# editörde yapılan değişikliklerin üzerine yazar! main.tscn'de kütüphanenin hemen güneyinde durur
# (Gezinme/KulYolu, z = 40); parça taşıyınca navmesh'i yeniden çıkar: godot --path godot -s tools/bake_navmesh.gd
#
# Çalıştırma:  godot --headless --path godot -s tools/build_kul_yolu.gd
#
# Plan: Yanık Kütüphane'deki gibi 800 x 800 px = 40 x 40 m, 20 px = 1 m, üst = kuzey. Kuzeyi kütüphaneye
# açık (kapı yok); yol iki yanı kuru ağaç, yıkık duvar ve molozla çevrili olarak güneye iner.

extends SceneTree

const KIT := "res://assets/kit/"
const PLAN_SIZE := 800.0
const PIXELS_PER_METER := 20.0

const PART_SIZES := {
	"yikik-duvar": 4.0, "kirik-sutun": 0.9, "sutun": 0.9, "moloz": 2.0, "kuru-agac": 3.0,
	"kitap-yigini": 0.7,
}

# [parça, plandaki merkez x, merkez y, saat yönünde dönüş (derece)]
const PIECES := [
	# Yolun batısı
	["yikik-duvar", 285, 230, 90], ["kirik-sutun", 300, 300], ["yikik-duvar", 250, 470, 80],
	["moloz", 300, 380], ["kirik-sutun", 290, 560], ["moloz", 230, 640],
	# Yolun doğusu
	["yikik-duvar", 520, 180, 95], ["moloz", 505, 300], ["kirik-sutun", 515, 420],
	["yikik-duvar", 545, 560, 100], ["sutun", 505, 680],
	# Yolda: yangından kaçarken düşmüş kitaplar
	["kitap-yigini", 420, 250], ["kitap-yigini", 370, 520],
	# Kuru ağaçlar (iki yanda sık, yolda yok)
	["kuru-agac", 120, 90], ["kuru-agac", 190, 260], ["kuru-agac", 90, 380], ["kuru-agac", 170, 540],
	["kuru-agac", 110, 720], ["kuru-agac", 680, 110], ["kuru-agac", 620, 290], ["kuru-agac", 720, 420],
	["kuru-agac", 640, 600], ["kuru-agac", 700, 740], ["kuru-agac", 230, 760], ["kuru-agac", 600, 470],
]

# Zemin: kütüphanenin dışıyla aynı malzeme (harita tek parça; renk farkı sınırda çizgi gibi görünüyordu)
const FLOOR_MATERIAL := "res://materials/disarisi.tres"


func _initialize() -> void:
	var level := build_level()
	var scene := PackedScene.new()
	scene.pack(level)
	var error := ResourceSaver.save(scene, "res://levels/kul_yolu.tscn")
	print("Tamam: levels/kul_yolu.tscn (%s)" % error_string(error))
	quit()


func plan_to_world(x: float, y: float) -> Vector3:
	return Vector3((x - PLAN_SIZE / 2) / PIXELS_PER_METER, 0, (y - PLAN_SIZE / 2) / PIXELS_PER_METER)


func build_level() -> Node3D:
	var root := Node3D.new()
	root.name = "KulYolu"
	var map_size := PLAN_SIZE / PIXELS_PER_METER
	var plane := PlaneMesh.new()
	plane.size = Vector2(map_size, map_size)
	var ground := MeshInstance3D.new()
	ground.name = "KulYoluZemin"
	ground.mesh = plane
	ground.material_override = load(FLOOR_MATERIAL)
	root.add_child(ground)
	ground.owner = root

	var pieces := Node3D.new()
	pieces.name = "Parcalar"
	root.add_child(pieces)
	pieces.owner = root
	var templates := {}
	var counts := {}
	for entry in PIECES:
		var part: String = entry[0]
		if not templates.has(part):
			var packed: PackedScene = load(KIT + part + ".glb")
			templates[part] = {"scene": packed, "box": scene_aabb(packed.instantiate())}
		var box: AABB = templates[part]["box"]
		var scale_factor: float = PART_SIZES[part] / maxf(box.size.x, box.size.z)
		var center := box.get_center()
		counts[part] = counts.get(part, 0) + 1
		var holder := Node3D.new()
		holder.name = "%s-%d" % [part, counts[part]]
		holder.position = plan_to_world(entry[1], entry[2])
		holder.rotation_degrees.y = -(entry[3] if entry.size() > 3 else 0.0)
		pieces.add_child(holder)
		holder.owner = root
		var model: Node3D = (templates[part]["scene"] as PackedScene).instantiate()
		model.name = "Model"
		model.scale = Vector3.ONE * scale_factor
		model.position = Vector3(-center.x, -box.position.y, -center.z) * scale_factor
		holder.add_child(model)
		model.owner = root
	print("Kül Yolu: %d parça" % pieces.get_child_count())
	return root


func scene_aabb(node: Node, parent := Transform3D.IDENTITY) -> AABB:
	var xform := parent
	if node is Node3D:
		xform = parent * (node as Node3D).transform
	var box := AABB()
	var has_box := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		box = xform * (node as MeshInstance3D).mesh.get_aabb()
		has_box = true
	for child in node.get_children():
		var child_box := scene_aabb(child, xform)
		if child_box.size == Vector3.ZERO:
			continue
		box = box.merge(child_box) if has_box else child_box
		has_box = true
	return box
