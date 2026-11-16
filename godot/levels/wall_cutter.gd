# Duvar kesici: bir modelin mesh'lerinden, verilen kutuların (AABB, modelin kendi uzayında) içine düşen kısmı siler.
# Kutunun sınırından geçen üçgenler tam sınırdan kırpılır (Sutherland–Hodgman: çokgen bir düzlemle kesilir);
# köşelerin konumu, normali, UV'si, rengi ve tanjantı kesim noktasında ara değerlenir, kalan duvar dokusuyla görünür.
# Kullanım: bina_ici.gd, kat planlarındaki alçak duvarlara geçit açmak için (kat planı güncellenince yeniden bakılmalı).
# Mesh kaynak dosyada değişmez; oyun açılınca bellekte yeni bir mesh üretilir.

class_name WallCutter

const ATTRIBUTES := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]


## model altındaki her MeshInstance3D'den (adı skip_if_contains içerenler hariç) kutuların içini sil. Kaç üçgen
## silindi/kırpıldı döndürür.
static func cut(model: Node3D, boxes: Array[AABB], skip_if_contains := "floor") -> int:
	var changed := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if skip_if_contains != "" and String(instance.name).to_lower().contains(skip_if_contains):
			continue
		var to_model := relative_transform(instance, model)
		var mesh_box := to_model * instance.get_aabb()
		var hits: Array[AABB] = []
		for box in boxes:
			if box.intersects(mesh_box):
				hits.append(box)
		if hits.is_empty():
			continue
		# Kutuların düzlemlerini mesh'in kendi uzayına çevir (normaller dışarı bakar: içeride uzaklık <= 0)
		var to_local := to_model.affine_inverse()
		var box_planes: Array = []
		for box in hits:
			var planes: Array[Plane] = []
			for p in box_to_planes(box):
				planes.append(to_local * p)
			box_planes.append(planes)
		var result := cut_mesh(instance.mesh, box_planes)
		if result[0] != null:
			instance.mesh = result[0]
			changed += result[1]
	return changed


## Kutulara değen eşyaları BÜTÜN olarak kaldır (fıçı yarım kalmasın): her mesh'te birbirine bağlı üçgen grupları (aynı
## köşeyi paylaşan üçgenler) bir eşya sayılır; sınır kutusu bir kutuya değen ve yatayda max_size'dan küçük gruplar silinir.
## keep: bu adları içeren parçalara dokunulmaz (duvarlar, zemin). Silinen eşya sayısını döndürür.
static func clear(model: Node3D, boxes: Array[AABB], keep: Array[String], max_size := 2.2) -> int:
	var removed := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var skip := false
		for name in keep:
			if String(instance.name).to_lower().contains(name):
				skip = true
		if skip:
			continue
		var to_model := relative_transform(instance, model)
		var mesh_box := to_model * instance.get_aabb()
		var touches := false
		for box in boxes:
			if box.intersects(mesh_box):
				touches = true
		if not touches:
			continue
		var new_mesh := ArrayMesh.new()
		var any := false
		for s in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(s)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for i in positions.size():
					indices.append(i)
			# Aynı konumdaki köşeleri birleştir (UV dikişleri ayrı köşe olsa da aynı eşya), sonra union-find
			var key_of := {}
			var parent := PackedInt32Array()
			var vertex_group := PackedInt32Array()
			vertex_group.resize(positions.size())
			for i in positions.size():
				var key := positions[i].snapped(Vector3.ONE * 0.001)
				if not key_of.has(key):
					key_of[key] = parent.size()
					parent.append(parent.size())
				vertex_group[i] = key_of[key]
			for t in range(0, indices.size(), 3):
				var a := find_root(parent, vertex_group[indices[t]])
				for k in [1, 2]:
					var b := find_root(parent, vertex_group[indices[t + k]])
					if a != b:
						parent[b] = a
			var group_box := {}
			for t in range(0, indices.size(), 3):
				var g := find_root(parent, vertex_group[indices[t]])
				for k in 3:
					var p := to_model * positions[indices[t + k]]
					group_box[g] = AABB(p, Vector3.ZERO) if not group_box.has(g) else (group_box[g] as AABB).expand(p)
			var doomed := {}
			for g in group_box:
				var gb: AABB = group_box[g]
				if gb.size.x > max_size or gb.size.z > max_size:
					continue
				for box in boxes:
					if box.intersects(gb):
						doomed[g] = true
			if not doomed.is_empty():
				any = true
				removed += doomed.size()
			var kept := PackedInt32Array()
			for t in range(0, indices.size(), 3):
				if not doomed.has(find_root(parent, vertex_group[indices[t]])):
					kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
			if kept.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = kept
			new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, instance.mesh.surface_get_material(s))
		if any:
			instance.mesh = new_mesh
	return removed


