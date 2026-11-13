# Yanık Kütüphane'yi tarayıcı sürümündeki plandan (src/game/levels/yanikKutuphane.ts) Godot sahnesine
# dönüştüren BİR KERELİK betik. Sonuç: res://levels/yanik_kutuphane.tscn ve res://main.tscn.
# Bundan sonra bölge Godot editöründe düzenlenir. Betiği yeniden çalıştırmak editörde yapılan
# değişikliklerin üzerine yazar!
#
# Çalıştırma (proje klasöründe):  godot --headless --path godot -s tools/build_yanik_kutuphane.gd

extends SceneTree

const KIT := "res://assets/kit/"

# Plan: 800 x 800 px, 20 px = 1 m, üst = kuzey (TS dosyasıyla aynı)
const PLAN_SIZE := 800.0
const PIXELS_PER_METER := 20.0
const SPAWN := Vector2(400, 215)
const HALL := [206.0, 126.0, 594.0, 538.0] # sol, üst, sağ, alt

# Her parçanın yerde kapladığı en uzun kenar (metre). Model bu boya ölçeklenir.
const PART_SIZES := {
	"yikik-duvar": 4.0, "yuksek-duvar": 4.0, "duvar-rafi": 3.0, "cati-kemeri": 4.0, "kemer-kapi": 4.0,
	"sutun": 0.9, "kirik-sutun": 0.9, "yanmis-raf": 2.0, "muhur-kaidesi": 1.5, "kitap-yigini": 0.7,
	"moloz": 2.0, "kuru-agac": 3.0,
}

# [parça, plandaki merkez x, merkez y, saat yönünde dönüş (derece)]
const PIECES := [
	["yuksek-duvar", 240, 126], ["yuksek-duvar", 320, 126], ["yuksek-duvar", 400, 126],
	["yuksek-duvar", 480, 126], ["yuksek-duvar", 560, 126],
	["yuksek-duvar", 206, 172, 90], ["yuksek-duvar", 206, 252, 90],
	["yuksek-duvar", 206, 412, 90], ["yuksek-duvar", 206, 492, 90],
	["duvar-rafi", 240, 142], ["duvar-rafi", 320, 142], ["duvar-rafi", 480, 142], ["duvar-rafi", 560, 142],
	["duvar-rafi", 222, 172, -90], ["duvar-rafi", 222, 252, -90], ["duvar-rafi", 222, 412, -90], ["duvar-rafi", 222, 492, -90],
	["cati-kemeri", 206, 332, 90],
	["yikik-duvar", 594, 172, 90], ["yikik-duvar", 594, 252, 90], ["yikik-duvar", 594, 332, 90],
	["yikik-duvar", 594, 412, 90], ["yikik-duvar", 594, 492, 90],
	["yikik-duvar", 240, 538], ["yikik-duvar", 320, 538], ["kemer-kapi", 400, 538],
	["yikik-duvar", 480, 538], ["yikik-duvar", 560, 538],
	["sutun", 300, 210], ["sutun", 300, 300], ["kirik-sutun", 300, 390], ["sutun", 300, 470],
	["kirik-sutun", 500, 210], ["sutun", 500, 300], ["sutun", 500, 390], ["sutun", 500, 470],
	["yanmis-raf", 250, 230], ["yanmis-raf", 250, 280], ["yanmis-raf", 250, 360], ["yanmis-raf", 250, 440],
	["yanmis-raf", 550, 250], ["yanmis-raf", 550, 310], ["yanmis-raf", 550, 420], ["yanmis-raf", 550, 470],
	["muhur-kaidesi", 400, 165],
	["kitap-yigini", 345, 180], ["kitap-yigini", 455, 185], ["kitap-yigini", 440, 330],
	["kitap-yigini", 330, 470], ["kitap-yigini", 535, 365],
	["moloz", 172, 392], ["moloz", 555, 160], ["moloz", 450, 500], ["moloz", 640, 600],
	["kuru-agac", 90, 110], ["kuru-agac", 700, 90], ["kuru-agac", 120, 420], ["kuru-agac", 690, 380],
	["kuru-agac", 150, 660], ["kuru-agac", 610, 720], ["kuru-agac", 280, 640],
]

