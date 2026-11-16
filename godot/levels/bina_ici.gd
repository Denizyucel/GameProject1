# Gotik binanın içi (kullanıcının kat planları: assets/kit/bina/katlar/bina1-kat-1..2.glb). Diablo'daki gibi ayrı bir iç
# mekân: dört kat haritanın uzağında (x = 200, aralarında 60 m), karanlık boşlukta durur; Gezinme altında olduğu için
# navmesh'e girer. Katlar dışarıdaki binayla aynı yöne dönük (+90°), her katın zemini y = 0'da.
# Geçitler (PORTALS): oyuncu bir geçidin üstüne gelince ekran kararır, karakter (ve iskeletleri) öbür uca taşınır,
# ekran açılır. Noktalar katın kendi (glb) koordinatlarında, zemin yüksekliği hariç: +z kapı yönü.
# Dışarıdan giriş: gothic_door.gd anahtarla açılınca enter() çağırır; kat 0'daki kapıdan çıkınca dışarıda kapının önü.

extends Node3D

const BUILDING_WINDOW := preload("res://levels/building_window.gd")

const OUTSIDE := Vector3(-24.6, 0, 40) # dışarıda kapının önü (çıkınca buraya)
const TRIGGER := 0.9 # geçidin üstüne bu kadar yaklaşınca
const REARM_MARGIN := 0.3 # bir geçitten gelince geçitler, oyuncu hepsinden TRIGGER + bu kadar uzaklaşınca yeniden çalışır
const FADE := 0.45

# [buradaki kat, buradaki nokta, gidilen kat, varılan nokta]; "disari" = binanın dışı
const PORTALS := [
	["Kat0", Vector2(0.1, 4.9), "disari", Vector2.ZERO], # kapı (navmesh kapının ~1 m gerisinde, z ≈ 4.6'da bitiyor)
	["Kat0", Vector2(3.0, 2.4), "Kat1", Vector2(0.4, 4.4)], # yukarı merdiven (sağ önde) → kat 1'in sol alt odası
	["Kat0", Vector2(0.0, -2.3), "KatEksi1", Vector2(0.0, -2.2)], # aşağı merdiven (arka ortada) → mahzen koridoru
	# Kat 1'in aşağı merdiven "odası" çoğunlukla merdiven boşluğu: iniş noktası sol alt odadan açılan geçidin içinde
	["Kat1", Vector2(2.0, 4.5), "Kat0", Vector2(3.0, 1.2)], # kat 1'den aşağı
	["Kat1", Vector2(-1.1, -3.9), "Kat2", Vector2(0.4, -2.2)], # kat 1'den yukarı (sol üst odada merdivenin sol dibi)
	["Kat2", Vector2(0.0, -3.4), "Kat1", Vector2(-2.6, -4.2)], # kat 2'den aşağı
	["KatEksi1", Vector2(0.0, -3.4), "Kat0", Vector2(0.0, -1.1)], # mahzenden yukarı
]

