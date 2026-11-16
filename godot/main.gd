# Ana sahne: oyunun parçalarını birbirine bağlar (Hikaye.md, çekirdek döngü).
#   - Düşmanın mührü kırılınca (canı bitince): mühür kırma efekti ve "Teşekkür ederiz…" fısıltısı
#   - Bedeni gömülünce: yerinde ceset (et yığını); ara sıra can iksiri de düşer (alınınca can verir)
#   - 1 tuşu: oyuncu 8 m içindeki en yakın cesede büyü yapar; büyünün yarısında cesetten iskelet kalkar
#   - Harita tek parça: Yanık Kütüphane (düşmansız), güneyinde Kül Yolu, onun güneyinde Harabe Köy.
#     Düşmanlar ENEMY_SPAWNS'taki yerlere kodla konur.
#   - Kütüphane yanıyor: açılışta X'in tutuşturduğu raflar oyunda da yanmaya devam eder
#   - En fazla 5 iskelet: sınır doluyken yenisi kalkarsa rastgele biri ruhunu serbest bırakıp yok olur

class_name MainScene
extends Node3D

## Açılış ara sahnesinden gelindiyse true: Ruh Kıran kapıdan yürüyerek girer
static var after_intro := false

const SEAL_BREAK := preload("res://effects/seal_break.tscn")
const FIRE := preload("res://effects/fire.tscn")
# Açılışta X'in kıvılcımlarının tutuşturduğu raflar (en yakından uzağa); oyunda da yanmaya devam ederler
const FIRE_POINTS := [
	Vector3(-4, 0.4, -12.3), Vector3(4, 0.4, -12.3), Vector3(-7.5, 0.3, -8.5), Vector3(7.5, 0.3, -7.5),
	Vector3(-8, 0.4, -12.3), Vector3(8, 0.4, -12.3), Vector3(-7.5, 0.3, -6), Vector3(7.5, 0.3, -4.5),
	Vector3(-7.5, 0.3, -2), Vector3(7.5, 0.3, 1),
]
const ENEMY := preload("res://enemies/enemy.tscn")
const CORPSE := preload("res://minions/corpse.tscn")
const MINION := preload("res://minions/minion.tscn")
const POTION := preload("res://items/health_potion.tscn")
const CROWD := preload("res://characters/crowd.gd")
const NAME_PAGE := preload("res://items/name_page.gd")
const QUEST_LOG := preload("res://quests/quest_log.gd") # karakterler birbirinin içinden geçmesin
const POTION_CHANCE := 0.2 # ölen düşmanın can iksiri düşürme olasılığı (0..1)
const POTION_GAP := 2 # bir iksir düştükten sonra en az bu kadar ölümde iksir düşmez (art arda gelmesin)
const POTION_DISTANCE := 1.0 # iksir cesedin bu kadar yanına düşer (üstüne değil)
# Düşmanların yerleri (evleri; Hikaye.md): Kül Yolu'nda önce tek devriye, sonra iki;
# Harabe Köy'de 3, 4 ve 5'lik gruplar (köy girişi, meydan, batıdaki yokuş)
const ENEMY_SPAWNS := [
	Vector3(0.5, 0, 36), Vector3(-1.5, 0, 48), Vector3(2, 0, 50),
	Vector3(2, 0, 67), Vector3(5, 0, 68.5), Vector3(0, 0, 70.5),
	Vector3(0, 0, 75), Vector3(4, 0, 74.5), Vector3(2, 0, 77.5), Vector3(7, 0, 76.5),
	Vector3(-10, 0, 75.5), Vector3(-8, 0, 77.5), Vector3(-10, 0, 85), Vector3(-8, 0, 85.5), Vector3(-6.5, 0, 84.5),
]
# Unutulan İsimler (yan görev): kütüphanenin yangınından kalan 5 yanık kayıt sayfası. Hepsi bulununca en fazla can +10.
const NAME_PAGES := [
	{"at": Vector3(-7, 0, -10), "person": "Mira, ebe", "line": "«Kızımın doğumunu görmeden gitmem.» Gördü, sonra gitti."},
	{"at": Vector3(7, 0, -3), "person": "Ela, yedi yaşında", "line": "«Karanlıkta yanımda kalır mısın?» Kaldım."},
	{"at": Vector3(12, 0, 12), "person": "Değirmenci Ferhan", "line": "«Unutulmaktan korkuyorum.» Unutmadım."},
	{"at": Vector3(-8, 0, 30), "person": "Taşçı Oruç", "line": "«Duvarımı bitiremedim.» Duvarı hâlâ yolun kenarında duruyor."},
	{"at": Vector3(9, 0, 52), "person": "Adı yanmış", "line": "Tek satır kalmış: «Kardeşine iyi bak.»"},
]
# Altın Şampiyon (yan görev, zincir): Kül Yolu'nda gotik binaya giden patikanın yakınında tek, güçlü düşman. Oyuncu
# yaklaşınca görev açılır; mührü kırılınca altın anahtar düşer, anahtar alınınca kapı görevi başlar (gotik bina).
const CHAMPION_AT := Vector3(-11, 0, 46)
const CHAMPION_NOTICE := 14.0 # oyuncu bu kadar yaklaşınca görev açılır
const CHAMPION_QUEST := "sampiyon"
const CHAMPION_TITLE := "Altın Şampiyon'un mührünü kır"
const CHAMPION_SEEN_LINE := "Bu ötekilerden farklı. Altın onu daha sıkı sarmış."
const CHAMPION_DOWN_LINE := "Mührünün içinde bir şey vardı… bir anahtar."
const DOOR_QUEST := "kapi"
const DOOR_TITLE := "Altın anahtarı gotik binanın kapısına götür"
const KEY_LINE := "X'in altını. Batıdaki o kapalı binanın kapısına uyabilir."
const GOLDEN_KEY := preload("res://items/golden_key.gd")
# Saklanan Anne (yan görev): Harabe Köy'de evlerin arkasına saklanmış, dönüştürülmemiş bir kadın. Kızı köydeki Altın
# Ölümsüzlerden biri. Şimdilik yalnızca durur (konuşma ve görev sonra).
const VILLAGER := preload("res://npcs/villager.tscn")
const MOTHER_AT := Vector3(-8, 0, 61) # köyün kuzeybatısında, orman kenarında büyük kayanın yanı; köye girmeden görülür
# Kemik golemi (yan görev zincirinin sonu): X'in mektubu okununca görev açılır; gotik binanın mahzenindeki rün
# halkasına inilince golem ilk kez kalkar (levels/bina_ici.gd → awaken_golem) ve 2 tuşuyla çağırma hakkı kazanılır.
# Aynı anda tek golem; iskeletlerin 5'lik sınırından ayrı. Canı bitince ruhu serbest kalır; hak kaybolmaz, 20 sn
# bekledikten sonra yeniden çağrılabilir. Durumu HUD'da alt ortadaki beceri çubuğunda (hud/skill_bar.gd).
const GOLEM := preload("res://minions/golem.tscn")
const GOLEM_KEYS := [KEY_2, KEY_KP_2] # üst sıradaki 2 ve sayı tuş takımındaki 2
const GOLEM_MANA := 50.0
const GOLEM_DISTANCE := 2.0 # oyuncunun bu kadar önünde kalkar
const GOLEM_QUEST := "golem"
const GOLEM_TITLE := "Mahzendeki rün halkasına in"
const GOLEM_LINE := "Yüzlerce kemik, tek beden. Kimse onları zorlamadı; kendileri kalktı."
const GOLEM_HINT := "Yeni büyü: Kemik Golemi (2 tuşu)"
const GOLEM_HERE_LINE := "Golem zaten ayakta."
const GOLEM_COOLDOWN := 20.0 # golemin canı bitince yeniden çağırmak için beklenen süre (saniye)
const GOLEM_WAIT_LINE := "Kemikler henüz toplanmadı."
const NAMES_QUEST := "isimler"
const NAMES_TITLE := "Unutulan İsimler"
const NAMES_REWARD := 10.0 # hepsi bulununca en fazla cana eklenir
const NAMES_DONE_LINE := "Beş isim daha. Derimde hâlâ yer var."
const ENTER_FROM := Vector3(0, 0, 8) # güney kapı (X'in de girdiği yer)
const ENTER_TO := Vector3(0, 0, -5) # salonun ortası; yanmış raflara bakar
const ENTER_LINE := "Buraya ne oldu böyle?"
const RAISE_KEYS := [KEY_1, KEY_KP_1] # üst sıradaki 1 ve sayı tuş takımındaki 1
const RAISE_RANGE := 8.0 # oyuncudan en fazla bu uzaklıktaki ceset kaldırılabilir
const RAISE_MOMENT := 0.5 # iskeletin büyünün hangi anında (0..1) kalktığı
const MAX_MINIONS := 5
# Altın açı (≈137.5°): her yeni iskelet oyuncunun çevresinde bir öncekinden bu kadar dönük yere
# yerleşir; kaç iskelet olursa olsun çembere eşit dağılırlar
const GOLDEN_ANGLE := PI * (3.0 - sqrt(5.0))