# Zemin dokuları (ambientCG): bir doku karesinin dünyada kapladığı alan (metre) ve rengini koyulaştıran ton
const OUTSIDE_FLOOR := {"dir": "res://assets/floor/disarisi/Ground048_1K-JPG_", "tile": Vector2(3, 3), "tint": Color("#8d8884")}
const HALL_FLOOR := {"dir": "res://assets/floor/salonun-ici/Tiles130_1K-JPG_", "tile": Vector2(6, 3), "tint": Color("#74777f")}
const HALL_FLOOR_LIFT := 0.02 # iç zemin dış zeminin bu kadar üstünde, ki çakışıp titremesinler

# Kamera: karakterden (20, 20, 20) ötede, izometrik; ekranda 18 m yükseklik görünür
const CAMERA_OFFSET := Vector3(20, 20, 20)
const VIEW_HEIGHT := 18.0


func _initialize() -> void:
	var level := build_level()
	save_scene(level, "res://levels/yanik_kutuphane.tscn")
	var main := build_main()
	save_scene(main, "res://main.tscn")
	print("Tamam: levels/yanik_kutuphane.tscn ve main.tscn yazıldı")
	quit()


# Plan pikselini dünya koordinatına çevir: planın ortası (0, 0), aşağısı +z
func plan_to_world(x: float, y: float) -> Vector3:
	return Vector3((x - PLAN_SIZE / 2) / PIXELS_PER_METER, 0, (y - PLAN_SIZE / 2) / PIXELS_PER_METER)


func build_level() -> Node3D:
	var root := Node3D.new()
	root.name = "YanikKutuphane"

	# Zemin: bütün haritaya toprak, salonun içine taş döşeme
	var map_size := PLAN_SIZE / PIXELS_PER_METER
	add_floor(root, "Disarisi", OUTSIDE_FLOOR, Vector2(map_size, map_size), Vector3.ZERO)
	var from := plan_to_world(HALL[0], HALL[1])
	var to := plan_to_world(HALL[2], HALL[3])
	add_floor(root, "SalonunIci", HALL_FLOOR, Vector2(to.x - from.x, to.z - from.z),
		Vector3((from.x + to.x) / 2, HALL_FLOOR_LIFT, (from.z + to.z) / 2))

	var pieces := Node3D.new()
	pieces.name = "Parcalar"
	root.add_child(pieces)
	pieces.owner = root

	# Her parça dosyası bir kez yüklenir; ölçeği ve zemine oturma kayması o modelin sınır kutusundan
	var templates := {}
	var counts := {}
	for entry in PIECES:
		var part: String = entry[0]
		if not templates.has(part):
			var scene: PackedScene = load(KIT + part + ".glb")
			if scene == null:
				push_warning("Parça yüklenemedi: " + part)
				continue
			templates[part] = {"scene": scene, "box": scene_aabb(scene.instantiate())}
		var t: Dictionary = templates[part]
		var box: AABB = t["box"]
		var scale_factor: float = PART_SIZES[part] / maxf(box.size.x, box.size.z)
		var center := box.get_center()

		counts[part] = counts.get(part, 0) + 1
		# Tutucu: haritadaki yeri ve dönüşü. Editörde taşınacak ve döndürülecek olan bu.
		var holder := Node3D.new()
		holder.name = "%s-%d" % [part, counts[part]]
		holder.position = plan_to_world(entry[1], entry[2])
		var degrees: float = entry[3] if entry.size() > 3 else 0.0
		holder.rotation_degrees.y = -degrees # plan saat yönünde döner; Godot'da artı yön tersidir
		pieces.add_child(holder)
		holder.owner = root

		# Model: tutucunun içinde, kendi ortasına ve zemine hizalanmış, ölçeklenmiş
		var model: Node3D = (t["scene"] as PackedScene).instantiate()
		model.name = "Model"
		model.scale = Vector3.ONE * scale_factor
		model.position = Vector3(-center.x, -box.position.y, -center.z) * scale_factor
		holder.add_child(model)
		model.owner = root # sadece modelin kendisi kaydedilir; içi .glb dosyasına bağlı kalır

	print("Bölge: %d parça" % pieces.get_child_count())
	return root