# Kat planlarında odaları ayıran ~1.2 m'lik alçak duvarlarda geçit yoktu (kullanıcı kodla açılmasını istedi): her biri
# 1.5 m genişlik, yerden itibaren boş, önü boş, her oda merdivenin olduğu odaya bağlı. [x, z, duvarın yönü]
# (katın kendi koordinatında; "x" = duvar x boyunca uzanır, "z" = z boyunca). WallCutter oyun açılınca keser;
# navmesh de kesilmiş halinden çıkar (tools/bake_navmesh.gd). Kat planı güncellenirse yerleri gözden geçir.
const GAP_WIDTH := 1.5
const GAP_DEPTH := 0.75 # duvarın iki yanına (duvar + süs çıkıntıları + dip pervazı; 0.45 yetmiyordu)
const GAP_HEIGHT := 2.6
const CLEAR_REACH := 1.6 # geçidin iki yanında bu kadar mesafedeki eşyalar (fıçı, sandık, mum...) bütün olarak kaldırılır
const FLOOR_HEIGHTS := {"KatEksi1": 0.0, "Kat0": 0.5, "Kat1": 4.1, "Kat2": 7.7} # glb'de zeminin yüksekliği
const GAPS := {
	"KatEksi1": [
		[-1.6, -1.5, "z"], [1.5, -1.5, "z"], # merdiven koridorundan sol ve sağ büyük odalara
		[-4.0, -3.0, "x"], [6.3, -3.0, "x"], # büyük odalardan üstteki odalara
		[-0.1, 0.0, "x"], [0.0, 3.0, "x"], # koridordan ortadaki küçük odaya, oradan sol alt odaya
		[3.0, 3.0, "x"], # sağ büyük odadan sağ alt odaya
	],
	"Kat1": [
		[-1.35, -3.0, "x"], # depodan yukarı merdivenin olduğu sol üst odaya (merdivenin solu: merdiven x -0.6'dan başlar)
		[1.5, -1.6, "z"], # depodan kitaplığa
		[-0.2, 3.0, "x"], # depodan sol alt odaya
		[1.5, 4.5, "z"], # sol alt odadan aşağı merdivenin odasına
	],
	"Kat2": [
		[-1.6, -1.9, "z"], [4.5, -4.0, "z"], # merdivenin olduğu üst ortadan sol ve sağ üst odalara
		[-4.2, 0.0, "x"], # sol üstten sol alta
		[-1.6, 1.9, "z"], # sol alttan depoya
		[5.9, 0.0, "x"], # sağ üstten sağ alta
	],
}
# Yolu kesen tek tek eşyalar (bütün olarak kaldırılır): [x, z, genişlik x, derinlik z]
const CLEARS := {
	"KatEksi1": [
		[0.0, 1.5, 1.0, 1.0], # ortadaki küçük odanın ortasındaki kaide (iki yandaki geçişleri kapatıyordu)
		[4.0, -1.5, 1.6, 1.4], # sağ büyük odayı ikiye bölen eşyalar (şerit)
		[5.6, -2.0, 1.6, 1.2], # sağ büyük odadan sağ üst odanın geçidine giden şerit
	],
	"Kat2": [
		[2.2, -2.5, 1.0, 2.2], # üst ortadaki odanın sağ yarısına geçişi kesen sandık ve küçük eşya
		[0.95, -2.27, 1.1, 1.1], # sol yarıyla sağ yarı arasındaki kazan (masalarla arasında 0.4-0.6 m kalıyordu)
		[2.6, -4.6, 0.9, 0.9], # sağ üst odanın geçidinin önündeki yuvarlak eşya
		[5.3, -4.0, 1.4, 1.5], # sağ üst odada geçidin hemen içi (dekor dahil)
		[5.4, -2.15, 0.9, 1.9], # sağ üst odada iki dolap arası 0.5 m kalıyordu: soldaki dolap (sağ alta inen yol)
	],
}
const ENTRY := Vector2(0.1, 3.3) # dışarıdan girince kat 0'da varılan nokta (kapı geçidinin dışında)

# X'in mektubu (gotik kapı görevinin sonu): şimdilik kat 0'da, kitaplığın yanında (öbür katlara henüz geçilemiyor).
# Alınınca ekran kararır, oyun durur, mektup okunur; kapanınca görev biter, ödül: kırık gümüş mühür (en fazla mana +20).
# Mektubu Claude yazdı; değiştirilebilir.
const LETTER_FLOOR := "Kat0"
const LETTER_AT := Vector2(3.8, -4.4)
const NOTE_TITLE := "Yarım kalan bir mektup" # (Aguafina'da "ş" yok: başlıkta "ş" kullanma)
const NOTE_TEXT := """Abim,

Onun son gecesinde ellerini tuttum. Sen «vakti geldi» dedin, ben «henüz değil». Acısını dindiremedim; sen ise onu uğurlamaya hazırdın.

Mühürleri ters çevirdim. Artık kimse gitmek zorunda kalmayacak, kimse arkasında ağlayan birini bırakmayacak.

Anlamayacağını biliyorum. Ama bir gün, sen de yorulduğunda, bana teşekkür edeceksin.

— X"""
const REWARD_MANA := 20.0
const REWARD_LINE := "Mektubun altında kırık bir gümüş mühür… onun çaldıklarından biri. Elimde hâlâ ılık."

