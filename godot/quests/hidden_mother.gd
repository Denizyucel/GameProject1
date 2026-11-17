# Saklanan Anne (yan görev, Harabe Köy). Köyün kuzeybatısında, orman kenarında saklanan dönüştürülmemiş bir kadın:
# kızı Nazlı köy meydanındaki Altın Ölümsüzlerden biri. Act II'deki sınır kasabası sahnesinin küçük bir habercisi
# (Hikaye.md: "kimse teşekkür etmez ama ruhlar ona eşlik eder"). Kadını ve Nazlı'yı main.gd koyar, bu düğüme verir.
# Akış:
#   1. Kadının başında "!" var. Yanına gelince konuşurlar (HUD.talk: konuşma kutusu, oyun durur); "Ona dokunma, en
#      azından yaşıyor!" diye yalvarır. Görev açılır: "Meydanda Nazlı'yı bul". Nazlı'nın başının üstünde adı belirir,
#      küçük haritada çevresinde köz halkası ("gorev_hedefi" grubu).
#   2. Ruh Kıran Nazlı'ya yaklaşınca onu tanır; görev "Nazlı'nın mührünü kır" olur.
#   3. Mührü kırılınca (kim vurursa vursun) ruhu mavi ışıkla yükselir ve fısıldar; görev "Nazlı'nın annesine dön",
#      kadının başında yine "!".
#   4. Kadına dönünce son konuşma: teşekkür etmez, kovar. Görev biter; kadın sırtını döner.
# Nazlı'nın mührü kadınla hiç konuşulmadan kırıldıysa: görev "Nazlı'nın annesini bul" diye açılır, kadınla tek
# (kısa) konuşmada biter.
# Sözleri Claude yazdı; değiştirilebilir.

extends Node

const TALK_RANGE := 2.2 # kadına bu kadar yaklaşınca konuşma başlar
const AWAY := 5.0 # bu kadar uzaklaşıp yeniden gelince kısa sözünü yineler
const SETTLE := 0.25 # konuşmadan önce Ruh Kıran'ın durup beklemeye geçmesi için süre
const SPOT_RANGE := 9.0 # Nazlı'ya bu kadar yaklaşınca Ruh Kıran onu tanır
const TAG_HEIGHT := 2.2 # Nazlı'nın adının ayağından yüksekliği (metre)
const TAG_COLOR := Color(0.78, 0.88, 1.0) # soluk mavi: içeride hâlâ bir ruh var
const TAG_FONT := preload("res://fonts/AguafinaScript-Regular.ttf")
const SOUL_TIME := 5.0 # ruhun fısıltısının ekranda kalma süresi (uzun söz)
const TARGET_GROUP := "gorev_hedefi" # küçük harita bu gruptakileri köz halkasıyla gösterir (hud/minimap.gd)

const QUEST := "anne"
const FIND_TITLE := "Meydanda Nazlı'yı bul"
const BREAK_TITLE := "Nazlı'nın mührünü kır"
const RETURN_TITLE := "Nazlı'nın annesine dön"
const SEEK_TITLE := "Nazlı'nın annesini bul" # kadınla konuşmadan mühür kırıldıysa

const HERO := "Ruh Kıran" # HUD.HERO_NAME ile aynı: adı köz kırmızısı yazılır
const MOTHER := "Kadın"
# Nazlı: meydandaki düşmanlardan biri, ötekilerden ufak (enemy.custom_style; STYLES'taki alanların aynısı)
const DAUGHTER_STYLE := {"name": "Nazlı", "health": 30.0, "damage": 5.0, "size": 0.88, "chase": "walk",
	"chase_speed": 2.0, "attack_speed": 1.1, "cooldown": 0.8, "taunts": false}

