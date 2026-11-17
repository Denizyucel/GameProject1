# Oyunun üstündeki arayüz (HUD). Oyuncunun sinyallerini dinler: can küresini günceller, ölünce
# "Öldün" yazısını gösterir, yeniden doğunca gizler. Kurtarılan ruhların fısıltısını ve Ruh Kıran'ın
# kendi sözlerini (alt yazı) gösterir. Okunacak notu (show_note) ve karşılıklı konuşma kutusunu (talk) da o açar.

extends CanvasLayer

const WHISPER_TIME := 3.0 # fısıltının ekranda kalma süresi (saniye)
const WHISPER_RISE := 18.0 # kaybolurken ne kadar yukarı süzüldüğü (piksel)
const SAY_TIME := 3.5 # Ruh Kıran'ın sözünün ekranda kalma süresi (saniye)
const NO_MANA_LINE := "Manam yetmiyor."
const NO_MANA_GAP := 2.0 # bu sözü en sık bu kadar saniyede bir söyler (tık tık denerken tekrarlamasın)
const TALK_SPEED := 55.0 # konuşma kutusunda sözün yazılma hızı (harf / saniye)
const HERO_NAME := "Ruh Kıran"
const HERO_COLOR := Color(1.0, 0.52, 0.36) # Ruh Kıran'ın adı köz kırmızısı
const OTHER_COLOR := Color(0.78, 0.88, 1.0) # karşısındakinin adı soluk mavi (dönüştürülmemiş, özgür)

@export var player: Node

@onready var globe = $CanKuresi
@onready var mana_globe = $ManaKuresi
@onready var death_label: Label = $OlumYazisi
@onready var whisper_label: Label = $Fisilti
@onready var minion_label: Label = $ManaKuresi/Rozet # kafatasının üstündeki rozet
@onready var say_label: Label = $Konusma
@onready var quest_label: Label = $Gorevler/Liste
@onready var blackout: ColorRect = $Kararma
@onready var note_panel: PanelContainer = $Not
@onready var talk_panel: PanelContainer = $Diyalog
@onready var talk_name: Label = $Diyalog/Duzen/Ad
@onready var talk_text: Label = $Diyalog/Duzen/Metin

var whisper_tween: Tween
var whisper_top := 0.0
var say_tween: Tween
var no_mana_said_at := -100.0
var note_open := false
var talk_open := false
var talk_lines: Array = [] # [[konuşan, söz], ...]
var talk_index := 0
var talk_tween: Tween

signal note_closed
signal talk_finished


func _ready() -> void:
	whisper_top = whisper_label.position.y
	if player == null:
		return
	globe.set_health(player.health, player.max_health, false)
	player.health_changed.connect(globe.set_health)
	mana_globe.set_health(player.mana, player.max_mana, false)
	player.mana_changed.connect(mana_globe.set_health)
	player.not_enough_mana.connect(on_not_enough_mana)
	player.died.connect(func(): death_label.visible = true)
	player.respawned.connect(func(): death_label.visible = false)


## Ekranın üst ortasında kısa süre belirip yukarı süzülerek kaybolan yazı (kurtarılan ruhun sesi).
## time: ekranda kalma süresi (uzun sözlerde okunabilsin diye artırılır)
func whisper(text: String, time := WHISPER_TIME) -> void:
	if whisper_tween:
		whisper_tween.kill()
	whisper_label.text = text
	whisper_label.modulate.a = 0.0
	whisper_label.position.y = whisper_top
	whisper_tween = create_tween()
	whisper_tween.tween_property(whisper_label, "modulate:a", 1.0, time * 0.2)
	whisper_tween.tween_interval(time * 0.35)
	whisper_tween.tween_property(whisper_label, "modulate:a", 0.0, time * 0.45)
	whisper_tween.parallel().tween_property(whisper_label, "position:y", whisper_top - WHISPER_RISE, time * 0.45)


## Ruh Kıran'ın kendi sözü: ekranın altında alt yazı gibi belirir, biraz kalır, söner
func say(text: String) -> void:
	if say_tween:
		say_tween.kill()
	say_label.text = text
	say_tween = create_tween()
	say_tween.tween_property(say_label, "modulate:a", 1.0, 0.3)
	say_tween.tween_interval(SAY_TIME)
	say_tween.tween_property(say_label, "modulate:a", 0.0, 0.6)


## Ayaktaki iskelet sayısı: mana küresinin kafatasının üstündeki rozette (kalkınca artar, gidince azalır)
func set_minions(count: int) -> void:
	minion_label.text = str(count)


