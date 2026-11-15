# Unutulan İsimler görevinin sayfası: kütüphanenin yangınından kalmış, yarısı yanık bir kayıt sayfası. Yerde hafifçe
# süzülür, kenarları köz gibi parlar (oyuncunun tarafının rengi), küçük bir ışığı nabız gibi atar ki karanlıkta
# fark edilsin. Oyuncu yanına gelince (PICKUP_RADIUS) kendiliğinden alınır; main.gd picked sinyalini dinler
# (Ruh Kıran adı ve son sözü okur, görev ilerler). Model dosyası yok, kodla kurulur.

class_name NamePage
extends Node3D

signal picked(page: NamePage)

const PICKUP_RADIUS := 1.2
const HOVER := 0.35 # yerden yükseklik
const BOB := 0.06
const SPIN := 0.8
const PAPER := Color(0.72, 0.62, 0.46)
const EMBER := Color(1.0, 0.35, 0.12)
const TAKE_TIME := 0.3

var person := "" # sayfadaki isim
var line := "" # son sözü
var floor_y := 0.0
var age := 0.0
var taken := false
var paper: MeshInstance3D
var light: OmniLight3D


func _ready() -> void:
	add_to_group("isim_sayfasi") # küçük harita gösterir
	paper = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.44, 0.015, 0.58)
	paper.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = PAPER
	material.roughness = 0.95
	material.emission_enabled = true
	material.emission = EMBER
	material.emission_energy_multiplier = 0.6 # kâğıt hafifçe içten yanıyor gibi
	paper.material_override = material
	paper.rotation = Vector3(deg_to_rad(18), randf() * TAU, deg_to_rad(-10)) # yere değil havaya eğik dursun
	add_child(paper)
	light = OmniLight3D.new()
	light.light_color = EMBER
	light.omni_range = 3.0
	light.position.y = 0.3
	add_child(light)
	floor_y = Terrain.visible_floor(self, global_position)


func _process(delta: float) -> void:
	age += delta
	if taken:
		return
	paper.position.y = floor_y - global_position.y + HOVER + sin(age * 2.0) * BOB
	paper.rotation.y += SPIN * delta
	light.light_energy = 1.5 + sin(age * 3.0) * 0.5
	var player := get_tree().get_first_node_in_group("oyuncu") as Node3D
	if player == null or not player.alive:
		return
	var to_player := player.global_position - global_position
	if Vector2(to_player.x, to_player.z).length() <= PICKUP_RADIUS:
		taken = true
		picked.emit(self)
		# Alındı: oyuncuya doğru yükselip küçülerek kaybol
		var tween := create_tween().set_parallel()
		tween.tween_property(paper, "scale", Vector3.ONE * 0.01, TAKE_TIME).set_ease(Tween.EASE_IN)
		tween.tween_property(paper, "global_position", Terrain.on_ground(player.global_position) + Vector3.UP * 1.3, TAKE_TIME)
		tween.tween_property(light, "light_energy", 0.0, TAKE_TIME)
		tween.chain().tween_callback(queue_free)