@onready var hud = $HUD
@onready var player = $Player
@onready var enemies_root: Node3D = $Dusmanlar

var minions: Array[Node3D] = []
var raised_count := 0 # şimdiye kadar kaldırılan iskelet sayısı (yerlerini seçer)
var kills_since_potion := POTION_GAP # son iksirden beri ölen düşman sayısı (ilk ölümde düşebilir)
var quests: QuestLog
var champion: Node3D
var has_golden_key := false
var cast_target: Node3D # bu büyüyle kalkacak ceset; kalkınca null
var has_golem := false # golem çağırma hakkı kazanıldı mı (mahzendeki rün halkası)
var golem: Node3D # ayaktaki golem; yoksa null
var golem_pending := false # golem büyüsü sürüyor: yarısında golem_at'te kalkar
var golem_at := Vector3.ZERO
var golem_cooldown := 0.0 # golem öldüyse yeniden çağırmaya kalan süre (saniye); HUD'daki beceri simgesi gösterir


func _ready() -> void:
	hud.set_minions(0)
	var crowd := Node.new()
	crowd.name = "Kalabalik"
	crowd.set_script(CROWD)
	add_child(crowd)
	quests = QUEST_LOG.new()
	quests.name = "Gorevler"
	add_child(quests)
	quests.changed.connect(func(): hud.show_quests(quests.lines()))
	place_name_pages()
	for point in FIRE_POINTS:
		var fire := FIRE.instantiate()
		add_child(fire)
		fire.global_position = point
		fire.ignite()
	for point in ENEMY_SPAWNS:
		var enemy := ENEMY.instantiate()
		enemy.position = point # evi burası olur (_ready'de)
		enemies_root.add_child(enemy)
		enemy.seal_broken.connect(on_seal_broken)
		enemy.buried.connect(on_enemy_fell)
	champion = ENEMY.instantiate()
	champion.champion = true
	champion.name = "AltinSampiyon"
	champion.position = CHAMPION_AT
	enemies_root.add_child(champion)
	champion.seal_broken.connect(on_seal_broken)
	champion.buried.connect(on_enemy_fell)
	var mother := VILLAGER.instantiate()
	mother.name = "Anne"
	mother.position = MOTHER_AT
	mother.rotation.y = atan2(12.0, 15.0) # köye (meydana) bakar: kızı orada
	add_child(mother)
	# Açılıştan geldiyse: Ruh Kıran kapıdan girer, salonun ortasında durup yangının izlerine bakar
	if after_intro:
		after_intro = false
		player.enter_scene(ENTER_FROM, ENTER_TO)
		player.arrived.connect(func(): hud.say(ENTER_LINE), CONNECT_ONE_SHOT)


