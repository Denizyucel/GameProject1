# Köylü (oyuncu olmayan karakter, NPC): dövüşmez, düşmanlar ona saldırmaz; yerinde bekler, oyuncu yaklaşınca ona döner.
# İlk köylü Harabe Köy'de saklanan anne (Saklanan Anne yan görevi; main.gd koyar). Model assets/npc/woman1.glb
# (Meshy SmartRig, Mixamo kemik adları, 1.7 m). Bekleme animasyonu oyuncununkiyle aynı idle.fbx; RigAnimations.take
# onu bu modelin iskeletine uyarlar. Söyleyecek sözü varken başının üstünde köz rengi bir "!" süzülür (set_marker).

class_name Villager
extends Node3D

const TURN_SPEED := 4.0
const LOOK_RANGE := 5.0 # oyuncu bu kadar yakınsa ona döner
const MARKER_HEIGHT := 2.35 # "!" işaretinin ayaktan yüksekliği (metre)
const MARKER_COLOR := Color(1.0, 0.55, 0.3) # köz rengi: oyuncunun tarafı (altın = tehlike olduğu için sarı değil)

@export_file("*.fbx", "*.glb") var idle_file := "res://assets/character/idle.fbx"
@export var idle_name := "mixamo_com"

@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var skeleton: Skeleton3D = $Model.find_child("Skeleton3D")

var alive := true # characters/crowd.gd bakar: köylünün içinden geçilmez
var watches := true # oyuncu yaklaşınca ona döner; false ise ilk baktığı yöne döner ve öyle kalır (küsmüş)
var home_turn := 0.0 # ilk baktığı yön
var marker: Label3D # başının üstündeki "!"; yoksa null


func _ready() -> void:
	add_to_group("koylu")
	home_turn = rotation.y
	var library := AnimationLibrary.new()
	library.add_animation("idle", RigAnimations.take(idle_file, idle_name, animation_player, skeleton))
	animation_player.add_animation_library("koylu", library)
	animation_player.play("koylu/idle")
	animation_player.seek(randf() * 2.0) # birden çok köylü aynı anda nefes almasın


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("oyuncu") as Node3D
	if not watches:
		rotation.y = lerp_angle(rotation.y, home_turn, 1.0 - exp(-TURN_SPEED * 0.4 * delta)) # yavaşça sırtını döner
	elif player:
		var to_player := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
		if to_player.length() < LOOK_RANGE and to_player.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.y), 1.0 - exp(-TURN_SPEED * delta))
	model.position.y = Terrain.height_at(global_position) # köyün zemini engebeli (levels/terrain.gd)
	if marker and marker.visible:
		marker.position.y = model.position.y + MARKER_HEIGHT + sin(Time.get_ticks_msec() / 300.0) * 0.08


## Başının üstündeki "!" işaretini aç ya da kapat (söyleyecek sözü var). Label3D: 3B dünyada duran yazı; hep kameraya
## döner (billboard) ve evlerin arkasında kalsa da görünür (no_depth_test).
func set_marker(on: bool) -> void:
	if marker == null:
		if not on:
			return
		marker = Label3D.new()
		marker.text = "!"
		marker.font_size = 110
		marker.pixel_size = 0.006
		marker.outline_size = 22
		marker.modulate = MARKER_COLOR
		marker.outline_modulate = Color(0.08, 0.03, 0.02)
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.no_depth_test = true
		marker.position.y = MARKER_HEIGHT
		add_child(marker)
	marker.visible = on