## Büyüye mana yetmedi: mana küresi parlar, Ruh Kıran söyler
func on_not_enough_mana() -> void:
	mana_globe.blink()
	var now := Time.get_ticks_msec() / 1000.0
	if now - no_mana_said_at >= NO_MANA_GAP:
		no_mana_said_at = now
		say(NO_MANA_LINE)


## Görev listesi (sağ üst): açık görevler başlık ve sayacıyla; biten görev üstü çizili gibi soluk görünür
func show_quests(lines: Array) -> void:
	var text := ""
	for line in lines:
		text += ("✓ " if line[1] else "• ") + line[0] + "\n"
	quest_label.text = text.strip_edges()
	$Gorevler.visible = not lines.is_empty()


## Ekranı karart (alpha 1) ya da aç (alpha 0). Oyun durmuşken de işler. Bitince sinyal: await hud.fade(1.0, 0.6)
func fade(alpha: float, time: float) -> Signal:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(blackout, "color:a", alpha, time)
	return tween.finished


## Okunacak bir not (eski kâğıt gibi panel). Oyun bu sırada durur (çağıran durdurur); tık, Esc ya da Enter kapatır.
## Kapanınca note_closed sinyali.
func show_note(title: String, text: String) -> void:
	note_panel.get_node("Duzen/Baslik").text = title
	note_panel.get_node("Duzen/Metin").text = text
	note_panel.modulate.a = 0.0
	note_panel.visible = true
	note_open = true
	process_mode = Node.PROCESS_MODE_ALWAYS # oyun durmuşken tıklamayı duyabilsin
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(note_panel, "modulate:a", 1.0, 0.4)


## Karşılıklı konuşma kutusu (altta, iki kürenin arasında). lines: [[konuşan, söz], ...]. Söz harf harf yazılır;
## tık / Boşluk / Enter önce sözü tamamlar, sonra sıradakine geçer; Esc konuşmanın tamamını geçer. Oyun bu sırada
## durur (çağıran durdurur). Bitince talk_finished: await hud.talk(...)
func talk(lines: Array) -> Signal:
	talk_lines = lines
	talk_index = 0
	talk_open = true
	process_mode = Node.PROCESS_MODE_ALWAYS # oyun durmuşken tıklamayı duyabilsin
	talk_panel.modulate.a = 0.0
	talk_panel.visible = true
	$Beceriler.modulate.a = 0.0 # beceri simgeleri kutunun altında kalmasın
	if say_tween:
		say_tween.kill()
	say_label.modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(talk_panel, "modulate:a", 1.0, 0.25)
	show_talk_line()
	return talk_finished


func show_talk_line() -> void:
	var line: Array = talk_lines[talk_index]
	talk_name.text = line[0]
	talk_name.label_settings.font_color = HERO_COLOR if line[0] == HERO_NAME else OTHER_COLOR
	talk_text.text = line[1]
	talk_text.visible_ratio = 0.0
	if talk_tween:
		talk_tween.kill()
	talk_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	talk_tween.tween_property(talk_text, "visible_ratio", 1.0, String(line[1]).length() / TALK_SPEED)


## Konuşmada ilerle: söz yazılıyorsa tamamla, tamamsa sıradaki söz; sonuncudan sonra (ya da skip ile) kutu kapanır
func advance_talk(skip := false) -> void:
	if not skip and talk_text.visible_ratio < 1.0:
		talk_tween.kill()
		talk_text.visible_ratio = 1.0
		return
	talk_index += 1
	if not skip and talk_index < talk_lines.size():
		show_talk_line()
		return
	talk_open = false
	if talk_tween:
		talk_tween.kill()
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(talk_panel, "modulate:a", 0.0, 0.2)
	await tween.finished
	talk_panel.visible = false
	$Beceriler.modulate.a = 1.0
	process_mode = Node.PROCESS_MODE_INHERIT
	talk_finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	var key := event as InputEventKey
	if talk_open:
		if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			advance_talk(true)
		elif (click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or (key and key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]):
			get_viewport().set_input_as_handled()
			advance_talk()
		return
	if not note_open:
		return
	if (click and click.pressed) or (key and key.pressed and not key.echo and key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]):
		get_viewport().set_input_as_handled()
		note_open = false
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(note_panel, "modulate:a", 0.0, 0.3)
		await tween.finished
		note_panel.visible = false
		process_mode = Node.PROCESS_MODE_INHERIT
		note_closed.emit()