var busy := false
var armed := true # geçitler çalışıyor mu (bir geçitten gelince oyuncu hepsinin dışına çıkana kadar false)


## Katın kendi koordinatındaki (x, z) noktanın dünyadaki yeri (y = 0)
func floor_point(floor_name: String, local: Vector2) -> Vector3:
	var holder: Node3D = get_node(floor_name)
	var world := holder.global_transform * Vector3(local.x, 0, local.y)
	return Vector3(world.x, 0, world.z)


## Oyuncu iç mekânda mı (dört katın birinde)
func is_inside(point: Vector3) -> bool:
	return point.x > 150.0


func _ready() -> void:
	cut_gaps()
	add_windows()
	place_letter()


## Her kata görüş penceresi (gotik binanın dışındaki gibi, levels/building_window.gd): kameraya yakın tam boy dış
## duvarlar öndeki odaları ve karakteri kapatıyordu; karakterin önünde kalan kısım noktalı silinir. Geçitler kesildikten
## SONRA kurulur (pencere, mesh'lerin o anki malzemelerini kendi shader'ına çevirir).
func add_windows() -> void:
	for floor_name in FLOOR_HEIGHTS:
		var window := Node3D.new()
		window.name = "Pencere"
		window.set_script(BUILDING_WINDOW)
		window.building = get_node(floor_name).get_node("Model")
		get_node(floor_name).add_child(window)


## Alçak duvarlara geçitleri aç (GAPS)
func cut_gaps() -> void:
	for floor_name in GAPS:
		var model: Node3D = get_node(floor_name).get_node("Model")
		var floor_y: float = FLOOR_HEIGHTS[floor_name]
		var boxes: Array[AABB] = []
		var fronts: Array[AABB] = []
		for gap in GAPS[floor_name]:
			boxes.append(gap_box(gap, floor_y, GAP_DEPTH))
			fronts.append(gap_box(gap, floor_y, CLEAR_REACH))
		# Önce geçidin iki yanındaki eşyaları bütün olarak kaldır (önü boş olsun), sonra duvarı kes
		WallCutter.clear(model, fronts, ["gothic_stone", "floor"])
		var singles: Array[AABB] = []
		for c in CLEARS.get(floor_name, []):
			singles.append(AABB(Vector3(c[0] - c[2] * 0.5, floor_y + 0.03, c[1] - c[3] * 0.5), Vector3(c[2], GAP_HEIGHT, c[3])))
		if not singles.is_empty():
			WallCutter.clear(model, singles, ["floor"])
		WallCutter.cut(model, boxes)


## Geçidin kutusu (katın uzayında): genişlik GAP_WIDTH, duvarın iki yanına depth
func gap_box(gap: Array, floor_y: float, depth: float) -> AABB:
	var size := Vector3(GAP_WIDTH, GAP_HEIGHT, depth * 2.0) if gap[2] == "x" else Vector3(depth * 2.0, GAP_HEIGHT, GAP_WIDTH)
	return AABB(Vector3(gap[0], floor_y + 0.03, gap[1]) - Vector3(size.x * 0.5, 0, size.z * 0.5), size)


