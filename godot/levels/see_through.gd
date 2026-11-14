# Karakter bir parçanın (ağaç, duvar, raf, sütun) arkasında kalınca o parçayı yarı saydam yapar; karakter
# çıkınca parça yeniden belirir. Fizik/çarpışma kutusu kullanmaz: her parçanın sınır kutusu (AABB: parçayı
# saran en küçük kutu) açılışta bir kez ölçülür, sonra karakterden kameraya uzanan çizgi bu kutuyu kesiyor
# mu diye bakılır. Kutu parçanın kendi yönünde tutulur (dönmüş duvarlarda da sıkı oturur).
# Saydamlık GeometryInstance3D.transparency ile verilir: malzemeyi kopyalamaya gerek yok.

extends Node

@export var player: Node3D
@export var camera: Camera3D
## Parçaların durduğu düğümler: her çocuğu bir parça (içinde "Model")
@export var piece_roots: Array[Node3D] = []

const FADED := 0.7 # arkasında karakter varken parçanın saydamlığı (0 = opak, 1 = görünmez)
const FADE_SPEED := 4.0 # saniyede saydamlık değişimi (0.7'ye ~0.18 sn'de varır)
const CHECK_EVERY := 0.1 # saniye; her karede bakmaya gerek yok
const REACH := 14.0 # karakterden yatayda bundan uzak parçalar onu örtemez (en uzun ağaç ~8 m)
const MIN_HEIGHT := 1.2 # bundan alçak parçalar (taş, moloz, kitap yığını) karakteri örtmez
const RAY_LENGTH := 30.0
# Karakterin kameraya doğru bakılan noktaları (yerden yükseklik): ayak bileği, göğüs, baş
const BODY_HEIGHTS := [0.3, 1.0, 1.8]

var pieces: Array[Dictionary] = [] # {node, box (parçanın kendi uzayında), meshes, at (dünyada x, z)}
var faded: Array[Dictionary] = [] # şu an saydam olan ya da geri belirmekte olan parçalar
var check_left := 0.0


func _ready() -> void:
	for root in piece_roots:
		for holder in root.get_children():
			var node := holder as Node3D
			if node == null:
				continue
			var meshes := node.find_children("*", "GeometryInstance3D", true, false)
			var box := local_box(node, meshes)
			if meshes.is_empty() or box.size.y * node.global_transform.basis.get_scale().y < MIN_HEIGHT:
				continue
			pieces.append({
				"node": node, "box": box, "meshes": meshes, "hidden": false,
				"at": Vector2(node.global_position.x, node.global_position.z),
			})


## Parçanın bütün meshlerini saran kutu, parçanın (holder) kendi uzayında
func local_box(holder: Node3D, meshes: Array) -> AABB:
	var to_local := holder.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mesh in meshes:
		var instance := mesh as GeometryInstance3D
		var mesh_box := (to_local * instance.global_transform) * instance.get_aabb()
		box = mesh_box if first else box.merge(mesh_box)
		first = false
	return box


func _process(delta: float) -> void:
	check_left -= delta
	if check_left <= 0:
		check_left = CHECK_EVERY
		check()
	# Saydamlığı hedefe doğru yumuşakça götür; tam opak olan listeden çıkar
	for i in range(faded.size() - 1, -1, -1):
		var piece := faded[i]
		var target := FADED if piece["hidden"] else 0.0
		var meshes: Array = piece["meshes"]
		var value := move_toward((meshes[0] as GeometryInstance3D).transparency, target, FADE_SPEED * delta)
		for mesh in meshes:
			(mesh as GeometryInstance3D).transparency = value
		if value == 0.0 and not piece["hidden"]:
			faded.remove_at(i)


func check() -> void:
	if player == null or camera == null:
		return
	var feet := player.global_position
	var here := Vector2(feet.x, feet.z)
	var to_camera := camera.global_transform.basis.z * RAY_LENGTH # kamera -z'ye bakar; +z kameraya doğru
	for piece in pieces:
		var hides := false
		if here.distance_squared_to(piece["at"]) < REACH * REACH:
			var to_local: Transform3D = (piece["node"] as Node3D).global_transform.affine_inverse()
			var box: AABB = piece["box"]
			for height in BODY_HEIGHTS:
				var from: Vector3 = feet + Vector3.UP * height
				if box.intersects_segment(to_local * from, to_local * (from + to_camera)):
					hides = true
					break
		if hides and not piece["hidden"] and not faded.has(piece):
			faded.append(piece)
		piece["hidden"] = hides
