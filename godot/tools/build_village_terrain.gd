# Köy modelinden (levels/koy.tscn içindeki Model) zemin verisini çıkarır: levels/harabe_koy_terrain.res.
# Her 0.25 m'lik kare için: zeminin yüksekliği (yukarı bakan yüzeylerin en alçağı: saçak altında çatı değil
# yer sayılır) ve yürünebilir mi (üstünde bel hizasında bir şey varsa, yamaç dikse ya da girişten
# ulaşılamıyorsa yürünemez). Modeli taşıyınca/ölçekleyince yeniden çalıştır, sonra navmesh'i çıkar.
# Çalıştırma:  godot --headless --path godot -s tools/build_village_terrain.gd [-- <harita.txt>]

extends SceneTree

const CELL := 0.25
const AREA := Rect2(-20, 60, 40, 44) # köy bölgesi (dünya x, z, genişlik, derinlik)
const ENTRANCE := Vector2(0, 60.2) # yürünebilirlik buradan yayılır (Kül Yolu'nun ucu)
const MAX_STEP := 0.3 # komşu iki kare arasında en fazla bu kadar yükseklik farkı yürünür
const BODY_FROM := 0.35 # zeminden bu yükseklikle...
const BODY_TO := 1.9 # ...bu yükseklik arasında bir yüzey varsa orası dolu (duvar, çit)
const NONE := -1000.0


func _initialize() -> void:
	var village: Node3D = (load("res://levels/koy.tscn") as PackedScene).instantiate()
	var model: Node3D = village.get_node("Model")
	var size_x := int(AREA.size.x / CELL)
	var size_z := int(AREA.size.y / CELL)
	var ground := PackedFloat32Array()
	ground.resize(size_x * size_z)
	ground.fill(NONE)
	var triangles: Array = [] # [a, b, c] dünya konumları
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var xform := model.transform * relative_transform(instance, model)
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				triangles.append([xform * vertices[indices[i]], xform * vertices[indices[i + 1]], xform * vertices[indices[i + 2]]])
	print("Üçgen: ", triangles.size())

	# 1. geçiş: zemin = kareyi örten, yukarı bakan yüzeylerin en alçağı
	for pass_number in 2:
		var busy := PackedByteArray()
		busy.resize(size_x * size_z)
		for triangle in triangles:
			var a: Vector3 = triangle[0]
			var b: Vector3 = triangle[1]
			var c: Vector3 = triangle[2]
			var normal := (b - a).cross(c - a)
			if normal.length_squared() < 1e-12:
				continue
			var up := absf(normal.normalized().y) # yüzün yönü ters sarılmış olabilir; eğime bak
			var from_x := maxi(0, floori((minf(a.x, minf(b.x, c.x)) - AREA.position.x) / CELL))
			var to_x := mini(size_x - 1, floori((maxf(a.x, maxf(b.x, c.x)) - AREA.position.x) / CELL))
			var from_z := maxi(0, floori((minf(a.z, minf(b.z, c.z)) - AREA.position.y) / CELL))
			var to_z := mini(size_z - 1, floori((maxf(a.z, maxf(b.z, c.z)) - AREA.position.y) / CELL))
			for z in range(from_z, to_z + 1):
				for x in range(from_x, to_x + 1):
					var px := AREA.position.x + (x + 0.5) * CELL
					var pz := AREA.position.y + (z + 0.5) * CELL
					var y = height_in_triangle(px, pz, a, b, c)
					if y == null:
						continue
					var index := z * size_x + x
					if pass_number == 0:
						# Tabanın alt yüzü de "yatay": zemin, tabandan (y < -0.05) yukarıdaki en alçak yüzey
						if up > 0.5 and y > -0.05 and (ground[index] == NONE or y < ground[index]):
							ground[index] = y
					elif ground[index] != NONE and y > ground[index] + BODY_FROM and y < ground[index] + BODY_TO:
						busy[index] = 1
		if pass_number == 1:
			finish(ground, busy, size_x, size_z)
	quit()