func place_name_pages() -> void:
	# Navmesh ilk karelerde henüz boş (sorgular (0, 0, 0) döndürüyor): oyuncunun yeri yanıt verene kadar bekle
	var map := get_world_3d().navigation_map
	while NavigationServer3D.map_get_closest_point(map, player.global_position).is_zero_approx():
		await get_tree().physics_frame
	var region: NavigationRegion3D = $Gezinme
	hud.get_node("Harita").build(region.navigation_mesh, region.global_transform) # küçük harita yürünebilir alanı çizer
	for spec in NAME_PAGES:
		var page: NamePage = NAME_PAGE.new()
		page.person = spec["person"]
		page.line = spec["line"]
		var at: Vector3 = spec["at"]
		var walkable := NavigationServer3D.map_get_closest_point_to_segment(map, at + Vector3.UP * 3.0, at + Vector3.DOWN * 2.0)
		page.position = Vector3(walkable.x, 0, walkable.z) # yürünebilir bir yerde dursun (alınabilsin)
		add_child(page)
		page.picked.connect(on_name_page)


## Bir isim sayfası alındı: Ruh Kıran adı ve son sözü okur; ilk sayfada görev açılır, beşincide biter
func on_name_page(page: NamePage) -> void:
	quests.start(NAMES_QUEST, NAMES_TITLE, NAME_PAGES.size())
	quests.advance(NAMES_QUEST)
	if quests.is_done(NAMES_QUEST):
		hud.say("%s. %s" % [page.person, page.line])
		get_tree().create_timer(4.2).timeout.connect(func(): hud.say(NAMES_DONE_LINE))
		player.raise_max_health(NAMES_REWARD)
	else:
		hud.say("%s. %s" % [page.person, page.line])


