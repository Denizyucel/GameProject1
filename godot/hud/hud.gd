# Oyunun üstündeki arayüz (HUD). Oyuncunun sinyallerini dinler: can küresini günceller, ölünce
# "Öldün" yazısını gösterir, yeniden doğunca gizler. Kurtarılan ruhların fısıltısını gösterir.

extends CanvasLayer

const WHISPER_TIME := 3.0 # fısıltının ekranda kalma süresi (saniye)
const WHISPER_RISE := 18.0 # kaybolurken ne kadar yukarı süzüldüğü (piksel)

@export var player: Node

@onready var globe = $CanKuresi
@onready var death_label: Label = $OlumYazisi
@onready var whisper_label: Label = $Fisilti
@onready var minion_label: Label = $IskeletSayisi

var whisper_tween: Tween
var whisper_top := 0.0


func _ready() -> void:
	whisper_top = whisper_label.position.y
	if player == null:
		return
	globe.set_health(player.health, player.max_health, false)
	player.health_changed.connect(globe.set_health)
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


## Kürenin yanındaki iskelet sayısı
func set_minions(count: int) -> void:
	minion_label.text = "İskelet: %d" % count