func finish(ground: PackedFloat32Array, busy: PackedByteArray, size_x: int, size_z: int) -> void:
	var heights := PackedFloat32Array()
	heights.resize(size_x * size_z)
	for i in heights.size():
		heights[i] = 0.0 if ground[i] == NONE else maxf(ground[i], 0.0) # modelin dışı: düz çimen
	# Yürünebilir aday: üstü boş ve dört komşusuyla arası dik değil
	var open := PackedByteArray()
	open.resize(size_x * size_z)
	for z in size_z:
		for x in size_x:
			var index := z * size_x + x
			if busy[index] == 1:
				continue
			var steep := false
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + offset.x
				var nz: int = z + offset.y
				if nx < 0 or nz < 0 or nx >= size_x or nz >= size_z:
					continue
				if absf(heights[nz * size_x + nx] - heights[index]) > MAX_STEP:
					steep = true
			open[index] = 0 if steep else 1
	# Girişten ulaşılabilenler yürünebilir; çatıların üstü gibi kopuk adalar değil
	var reached := PackedByteArray()
	reached.resize(size_x * size_z)
	var start := Vector2i(int((ENTRANCE.x - AREA.position.x) / CELL), int((ENTRANCE.y - AREA.position.y) / CELL))
	var queue: Array[Vector2i] = [start]
	reached[start.y * size_x + start.x] = 1
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = at + offset
			if next.x < 0 or next.y < 0 or next.x >= size_x or next.y >= size_z:
				continue
			var index := next.y * size_x + next.x
			if reached[index] == 1 or open[index] == 0:
				continue
			# Adım: iki kare arası da dik olmamalı
			if absf(heights[index] - heights[at.y * size_x + at.x]) > MAX_STEP:
				continue
			reached[index] = 1
			queue.append(next)
	var data := TerrainData.new()
	data.cell = CELL
	data.origin = AREA.position
	data.size_x = size_x
	data.size_z = size_z
	data.heights = heights
	data.blocked = PackedByteArray()
	data.blocked.resize(size_x * size_z)
	var walkable := 0
	for i in reached.size():
		data.blocked[i] = 0 if reached[i] == 1 else 1
		walkable += reached[i]
	var error := ResourceSaver.save(data, "res://levels/harabe_koy_terrain.res")
	print("Kaydedildi: levels/harabe_koy_terrain.res (%s), %d x %d kare, yürünebilir %d" % [error_string(error), size_x, size_z, walkable])

	# Harita (her harf 1 x 1 m): boşluk = model yok (çimen), rakam = yürünebilir zemin (yükseklik, metre), # = dolu
	var lines := PackedStringArray()
	var per := int(1.0 / CELL)
	for z in range(0, size_z, per):
		var line := "%3d " % int(AREA.position.y + z * CELL)
		for x in range(0, size_x, per):
			var free := 0
			var inside := 0
			var total := 0.0
			for dz in per:
				for dx in per:
					var index := (z + dz) * size_x + x + dx
					free += 1 - data.blocked[index]
					inside += 0 if ground[index] == NONE else 1
					total += heights[index]
			if free < per * per * 0.7:
				line += "#"
			elif inside == 0:
				line += " "
			else:
				line += str(mini(9, roundi(total / (per * per))))
		lines.append(line)
	var text := "\n".join(lines)
	print(text)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(text)


## (px, pz) noktası üçgenin içindeyse üçgenin o noktadaki yüksekliği; değilse null
func height_in_triangle(px: float, pz: float, a: Vector3, b: Vector3, c: Vector3) -> Variant:
	var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(d) < 1e-9:
		return null
	var u := ((b.z - c.z) * (px - c.x) + (c.x - b.x) * (pz - c.z)) / d
	var v := ((c.z - a.z) * (px - c.x) + (a.x - c.x) * (pz - c.z)) / d
	var w := 1.0 - u - v
	if u < 0 or v < 0 or w < 0:
		return null
	return u * a.y + v * b.y + w * c.y


func relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != ancestor:
		xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform
