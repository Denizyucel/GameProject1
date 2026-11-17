# Küçük harita (sağ üst köşe, Diablo tarzı sade çizim). Dünyayı ikinci bir kamerayla yeniden çizmez: açılışta
# navmesh'in yürünebilir alanı bir kez bir resme (METRE_PX piksel/metre) dökülür; her karede bu resim, karakter
# ortada kalacak ve ekrandaki izometrik açıyla aynı yöne bakacak şekilde yuvarlak bir pencereye çizilir.
# Üstünde: oyuncu (köz kırmızısı ok, baktığı yöne), düşmanlar (altın), iskeletler (kemik beyazı), köylüler (soluk mavi), alınmamış
# isim sayfaları (köz noktası), görev hedefleri ("gorev_hedefi" grubu: köz halkası, uzaktaysa kenarda). Boyut ve yer hud.tscn'de (Harita).

extends Control

const METRE_PX := 4.0 # resimde metre başına piksel
const VIEW_METRES := 44.0 # haritanın çapı kaç metreyi gösterir
const BORDER := Color(0.42, 0.33, 0.2, 1) # can barı çerçevesiyle aynı bronz
const BACKGROUND := Color(0.04, 0.03, 0.05, 0.72)
const WALKABLE := Color(0.48, 0.41, 0.34, 0.62)
const PLAYER := Color(1.0, 0.38, 0.18)
const ENEMY := Color(1.0, 0.8, 0.35)
const MINION := Color(0.9, 0.88, 0.8)
const PAGE := Color(1.0, 0.3, 0.1)
const VILLAGER := Color(0.6, 0.82, 1.0) # köylüler (konuşulabilen karakterler): soluk mavi
const TARGET := Color(1.0, 0.45, 0.2) # görev hedefi ("gorev_hedefi" grubu): nabız atan köz halkası
const SEGMENTS := 64

var map_texture: ImageTexture
var map_origin := Vector2.ZERO # resmin sol üst köşesinin dünyadaki (x, z) yeri
var player: Node3D
var camera: Camera3D


## Navmesh'in yürünebilir çokgenlerini bir resme dök (main.gd navmesh hazır olunca çağırır)
func build(navigation_mesh: NavigationMesh, region_transform: Transform3D) -> void:
	var vertices := navigation_mesh.get_vertices()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var flat: Array[Vector2] = []
	for v in vertices:
		var world := region_transform * v
		var p := Vector2(world.x, world.z)
		flat.append(p)
		low = low.min(p)
		high = high.max(p)
	map_origin = low - Vector2.ONE * 2.0
	var size := Vector2i(((high - low + Vector2.ONE * 4.0) * METRE_PX).ceil())
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for i in navigation_mesh.get_polygon_count():
		var indices := navigation_mesh.get_polygon(i)
		var polygon := PackedVector2Array()
		for index in indices:
			polygon.append((flat[index] - map_origin) * METRE_PX)
		var box := Rect2(polygon[0], Vector2.ZERO)
		for p in polygon:
			box = box.expand(p)
		for y in range(int(box.position.y), int(ceil(box.end.y)) + 1):
			for x in range(int(box.position.x), int(ceil(box.end.x)) + 1):
				if x < 0 or y < 0 or x >= size.x or y >= size.y:
					continue
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), polygon):
					image.set_pixel(x, y, WALKABLE)
	map_texture = ImageTexture.create_from_image(image)


func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("oyuncu")
	camera = get_viewport().get_camera_3d()
	queue_redraw()


## Dünyadaki (x, z) noktasının haritadaki yeri. Ekranın sağı = kameranın sağı, ekranın yukarısı = kameranın baktığı yön
func to_map(world: Vector3) -> Vector2:
	var center := size * 0.5
	var scale := size.x / VIEW_METRES
	var offset := Vector2(world.x - player.global_position.x, world.z - player.global_position.z)
	var right := Vector2(camera.global_basis.x.x, camera.global_basis.x.z).normalized()
	var forward := Vector2(-camera.global_basis.z.x, -camera.global_basis.z.z).normalized()
	return center + Vector2(offset.dot(right), -offset.dot(forward)) * scale


func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.5
	draw_circle(center, radius, BACKGROUND)
	if player and camera and map_texture:
		# Yuvarlak pencere: çember çokgeninin her köşesine resmin karşılık gelen noktası (UV) verilir
		var right := Vector2(camera.global_basis.x.x, camera.global_basis.x.z).normalized()
		var forward := Vector2(-camera.global_basis.z.x, -camera.global_basis.z.z).normalized()
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		var texture_size := Vector2(map_texture.get_size())
		var here := Vector2(player.global_position.x, player.global_position.z)
		for i in SEGMENTS:
			var angle := TAU * i / SEGMENTS
			var on_screen := Vector2(cos(angle), sin(angle)) * (radius - 2.0)
			points.append(center + on_screen)
			var metres := on_screen / (size.x / VIEW_METRES) # ekrandaki kayma → metre (sağ, aşağı)
			var world := here + right * metres.x - forward * metres.y
			uvs.append((world - map_origin) * METRE_PX / texture_size)
		draw_colored_polygon(points, Color.WHITE, uvs, map_texture)
		draw_markers(radius)
	draw_arc(center, radius - 1.0, 0, TAU, SEGMENTS, BORDER, 3.0, true)


func draw_markers(radius: float) -> void:
	var center := size * 0.5
	var limit := radius - 5.0
	for page in get_tree().get_nodes_in_group("isim_sayfasi"):
		if not page.taken:
			draw_dot(to_map(page.global_position), limit, PAGE, 3.0 + sin(Time.get_ticks_msec() / 250.0))
	for villager in get_tree().get_nodes_in_group("koylu"):
		draw_dot(to_map(villager.global_position), limit, VILLAGER, 3.0)
	for minion in get_tree().get_nodes_in_group("iskelet"):
		draw_dot(to_map(minion.global_position), limit, MINION, 2.5)
	for enemy in get_tree().get_nodes_in_group("dusman"):
		draw_dot(to_map(enemy.global_position), limit, ENEMY, 3.0)
	# Görev hedefleri: noktanın çevresinde nabız atan halka; harita dışındaysa o yönde, kenarda durur (yön gösterir)
	for target in get_tree().get_nodes_in_group("gorev_hedefi"):
		var at := to_map(target.global_position)
		if at.distance_to(center) > limit:
			at = center + (at - center).normalized() * limit
		draw_arc(at, 5.5 + sin(Time.get_ticks_msec() / 250.0), 0, TAU, 24, TARGET, 1.5, true)
	# Oyuncu: baktığı yöne dönük küçük bir ok
	var facing3 := player.global_basis.z # model +z'ye bakıyor
	var tip := to_map(player.global_position + Vector3(facing3.x, 0, facing3.z).normalized() * 1.0) - center
	var ahead := tip.normalized() if tip.length() > 0.01 else Vector2.UP
	var side := Vector2(-ahead.y, ahead.x)
	draw_colored_polygon(PackedVector2Array([center + ahead * 7.0, center - ahead * 4.0 + side * 4.5, center - ahead * 2.0, center - ahead * 4.0 - side * 4.5]), PLAYER)


func draw_dot(at: Vector2, limit: float, color: Color, dot_radius: float) -> void:
	if at.distance_to(size * 0.5) <= limit:
		draw_circle(at, dot_radius, color)
