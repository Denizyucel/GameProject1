# Saklanan Anne görevinin tamamını dener (quests/hidden_mother.gd): Nazlı meydanda, ötekilerden ufak; kadınla
# konuşunca görev açılır, Nazlı'nın başında adı ve küçük haritada halkası belirir; yaklaşınca Ruh Kıran onu tanır;
# mührü kırılınca mavi ruh yükselir, fısıldar, görev kadına döner; kadınla son konuşmada görev biter, kadın sırtını
# döner. İkinci kip ("gec"): mühür kadınla konuşmadan kırılır; görev "annesini bul" diye açılır, tek konuşmada biter.
# Görüntüler: nazli-uzak.png, nazli-yakin.png, nazli-ruh.png, anne-son.png, anne-bitti.png.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/mother_quest_test.gd -- <klasör> [gec]

extends SceneTree

var out_dir := ""
var main: Node
var player: Node3D
var hud
var mother
var daughter
var quest


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	var late := args.size() > 1 and args[1] == "gec"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	player = main.get_node("Player")
	await create_timer(1.0).timeout
	hud = main.hud
	mother = main.get_node("Anne")
	quest = main.get_node("SaklananAnne")
	daughter = main.get_node("Dusmanlar/Nazli")
	var map: RID = player.get_world_3d().navigation_map
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await physics_frame
	var enemies := main.get_node("Dusmanlar").get_children()
	var others: Array = enemies.filter(func(e): return e != daughter)
	var smallest: float = others.map(func(e): return e.style["size"]).min()
	print("0. Düşman sayısı %d (16 olmalı: 14 + Nazlı + şampiyon); Nazlı: ad '%s', boy %.2f (ötekilerin en ufağı %.2f), can %d, evi %s, ruhu görünür mü %s, adı başında mı %s (false olmalı)" % [enemies.size(), daughter.style["name"], daughter.style["size"], smallest, daughter.health, daughter.home, daughter.soul_rises, quest.name_tag != null])
	for e in others:
		e.queue_free()
	daughter.set_physics_process(false) # görüntü alırken dolaşmasın, dövüşmesin
	if late:
		await late_run()
	else:
		await full_run()
	quit()