# Düşman ölünce yalnızca altın mühür kırılır: mavi ruh ve "Teşekkür ederiz" fısıltısı yok (kullanıcı istedi)
func on_seal_broken(enemy: Node3D) -> void:
	spawn_effect(enemy.global_position, false, false)
	GameCamera.shake(0.6)
	if enemy.champion:
		quests.start(CHAMPION_QUEST, CHAMPION_TITLE) # yaklaşmadan uzaktan (mızrakla) kırıldıysa da açılıp bitsin
		quests.finish(CHAMPION_QUEST)
		hud.say(CHAMPION_DOWN_LINE)
		drop_golden_key(enemy.global_position)


func drop_golden_key(at: Vector3) -> void:
	var angle := randf() * TAU
	var landing := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, at + Vector3(sin(angle), 0, cos(angle)) * 1.2)
	var key: GoldenKey = GOLDEN_KEY.new()
	add_child(key)
	key.drop(Terrain.on_ground(at) + Vector3.UP * 0.8, Terrain.on_ground(Vector3(landing.x, 0, landing.z)))
	key.picked.connect(on_golden_key)


func on_golden_key() -> void:
	has_golden_key = true
	quests.start(DOOR_QUEST, DOOR_TITLE)
	hud.say(KEY_LINE)


# Şampiyon görevi: oyuncu şampiyonu ilk kez yakından görünce açılır (_process her kare çağırır)
func watch_champion() -> void:
	if quests and not quests.quests.has(CHAMPION_QUEST) and is_instance_valid(champion) and champion.alive:
		var gap := Vector2(player.global_position.x - champion.global_position.x, player.global_position.z - champion.global_position.z).length()
		if gap <= CHAMPION_NOTICE and player.alive:
			quests.start(CHAMPION_QUEST, CHAMPION_TITLE)
			hud.say(CHAMPION_SEEN_LINE)


func spawn_effect(at: Vector3, release: bool, with_soul := true) -> void:
	var effect := SEAL_BREAK.instantiate()
	effect.release = release
	effect.with_soul = with_soul
	add_child(effect)
	effect.global_position = Terrain.on_ground(at)


## Düşman yere düştü: yerinde ceset kalır, ara sıra da can iksiri düşer
func on_enemy_fell(at: Vector3) -> void:
	on_buried(at)
	if kills_since_potion >= POTION_GAP and randf() < POTION_CHANCE:
		kills_since_potion = 0
		drop_potion(at)
	else:
		kills_since_potion += 1


## at noktasından yanındaki rastgele bir yere can iksiri düşür (yürünebilir zemine çekilir)
func drop_potion(at: Vector3) -> Node3D:
	var angle := randf() * TAU
	var wanted := at + Vector3(sin(angle), 0, cos(angle)) * POTION_DISTANCE
	var landing := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, wanted)
	var potion := POTION.instantiate()
	add_child(potion)
	potion.drop(Terrain.on_ground(at) + Vector3.UP * 0.5, Terrain.on_ground(landing))
	return potion


func on_buried(at: Vector3) -> void:
	var corpse := CORPSE.instantiate()
	add_child(corpse)
	corpse.global_position = Terrain.on_ground(at)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode in RAISE_KEYS:
		raise_dead()
	if key and key.pressed and not key.echo and key.physical_keycode in GOLEM_KEYS:
		summon_golem()


## 1 tuşu: en yakın cesede büyü yapmaya başla
func raise_dead() -> bool:
	if player.is_busy():
		return false
	var corpse := nearest_corpse()
	if corpse == null:
		return false
	if player.mana < player.RAISE_MANA:
		player.not_enough_mana.emit()
		return false
	if player.start_cast(corpse.global_position) < 0:
		return false
	player.spend_mana(player.RAISE_MANA)
	cast_target = corpse
	return true


func nearest_corpse() -> Node3D:
	var best: Node3D = null
	var best_distance := RAISE_RANGE
	for corpse in get_tree().get_nodes_in_group("ceset"):
		var distance: float = Vector2(corpse.global_position.x - player.global_position.x,
			corpse.global_position.z - player.global_position.z).length()
		if distance <= best_distance:
			best = corpse
			best_distance = distance
	return best