const FIRST_TALK := [
	[MOTHER, "Dur! Yaklaşma… Hayır. Sen onlardan değilsin. Gözlerin altın değil."],
	[HERO, "Değilim. Burada tek başına ne yapıyorsun?"],
	[MOTHER, "Saklanıyorum. Altın adam geldiğinde herkes sıraya girdi. Ben kilere indim, nefesimi tuttum."],
	[MOTHER, "Kızım Nazlı inmedi. Şimdi meydanda, ötekilerin arasında. Yürüyor, nefes alıyor… ama bana bakmıyor."],
	[HERO, "O artık yalnızca bir kabuk. Mührü kırılmadıkça ruhu içeride hapis kalır."],
	[MOTHER, "Hayır! Ona dokunma. En azından yaşıyor! Mührünü kırarsan elimde hiçbir şey kalmaz."],
	[HERO, "Söz veremem."],
]
const REPEAT_LINE := "Kadın: «Ona dokunma… ne olur.»"
const SPOT_LINE := "İşte Nazlı. Ötekilerden ufak… İçeride hâlâ biri var."
const SOUL_LINE := "Teşekkür ederim… Anneme söyle, artık üşümüyorum."
const FREED_LINE := "Söyleyeceğim. Dinlemese de."
const FREED_PAUSE := 3.4 # fısıltıdan sonra Ruh Kıran'ın yanıtına kadar (saniye)
const LAST_TALK := [
	[MOTHER, "Meydanda mavi bir ışık gördüm. Göğe çıktı… Onu sen yaptın."],
	[HERO, "Nazlı özgür. Giderken sana bir söz bıraktı: artık üşümüyormuş."],
	[MOTHER, "Üşümüyor… Küçükken hep üşürdü. Geceleri yorganını ben örterdim."],
	[MOTHER, "Ama bana kızımı geri vermedin. Ondan kalan son şeyi de aldın. Git buradan."],
	[HERO, "Gidiyorum. Adını unutmayacağım."],
]
# Nazlı'nın mührü kadınla tanışmadan kırıldıysa
const LATE_TALK := [
	[MOTHER, "Dur! Yaklaşma… Sen onlardan değilsin. Gözlerin altın değil."],
	[MOTHER, "Meydanda mavi bir ışık gördüm. Kızım Nazlı oradaydı, ötekilerin arasında. Ona ne yaptın?"],
	[HERO, "Mührünü kırdım. Artık özgür. Giderken sana bir söz bıraktı: artık üşümüyormuş."],
	[MOTHER, "Üşümüyor… Ama yürüyordu, nefes alıyordu! Ondan kalan son şeyi aldın. Git buradan."],
	[HERO, "Gidiyorum. Adını unutmayacağım."],
]
const END_LINE := "Nazlı. Derimde bir isim daha." # Ruh Kıran unutulanların adını derisine kazır (Hikaye.md)
const DONE_LINE := "Kadın: «Git buradan.»"

var mother: Villager # main.gd verir
var daughter: Node3D # main.gd verir (enemies/enemy.gd); silinmiş olabilir
var talked := false # kadınla ilk konuşma yapıldı
var freed := false # Nazlı'nın mührü kırıldı
var done := false # görev bitti
var spotted := false # Ruh Kıran Nazlı'yı yakından gördü
var near := false # kadının yanında (kısa söz uzaklaşana kadar bir kez)
var busy := false # konuşma sürüyor
var name_tag: Label3D # Nazlı'nın başının üstündeki adı; görev açılınca belirir


func _ready() -> void:
	if mother:
		mother.set_marker(true) # söyleyecek sözü var
	if daughter:
		daughter.seal_broken.connect(on_daughter_freed)


func _process(_delta: float) -> void:
	var main := get_parent()
	var player: Node3D = main.player
	if name_tag and is_instance_valid(daughter):
		name_tag.position.y = daughter.model.position.y + TAG_HEIGHT # köyün zemini engebeli: adı da modelle yükselir
	if busy or not player.alive:
		return
	watch_daughter(player)
	if not is_instance_valid(mother):
		return
	var gap := flat_distance(player.global_position, mother.global_position)
	if gap > AWAY:
		near = false
	if gap > TALK_RANGE or near or player.is_busy():
		return
	near = true
	meet()


