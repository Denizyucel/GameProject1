# Gotik binanın içi (kullanıcının kat planları: assets/kit/bina/katlar/bina1-kat-1..2.glb). Diablo'daki gibi ayrı bir iç
# mekân: dört kat haritanın uzağında (x = 200, aralarında 60 m), karanlık boşlukta durur; Gezinme altında olduğu için
# navmesh'e girer. Katlar dışarıdaki binayla aynı yöne dönük (+90°), her katın zemini y = 0'da.
# Geçitler (PORTALS): oyuncu bir geçidin üstüne gelince ekran kararır, karakter (ve iskeletleri) öbür uca taşınır,
# ekran açılır. Noktalar katın kendi (glb) koordinatlarında, zemin yüksekliği hariç: +z kapı yönü.
# Dışarıdan giriş: gothic_door.gd anahtarla açılınca enter() çağırır; kat 0'daki kapıdan çıkınca dışarıda kapının önü.

extends Node3D

const OUTSIDE := Vector3(-24.6, 0, 40) # dışarıda kapının önü (çıkınca buraya)
const TRIGGER := 0.9 # geçidin üstüne bu kadar yaklaşınca
const REARM := 1.6 # bir geçitten gelince, yeniden tetiklenmesi için bu kadar uzaklaşmak gerekir
const FADE := 0.45

# [buradaki kat, buradaki nokta, gidilen kat, varılan nokta]; "disari" = binanın dışı
const PORTALS := [
	["Kat0", Vector2(0.1, 4.9), "disari", Vector2.ZERO], # kapı (navmesh kapının ~1 m gerisinde, z ≈ 4.6'da bitiyor)
]
# Merdivenler: kat -1, 1 ve 2'de odaları ayıran ~1.2 m'lik alçak duvarlarda geçit yok (odalar kapalı, navmesh parça
# parça). Kat planlarına kapı aralıkları eklenince STAIRS'teki geçitler PORTALS'a eklenecek.
const STAIRS := [
	["Kat0", Vector2(3.0, 2.4), "Kat1", Vector2(5.6, 4.4)], # yukarı merdiven
	["Kat0", Vector2(0.0, -2.3), "KatEksi1", Vector2(0.0, -2.2)], # aşağı merdiven (mahzen)
	["Kat1", Vector2(3.0, 5.2), "Kat0", Vector2(3.0, 1.6)], # kat 1'den aşağı
	["Kat1", Vector2(0.0, -2.6), "Kat2", Vector2(0.4, -2.2)], # kat 1'den yukarı
	["Kat2", Vector2(0.0, -3.4), "Kat1", Vector2(0.0, -1.8)], # kat 2'den aşağı
	["KatEksi1", Vector2(0.0, -3.4), "Kat0", Vector2(0.0, -1.5)], # mahzenden yukarı
]
const ENTRY := Vector2(0.1, 3.3) # dışarıdan girince kat 0'da varılan nokta (kapı geçidinden REARM kadar içeride)

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
var armed_from := Vector3.INF # en son varılan nokta; oradan REARM uzaklaşana kadar geçitler beklemede


## Katın kendi koordinatındaki (x, z) noktanın dünyadaki yeri (y = 0)
func floor_point(floor_name: String, local: Vector2) -> Vector3:
	var holder: Node3D = get_node(floor_name)
	var world := holder.global_transform * Vector3(local.x, 0, local.y)
	return Vector3(world.x, 0, world.z)


## Oyuncu iç mekânda mı (dört katın birinde)
func is_inside(point: Vector3) -> bool:
	return point.x > 150.0


func _ready() -> void:
	place_letter()


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
	if armed_from != Vector3.INF:
		if Vector2(here.x - armed_from.x, here.z - armed_from.z).length() < REARM:
			return
		armed_from = Vector3.INF
	for portal in PORTALS:
		var at := floor_point(portal[0], portal[1])
		if Vector2(here.x - at.x, here.z - at.z).length() <= TRIGGER:
			if portal[2] == "disari":
				travel(OUTSIDE, true)
			else:
				travel(floor_point(portal[2], portal[3]))
			return


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
	armed_from = spot
	if leaving:
		# Dışarıda kapının önünde belirdi: kapı, oyuncu uzaklaşana kadar onu yeniden içeri almasın (taşındıktan SONRA:
		# karartma sürerken oyuncu hâlâ içerideyken kapı kendini yeniden hazırlıyordu)
		var door := get_tree().current_scene.get_node_or_null("Gezinme/GotikBina/Kapi")
		if door:
			door.disarm()
	await get_tree().create_timer(0.1).timeout
	await main.hud.fade(0.0, FADE)
	busy = false