# Bir sahnedeki bütün şekillerin, sahnenin kendi eksenindeki toplam sınır kutusu
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


# Dokulu, yatay bir zemin: boyutu size (metre), ortası center
func add_floor(root: Node3D, node_name: String, style: Dictionary, size: Vector2, center: Vector3) -> void:
	var material := StandardMaterial3D.new()
	var dir: String = style["dir"]
	material.albedo_texture = load(dir + "Color.jpg")
	material.albedo_color = style["tint"]
	material.normal_enabled = true
	material.normal_texture = load(dir + "NormalGL.jpg")
	material.roughness_texture = load(dir + "Roughness.jpg")
	material.ao_enabled = true
	material.ao_texture = load(dir + "AmbientOcclusion.jpg")
	# Doku kaç kez tekrar etsin: zeminin boyu / bir doku karesinin boyu
	var tile: Vector2 = style["tile"]
	material.uv1_scale = Vector3(size.x / tile.x, size.y / tile.y, 1)
	var material_path := "res://materials/%s.tres" % node_name.to_snake_case()
	ResourceSaver.save(material, material_path)

	var plane := PlaneMesh.new()
	plane.size = size
	var floor := MeshInstance3D.new()
	floor.name = node_name
	floor.mesh = plane
	floor.material_override = load(material_path)
	floor.position = center
	root.add_child(floor)
	floor.owner = root


func build_main() -> Node3D:
	var root := Node3D.new()
	root.name = "Main"

	# Ortam: arka plan rengi ve her yere eşit vuran yumuşak ışık (gökyüzü morumsu, zemin koyu)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#121018")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8f86b0")
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.name = "Ortam"
	world_env.environment = env
	root.add_child(world_env)
	world_env.owner = root

	# Ay ışığı: yönlü ışık, gölge düşürür; (-8, 15, 6) yönünden haritanın ortasına bakar
	var moon := DirectionalLight3D.new()
	moon.name = "AyIsigi"
	moon.light_color = Color("#c9d4ff")
	moon.light_energy = 1.2
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 80
	moon.transform = Transform3D.IDENTITY.looking_at(-Vector3(-8, 15, 6), Vector3.UP)
	root.add_child(moon)
	moon.owner = root

	# Bölge
	var level: PackedScene = load("res://levels/yanik_kutuphane.tscn")
	var level_node := level.instantiate()
	root.add_child(level_node)
	level_node.owner = root

	# İzometrik kamera: doğuş noktasına bakar. Ortografik: uzaktaki şey küçülmez (Diablo bakışı).
	var spawn := plan_to_world(SPAWN.x, SPAWN.y)
	var camera := Camera3D.new()
	camera.name = "Kamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_HEIGHT
	camera.near = 0.1
	camera.far = 200
	camera.transform = Transform3D(Basis.IDENTITY, spawn + CAMERA_OFFSET).looking_at(spawn, Vector3.UP)
	root.add_child(camera)
	camera.owner = root
	return root


func save_scene(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error != OK:
		push_error("Sahne paketlenemedi: %s (%d)" % [path, error])
		return
	error = ResourceSaver.save(packed, path)
	if error != OK:
		push_error("Sahne kaydedilemedi: %s (%d)" % [path, error])