## Ruh Kıran kadının yanına geldi: görevin neresindeysek ona göre konuşurlar
func meet() -> void:
	var main := get_parent()
	if done:
		main.hud.say(DONE_LINE)
	elif not freed and talked: # kızı hâlâ meydanda
		main.hud.say(REPEAT_LINE)
	elif not freed: # ilk karşılaşma: kızını anlatır, görev açılır
		busy = true
		talked = true
		await converse(FIRST_TALK)
		main.quests.start(QUEST, FIND_TITLE)
		mother.set_marker(false)
		show_name_tag()
		busy = false
	else: # Nazlı'nın mührü kırıldı: son konuşma, görev biter
		busy = true
		await converse(LAST_TALK if talked else LATE_TALK)
		talked = true
		done = true
		main.quests.start(QUEST, RETURN_TITLE) # hiç açılmadıysa da açılıp bitsin
		main.quests.finish(QUEST)
		mother.set_marker(false)
		if mother.is_in_group(TARGET_GROUP):
			mother.remove_from_group(TARGET_GROUP)
		mother.watches = false # artık Ruh Kıran'a bakmaz; meydana döner
		main.hud.say(END_LINE)
		busy = false


## Görev açıkken Ruh Kıran Nazlı'ya ilk kez yaklaştı mı: onu tanır, görev "mührünü kır" olur
func watch_daughter(player: Node3D) -> void:
	if spotted or freed or not talked or not is_instance_valid(daughter) or not daughter.alive:
		return
	if flat_distance(player.global_position, daughter.global_position) > SPOT_RANGE:
		return
	spotted = true
	var main := get_parent()
	main.quests.retitle(QUEST, BREAK_TITLE)
	main.hud.say(SPOT_LINE)


## Nazlı'nın mührü kırıldı (Ruh Kıran, bir iskelet ya da golem vurmuş olabilir). Mavi ruhu main.on_seal_broken
## gösterir (enemy.soul_rises); burada ruh fısıldar ve görev kadına döner.
func on_daughter_freed(_enemy: Node3D) -> void:
	freed = true
	var main := get_parent()
	if name_tag:
		name_tag.visible = false
	if daughter.is_in_group(TARGET_GROUP):
		daughter.remove_from_group(TARGET_GROUP)
	main.hud.whisper(SOUL_LINE, SOUL_TIME)
	if talked:
		main.quests.retitle(QUEST, RETURN_TITLE)
	else:
		main.quests.start(QUEST, SEEK_TITLE)
	if is_instance_valid(mother):
		mother.set_marker(true)
		mother.add_to_group(TARGET_GROUP)
	await get_tree().create_timer(FREED_PAUSE).timeout
	if not done:
		main.hud.say(FREED_LINE)


## Nazlı'nın başının üstünde adı: Label3D (3B dünyada duran yazı), hep kameraya döner ve evlerin arkasında da görünür
func show_name_tag() -> void:
	if name_tag or not is_instance_valid(daughter) or not daughter.alive:
		return
	name_tag = Label3D.new()
	name_tag.text = DAUGHTER_STYLE["name"]
	name_tag.font = TAG_FONT
	name_tag.font_size = 96
	name_tag.pixel_size = 0.0065
	name_tag.outline_size = 18
	name_tag.modulate = TAG_COLOR
	name_tag.outline_modulate = Color(0.03, 0.05, 0.1)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.no_depth_test = true
	name_tag.position.y = TAG_HEIGHT
	daughter.add_child(name_tag)
	daughter.add_to_group(TARGET_GROUP)


## Ruh Kıran durur, ikisi birbirine döner, oyun durur ve konuşma kutusu açılır. Konuşurken ikisinin bekleme
## animasyonu sürer (yoksa donmuş heykel gibi duruyorlardı). Kutu kapanınca oyun kaldığı yerden devam eder.
func converse(lines: Array) -> void:
	var main := get_parent()
	var player: Node3D = main.player
	player.agent.target_position = player.global_position
	player.holding = false
	player.attack_target = null
	var to_mother := mother.global_position - player.global_position
	player.rotation.y = atan2(to_mother.x, to_mother.z)
	await get_tree().create_timer(SETTLE).timeout
	mother.rotation.y = atan2(-to_mother.x, -to_mother.z)
	get_tree().paused = true
	var speakers: Array[AnimationPlayer] = [player.animation_player, mother.animation_player]
	for speaker in speakers:
		speaker.process_mode = Node.PROCESS_MODE_ALWAYS
	await main.hud.talk(lines)
	for speaker in speakers:
		speaker.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
