# Oyunun üstündeki arayüz (HUD). Oyuncunun can sinyalini dinleyip can küresini günceller.

extends CanvasLayer

@export var player: Node

@onready var globe = $CanKuresi


func _ready() -> void:
	if player == null:
		return
	globe.set_health(player.health, player.max_health, false)
	player.health_changed.connect(globe.set_health)