## 2 tuşu: kemik golemini çağır (hak kazanıldıysa ve ayakta golem yoksa). Oyuncunun önünde, büyünün yarısında kalkar.
func summon_golem() -> bool:
	if not has_golem or player.is_busy():
		return false
	if is_instance_valid(golem):
		hud.say(GOLEM_HERE_LINE)
		return false
	if golem_cooldown > 0:
		hud.say(GOLEM_WAIT_LINE)
		return false
	if player.mana < GOLEM_MANA:
		player.not_enough_mana.emit()
		return false
	var ahead: Vector3 = player.global_position + Vector3(sin(player.rotation.y), 0, cos(player.rotation.y)) * GOLEM_DISTANCE
	var found := NavigationServer3D.map_get_closest_point_to_segment(get_world_3d().navigation_map, ahead + Vector3.UP * 2.0, ahead + Vector3.DOWN * 2.0)
	if player.start_cast(found) < 0:
		return false
	player.spend_mana(GOLEM_MANA)
	golem_at = Vector3(found.x, 0, found.z)
	golem_pending = true
	return true


func update_golem_cast() -> void:
	if not golem_pending:
		return
	var progress: float = player.cast_progress()
	if progress < 0:
		golem_pending = false # büyü yarıda kaldı (oyuncu öldü)
	elif progress >= RAISE_MOMENT:
		golem_pending = false
		spawn_golem(golem_at)


## Golem at noktasında yerden yükselir (iskelet gibi mavi parıltıyla, ama daha yavaş ve ekranı sarsarak)
func spawn_golem(at: Vector3) -> void:
	if is_instance_valid(golem):
		return
	golem = GOLEM.instantiate()
	golem.leader = player
	golem.slot_angle = raised_count * GOLDEN_ANGLE + PI # iskeletlerin arasına denk gelmesin
	add_child(golem)
	golem.global_position = Vector3(at.x, 0, at.z)
	var to_player: Vector3 = player.global_position - golem.global_position
	golem.rotation.y = atan2(to_player.x, to_player.z)
	golem.fell.connect(on_golem_fell)
	GameCamera.shake(0.45)


## Golemin canı bitti: iskeletler gibi ruhu serbest kalır; bekleme süresi dolunca 2 tuşuyla yeniden çağrılabilir
func on_golem_fell(fallen: Node3D) -> void:
	spawn_effect(fallen.global_position, true)
	fallen.queue_free()
	golem = null
	golem_cooldown = GOLEM_COOLDOWN


## Mahzendeki rün halkası (levels/bina_ici.gd çağırır): golem ilk kez kalkar, çağırma hakkı kazanılır
func awaken_golem(at: Vector3) -> void:
	has_golem = true
	quests.start(GOLEM_QUEST, GOLEM_TITLE) # mektubu okumadan (denemede) gelinirse de görev bitsin
	quests.finish(GOLEM_QUEST)
	spawn_golem(at)
	hud.say(GOLEM_LINE)
	hud.whisper(GOLEM_HINT)


func _process(delta: float) -> void:
	watch_champion()
	golem_cooldown = maxf(0.0, golem_cooldown - delta)
	update_golem_cast()
	if cast_target == null:
		return
	var progress: float = player.cast_progress()
	if progress < 0 or not is_instance_valid(cast_target):
		# Büyü yarıda kaldı (oyuncu öldü): ceset parlamayı bıraksın
		if is_instance_valid(cast_target):
			cast_target.set_glow(0.0)
		cast_target = null
		return
	# Ceset büyünün ilk yarısında giderek parlar; yarısında iskelet kalkar
	cast_target.set_glow(progress / RAISE_MOMENT)
	if progress >= RAISE_MOMENT:
		raise_skeleton(cast_target)
		cast_target = null


func raise_skeleton(corpse: Node3D) -> void:
	if minions.size() >= MAX_MINIONS:
		release_minion(minions.pick_random())
	corpse.sink()
	var minion := MINION.instantiate()
	minion.leader = player
	minion.slot_angle = raised_count * GOLDEN_ANGLE
	raised_count += 1
	add_child(minion)
	var at: Vector3 = corpse.global_position
	minion.global_position = Vector3(at.x, 0, at.z)
	var to_player: Vector3 = player.global_position - minion.global_position
	minion.rotation.y = atan2(to_player.x, to_player.z) # efendisine dönük kalksın
	minion.fell.connect(release_minion) # canı biterse ruhu serbest kalır
	minions.append(minion)
	hud.set_minions(minions.size())


## İskeleti serbest bırak: ruhu mavi ışıkla yükselir, kemikleri yok olur
func release_minion(minion: Node3D) -> void:
	spawn_effect(minion.global_position, true)
	minions.erase(minion)
	minion.queue_free()
	hud.set_minions(minions.size())
