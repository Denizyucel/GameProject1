# Gotik binanın kapısı. Anahtarsız gelinirse "kilitli" der. Altın anahtarla ilk gelişte ahşap kapı altın bir parlamayla
# kaybolur ve Ruh Kıran binanın içine girer (levels/bina_ici.gd: kat planlarından ayrı iç mekân, kararmayla geçiş).
# Kapı bir kez açılınca her gelişte içeri girilir. Görev: "Binada X'in izini ara" (mektup kat 2'de, bina_ici.gd).
# GotikBina'nın altında, kapının önünde durur (gotik_bina.tscn, Kapi).

extends Node3D

const REACH := 1.8 # kapının önündeki bu yarıçapa girince
const AWAY := 4.0 # "kilitli" sözü ve içeri giriş, bu kadar uzaklaşıp yeniden gelince tekrar
const GOLD := Color(1.0, 0.78, 0.3)
const LOCKED_LINE := "Kilitli. Kilidi altından… X'in işi."
const INSIDE_TITLE := "Binada X'in izini ara"

@export var door_mesh_name := "gothic_wood"

var opened := false
var armed := true # içeriden çıkınca kapının önünde belirir: uzaklaşana kadar yeniden girmesin
var said_locked := false
var light: OmniLight3D


func _ready() -> void:
	light = OmniLight3D.new()
	light.light_color = GOLD
	light.light_energy = 0.0
	light.omni_range = 5.0
	light.position = Vector3(-1.4, 1.5, 0) # kapının ardında (binanın içi -x yönünde)
	add_child(light)


func _process(_delta: float) -> void:
	var main := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("oyuncu") as Node3D
	if player == null or not player.alive or main == null or not "has_golden_key" in main:
		return
	var gap := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if gap > AWAY:
		said_locked = false
		armed = true
	if gap > REACH or not armed:
		return
	if opened:
		armed = false
		main.get_node("Gezinme/BinaIci").enter()
	elif main.has_golden_key:
		armed = false
		open(main)
	elif not said_locked:
		said_locked = true
		main.hud.say(LOCKED_LINE)


func open(main: Node) -> void:
	opened = true
	var door := get_parent().find_child(door_mesh_name, true, false) as GeometryInstance3D
	# Kapı altın bir parlamayla kaybolur, ardından ışık taşar
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 6.0, 0.6)
	if door:
		tween.parallel().tween_property(door, "transparency", 1.0, 0.6)
	await tween.finished
	if door:
		door.visible = false
	main.has_golden_key = false
	main.quests.retitle(main.DOOR_QUEST, INSIDE_TITLE)
	create_tween().tween_property(light, "light_energy", 1.2, 2.0) # kapı aralığında sönük bir ışık kalır
	await get_tree().create_timer(0.3).timeout
	main.get_node("Gezinme/BinaIci").enter()


## İçeriden çıkınca bina_ici.gd çağırır: oyuncu kapının önünde belirir, uzaklaşmadan yeniden girmesin
func disarm() -> void:
	armed = false