static func find_root(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func relative_transform(node: Node, top: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var x: Node = node
	while x != top and x != null:
		if x is Node3D:
			t = (x as Node3D).transform * t
		x = x.get_parent()
	return t


static func box_to_planes(box: AABB) -> Array[Plane]:
	var lo := box.position
	var hi := box.end
	return [
		Plane(Vector3.RIGHT, hi.x), Plane(Vector3.LEFT, -lo.x),
		Plane(Vector3.UP, hi.y), Plane(Vector3.DOWN, -lo.y),
		Plane(Vector3.BACK, hi.z), Plane(Vector3.FORWARD, -lo.z),
	]


## Bir mesh'in her yüzeyini kes. [yeni mesh ya da null (değişiklik yoksa), değişen üçgen sayısı]
static func cut_mesh(mesh: Mesh, box_planes: Array) -> Array:
	var new_mesh := ArrayMesh.new()
	var changed := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in positions.size():
				indices.append(i)
		var present: Array = []
		for attribute in ATTRIBUTES:
			if arrays[attribute] != null and arrays[attribute].size() > 0:
				present.append(attribute)
		var out := {}
		for attribute in present:
			out[attribute] = []
		for t in range(0, indices.size(), 3):
			# Çoğu üçgen hiçbir kutuya değmez: onları olduğu gibi kopyala (hızlı yol)
			var touches := false
			for planes in box_planes:
				if not outside_any(planes, positions[indices[t]], positions[indices[t + 1]], positions[indices[t + 2]]):
					touches = true
					break
			if not touches:
				for k in 3:
					for attribute in present:
						out[attribute].append(read_attribute(arrays[attribute], attribute, indices[t + k]))
				continue
			var polygon: Array = [] # her köşe: {öznitelik: değer}
			for k in 3:
				var vertex := {}
				for attribute in present:
					vertex[attribute] = read_attribute(arrays[attribute], attribute, indices[t + k])
				polygon.append(vertex)
			var pieces: Array = [polygon]
			for planes in box_planes:
				var next: Array = []
				for piece in pieces:
					next.append_array(subtract_box(piece, planes))
				pieces = next
			changed += 1
			for piece in pieces:
				for k in range(1, piece.size() - 1): # yelpaze üçgenleme (dışbükey parça)
					for vertex in [piece[0], piece[k], piece[k + 1]]:
						for attribute in present:
							out[attribute].append(vertex[attribute])
		var new_arrays := []
		new_arrays.resize(Mesh.ARRAY_MAX)
		for attribute in present:
			new_arrays[attribute] = pack_attribute(out[attribute], attribute)
		if out[Mesh.ARRAY_VERTEX].is_empty():
			continue
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
		new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, mesh.surface_get_material(s))
	if changed == 0:
		return [null, 0]
	return [new_mesh, changed]


## Üçgenin üç köşesi de aynı düzlemin dışındaysa üçgen kutuya değmez
static func outside_any(planes: Array, a: Vector3, b: Vector3, c: Vector3) -> bool:
	for plane in planes:
		if plane.distance_to(a) > 1e-5 and plane.distance_to(b) > 1e-5 and plane.distance_to(c) > 1e-5:
			return true
	return false


## Dışbükey çokgenden kutunun içini çıkar: kalan parçalar (her biri dışbükey). Kutu = 6 iç yarı-uzayın kesişimi;
## dışı = her düzlemin dış tarafının (önceki düzlemlerin içinde kalan kısmı) birleşimi.
static func subtract_box(polygon: Array, planes: Array) -> Array:
	# Hızlı ret: bütün köşeler aynı düzlemin dışındaysa çokgen kutuya hiç değmiyor
	for plane in planes:
		var all_out := true
		for vertex in polygon:
			if plane.distance_to(vertex[Mesh.ARRAY_VERTEX]) <= 1e-5:
				all_out = false
				break
		if all_out:
			return [polygon]
	var pieces: Array = []
	var rest := polygon
	for plane in planes:
		var outside := clip(rest, plane, true)
		if outside.size() >= 3:
			pieces.append(outside)
		rest = clip(rest, plane, false)
		if rest.size() < 3:
			break
	return pieces # kalan "rest" kutunun içinde: atılır


## Sutherland–Hodgman: çokgeni düzlemin dış (keep_outside) ya da iç tarafına kırp
static func clip(polygon: Array, plane: Plane, keep_outside: bool) -> Array:
	var result: Array = []
	var count := polygon.size()
	for i in count:
		var a: Dictionary = polygon[i]
		var b: Dictionary = polygon[(i + 1) % count]
		var da := plane.distance_to(a[Mesh.ARRAY_VERTEX])
		var db := plane.distance_to(b[Mesh.ARRAY_VERTEX])
		if not keep_outside:
			da = -da
			db = -db
		var a_in := da >= 0.0 # tutulan tarafta mı
		var b_in := db >= 0.0
		if a_in:
			result.append(a)
		if a_in != b_in:
			var t := da / (da - db)
			result.append(lerp_vertex(a, b, t))
	return result


static func lerp_vertex(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var v := {}
	for attribute in a:
		var x = a[attribute]
		var y = b[attribute]
		if attribute == Mesh.ARRAY_NORMAL:
			v[attribute] = (x as Vector3).lerp(y, t).normalized()
		elif attribute == Mesh.ARRAY_TANGENT:
			var q := (x as Plane)
			var w := (y as Plane)
			var n := q.normal.lerp(w.normal, t).normalized()
			v[attribute] = Plane(n, q.d)
		else:
			v[attribute] = x.lerp(y, t)
	return v


static func read_attribute(array, attribute: int, index: int):
	if attribute == Mesh.ARRAY_TANGENT:
		return Plane(array[index * 4], array[index * 4 + 1], array[index * 4 + 2], array[index * 4 + 3])
	return array[index]


static func pack_attribute(values: Array, attribute: int):
	match attribute:
		Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
			return PackedVector3Array(values)
		Mesh.ARRAY_COLOR:
			return PackedColorArray(values)
		Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2:
			return PackedVector2Array(values)
		Mesh.ARRAY_TANGENT:
			var flat := PackedFloat32Array()
			for p in values:
				flat.append_array([p.normal.x, p.normal.y, p.normal.z, p.d])
			return flat
	return values