func full_run() -> void:
	# 1. Kadınla ilk konuşma (Esc ile geçilir; kutunun kendisini talk_test deniyor)
	await walk_to_mother()
	print("1. İlk konuşma: %d söz, ilki «%s»" % [hud.talk_lines.size(), hud.talk_lines[0][1]])
	await escape()
	print("   Görevler %s; Nazlı'nın adı başında mı %s, haritada hedef mi %s; kadının işareti %s (false olmalı)" % [main.quests.lines(), quest.name_tag != null and quest.name_tag.visible, daughter.is_in_group("gorev_hedefi"), mother.marker.visible])

	# 2. Uzaktan Nazlı: adı görünür, henüz tanınmadı; yaklaşınca tanır
	player.global_position = Vector3(3, 0, 66)
	player.agent.target_position = player.global_position
	await create_timer(1.2).timeout
	print("2. 11 m'den: tanıdı mı %s (false olmalı); adın yüksekliği %.2f (zemin %.2f)" % [quest.spotted, quest.name_tag.position.y, Terrain.height_at(daughter.global_position)])
	await shot("nazli-uzak.png")
	player.agent.target_position = Vector3(2, 0, 71)
	var waited := 0.0
	while not quest.spotted and waited < 6.0:
		await create_timer(0.1).timeout
		waited += 0.1
	await create_timer(0.5).timeout
	print("   Yaklaşınca: tanıdı mı %s (%.1f sn, Nazlı'ya %.1f m), alt yazı '%s', görevler %s" % [quest.spotted, waited, flat(player.global_position, daughter.global_position), hud.say_label.text, main.quests.lines()])
	await create_timer(1.0).timeout
	await shot("nazli-yakin.png")

	# 3. Mührü kırılır: mavi ruh, fısıltı, görev kadına döner
	await break_seal()
	print("3. Mühür kırıldı: freed %s, fısıltı '%s', görevler %s" % [quest.freed, hud.whisper_label.text, main.quests.lines()])
	print("   Kadının işareti %s (true olmalı), haritada hedef kadın mı %s, Nazlı'nın adı görünür mü %s (false olmalı), efekt ruhlu mu %s" % [mother.marker.visible, mother.is_in_group("gorev_hedefi"), quest.name_tag.visible, soul_effect()])
	await create_timer(0.9).timeout
	await shot("nazli-ruh.png")
	await create_timer(3.0).timeout
	print("   %.1f sn sonra alt yazı '%s'" % [quest.FREED_PAUSE, hud.say_label.text])

	# 4. Kadına dönüş: son konuşma, görev biter, kadın sırtını döner
	await walk_to_mother()
	print("4. Son konuşma: %d söz, ilki «%s»" % [hud.talk_lines.size(), hud.talk_lines[0][1]])
	await create_timer(1.6, true).timeout
	await shot("anne-son.png")
	await escape()
	print("   Görevler %s; işaret %s (false olmalı), hedef mi %s (false olmalı), bakıyor mu %s (false olmalı), alt yazı '%s'" % [main.quests.lines(), mother.marker.visible, mother.is_in_group("gorev_hedefi"), mother.watches, hud.say_label.text])
	await create_timer(2.5).timeout
	print("   Kadın ilk baktığı yöne döndü mü: %s (fark %.2f rad)" % [absf(angle_difference(mother.rotation.y, mother.home_turn)) < 0.1, angle_difference(mother.rotation.y, mother.home_turn)])
	await shot("anne-bitti.png")

	# 5. Uzaklaş, geri gel: kutu açılmaz, kısa söz
	player.agent.target_position = mother.global_position + Vector3(7, 0, 1)
	await create_timer(3.5).timeout
	player.agent.target_position = mother.global_position
	await create_timer(3.5).timeout
	print("5. Bittikten sonra gelince: kutu açık mı %s (false olmalı), alt yazı '%s'" % [hud.talk_open, hud.say_label.text])


func late_run() -> void:
	# Kadınla hiç konuşmadan mühür kırılır
	player.global_position = Vector3(2, 0, 71)
	player.agent.target_position = player.global_position
	await create_timer(0.8).timeout
	print("G1. Konuşmadan yaklaşınca: tanıdı mı %s (false olmalı), görevler %s" % [quest.spotted, main.quests.lines()])
	await break_seal()
	print("G2. Mühür kırıldı: fısıltı '%s', görevler %s, kadının işareti %s (true olmalı)" % [hud.whisper_label.text, main.quests.lines(), mother.marker.visible])
	await create_timer(1.0).timeout
	await walk_to_mother()
	print("G3. Kadınla tek konuşma: %d söz, ikincisi «%s»" % [hud.talk_lines.size(), hud.talk_lines[1][1]])
	await escape()
	print("    Görevler %s; işaret %s (false olmalı), alt yazı '%s'" % [main.quests.lines(), mother.marker.visible, hud.say_label.text])


## Oyuncuyu kadının 6 m yanına koy, ona yürüt; konuşma kutusu açılana kadar bekle
func walk_to_mother() -> void:
	player.global_position = mother.global_position + Vector3(6, 0, 1)
	player.agent.target_position = mother.global_position
	var waited := 0.0
	while not hud.talk_open and waited < 8.0:
		await create_timer(0.1, true).timeout
		waited += 0.1
	if not hud.talk_open:
		print("   KUTU AÇILMADI (oyuncu %s)" % player.global_position)
	await create_timer(0.3, true).timeout


func escape() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.6, true).timeout


func break_seal() -> void:
	daughter.set_physics_process(true) # ölüm animasyonu ve ceset için
	daughter.hit(player.global_position, 999.0)
	await create_timer(0.2).timeout


## Sahnedeki mühür kırma efektlerinden ruhlu olan var mı
func soul_effect() -> bool:
	for child in main.get_children():
		if "with_soul" in child and child.with_soul and not child.release:
			return true
	return false


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/" + file)