## Mektubu kat 2'ye koy (navmesh dolana kadar bekler: ilk karelerde sorgular (0, 0, 0) döner)
func place_letter() -> void:
	var map := get_world_3d().navigation_map
	var at := floor_point(LETTER_FLOOR, LETTER_AT)
	while NavigationServer3D.map_get_closest_point(map, at).is_zero_approx():
		await get_tree().physics_frame
	var walkable := NavigationServer3D.map_get_closest_point_to_segment(map, at + Vector3.UP * 3.0, at + Vector3.DOWN * 2.0)
	var letter := NamePage.new()
	letter.name = "Mektup"
	letter.person = "X"
	letter.position = Vector3(walkable.x, 0, walkable.z)
	add_child(letter)
	letter.picked.connect(func(_page): read_letter())


## Mektup alındı: karart, oyunu durdur, oku; kapanınca görev biter ve ödül
func read_letter() -> void:
	busy = true
	var main := get_tree().current_scene
	await main.hud.fade(1.0, 0.6)
	get_tree().paused = true
	main.hud.show_note(NOTE_TITLE, NOTE_TEXT)
	await main.hud.note_closed
	get_tree().paused = false
	await main.hud.fade(0.0, 0.6)
	main.quests.start(main.DOOR_QUEST, main.DOOR_TITLE) # kapıdan girmeden (denemede) alınırsa da görev bitsin
	main.quests.finish(main.DOOR_QUEST)
	(get_tree().get_first_node_in_group("oyuncu")).raise_max_mana(REWARD_MANA)
	main.hud.say(REWARD_LINE)
	busy = false


## Dışarıdan içeri gir (gothic_door.gd çağırır)
func enter() -> void:
	await travel(floor_point("Kat0", ENTRY))


func _process(_delta: float) -> void:
	if busy:
		return
	var player := get_tree().get_first_node_in_group("oyuncu") as Node3D
	if player == null or not player.alive or not is_inside(player.global_position):
		return
	var here := player.global_position
	# Bir geçitten gelince geçitler, oyuncu hepsinin dışına (TRIGGER + REARM_MARGIN) bir kez çıkana kadar beklemede
	var nearest := INF
	var hit: Array = []
	for portal in PORTALS:
		var at := floor_point(portal[0], portal[1])
		var gap := Vector2(here.x - at.x, here.z - at.z).length()
		nearest = minf(nearest, gap)
		if gap <= TRIGGER and hit.is_empty():
			hit = portal
	if not armed:
		if nearest > TRIGGER + REARM_MARGIN:
			armed = true
		return
	if not hit.is_empty():
		if hit[2] == "disari":
			travel(OUTSIDE, true)
		else:
			travel(floor_point(hit[2], hit[3]))


## Ekranı karart, oyuncuyu (ve iskeletlerini) taşı, ekranı aç
func travel(to: Vector3, leaving := false) -> void:
	busy = true
	var main := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("oyuncu") as Node3D
	await main.hud.fade(1.0, FADE)
	var map := get_world_3d().navigation_map
	var landing := NavigationServer3D.map_get_closest_point_to_segment(map, to + Vector3.UP * 3.0, to + Vector3.DOWN * 2.0)
	var spot := Vector3(landing.x, 0, landing.z)
	var offset := spot - player.global_position
	player.global_position = spot
	player.agent.target_position = spot
	player.attack_target = null
	player.holding = false
	for minion in get_tree().get_nodes_in_group("iskelet"):
		(minion as Node3D).global_position += offset # iskeletler de aynı yere, aynı dizilişle
		minion.agent.target_position = minion.global_position
	var camera := get_viewport().get_camera_3d()
	if "focus" in camera:
		camera.focus = Terrain.on_ground(spot) # kamera kaymadan yeni yerde başlasın
	armed = false
	if leaving:
		# Dışarıda kapının önünde belirdi: kapı, oyuncu uzaklaşana kadar onu yeniden içeri almasın (taşındıktan SONRA:
		# karartma sürerken oyuncu hâlâ içerideyken kapı kendini yeniden hazırlıyordu)
		var door := get_tree().current_scene.get_node_or_null("Gezinme/GotikBina/Kapi")
		if door:
			door.disarm()
	await get_tree().create_timer(0.1).timeout
	await main.hud.fade(0.0, FADE)
	busy = false
