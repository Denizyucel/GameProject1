# Köylü (oyuncu olmayan karakter, NPC): dövüşmez, düşmanlar ona saldırmaz; yerinde bekler, oyuncu yaklaşınca ona döner.
# İlk köylü Harabe Köy'de saklanan anne (Saklanan Anne yan görevi; main.gd koyar). Model assets/npc/woman1.glb
# (Meshy SmartRig, Mixamo kemik adları, 1.7 m). Bekleme animasyonu oyuncununkiyle aynı idle.fbx; RigAnimations.take
# onu bu modelin iskeletine uyarlar.

class_name Villager
extends Node3D

const TURN_SPEED := 4.0
const LOOK_RANGE := 5.0 # oyuncu bu kadar yakınsa ona döner

@export_file("*.fbx", "*.glb") var idle_file := "res://assets/character/idle.fbx"
@export var idle_name := "mixamo_com"

@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var skeleton: Skeleton3D = $Model.find_child("Skeleton3D")

var alive := true # characters/crowd.gd bakar: köylünün içinden geçilmez


func _ready() -> void:
	add_to_group("koylu")
	var library := AnimationLibrary.new()
	library.add_animation("idle", RigAnimations.take(idle_file, idle_name, animation_player, skeleton))
	animation_player.add_animation_library("koylu", library)
	animation_player.play("koylu/idle")
	animation_player.seek(randf() * 2.0) # birden çok köylü aynı anda nefes almasın


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("oyuncu") as Node3D
	if player:
		var to_player := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
		if to_player.length() < LOOK_RANGE and to_player.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.y), 1.0 - exp(-TURN_SPEED * delta))
	model.position.y = Terrain.height_at(global_position) # köyün zemini engebeli (levels/terrain.gd)
