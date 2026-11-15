# Oyunun üstündeki arayüz (HUD). Oyuncunun sinyallerini dinler: can küresini günceller, ölünce
# "Öldün" yazısını gösterir, yeniden doğunca gizler. Kurtarılan ruhların fısıltısını ve Ruh Kıran'ın
# kendi sözlerini (alt yazı) gösterir.

extends CanvasLayer

const WHISPER_TIME := 3.0 # fısıltının ekranda kalma süresi (saniye)
const WHISPER_RISE := 18.0 # kaybolurken ne kadar yukarı süzüldüğü (piksel)
const SAY_TIME := 3.5 # Ruh Kıran'ın sözünün ekranda kalma süresi (saniye)
const NO_MANA_LINE := "Manam yetmiyor."
const NO_MANA_GAP := 2.0 # bu sözü en sık bu kadar saniyede bir söyler (tık tık denerken tekrarlamasın)

@export var player: Node

@onready var globe = $CanKuresi
@onready var mana_globe = $ManaKuresi
@onready var death_label: Label = $OlumYazisi
@onready var whisper_label: Label = $Fisilti
@onready var minion_label: Label = $ManaKuresi/Rozet # kafatasının üstündeki rozet
@onready var say_label: Label = $Konusma
@onready var quest_label: Label = $Gorevler/Liste

var whisper_tween: Tween
var whisper_top := 0.0
var say_tween: Tween
var no_mana_said_at := -100.0


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


## Ekranın üst ortasında kısa süre belirip yukarı süzülerek kaybolan yazı (kurtarılan ruhun sesi)
func whisper(text: String) -> void:
	if whisper_tween:
		whisper_tween.kill()
	whisper_label.text = text
	whisper_label.modulate.a = 0.0
	whisper_label.position.y = whisper_top
	whisper_tween = create_tween()
	whisper_tween.tween_property(whisper_label, "modulate:a", 1.0, WHISPER_TIME * 0.2)
	whisper_tween.tween_interval(WHISPER_TIME * 0.35)
	whisper_tween.tween_property(whisper_label, "modulate:a", 0.0, WHISPER_TIME * 0.45)
	whisper_tween.parallel().tween_property(whisper_label, "position:y", whisper_top - WHISPER_RISE, WHISPER_TIME * 0.45)


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
