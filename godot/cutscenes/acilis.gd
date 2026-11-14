# Açılış ara sahnesi (Hikaye.md, "Açılış: X gece mühürleri çalar, kütüphaneyi yakar. Ruh Kıran küller
# arasında uyanır."). Zaman çizelgesi Senaryo (AnimationPlayer) düğümünde, "acilis" animasyonunda:
# kamera, X'in yolu ve dönüşleri, ışıklar ve kararma oradaki anahtar karelerle; aşağıdaki fonksiyonlar da
# oradaki "Call Method" izinden belirli saniyelerde çağrılır. Zamanlamayı editörde, anahtar kareleri
# sürükleyerek değiştir. Esc ya da tık: sahneyi geç.

extends Node3D

const MAIN_SCENE := "res://main.tscn"
const FIRE := preload("res://effects/fire.tscn")
const SILVER := Color(0.82, 0.86, 0.95)
const GOLD := Color("#ffc95a")
const WAKE_AT := Vector3(3.0, 0, -8.5) # ara sahneden sonra Ruh Kıran'ın küller arasında uyandığı yer
const SEAL_RADIUS := 0.16
const SEAL_SPREAD := 0.28 # mühürlerin kaidenin ortasına uzaklığı (üçgen dizilim)
const SPARK_TIME := 0.45 # kıvılcımın X'ten rafa uçuş süresi
const SPARK_GAP := 0.18 # iki kıvılcım arası
# Kıvılcımların tutuşturduğu yerler (raflar; en yakından uzağa)
const FIRE_POINTS := [
	Vector3(-4, 0.4, -12.3), Vector3(4, 0.4, -12.3), Vector3(-7.5, 0.3, -8.5), Vector3(7.5, 0.3, -7.5),
	Vector3(-8, 0.4, -12.3), Vector3(8, 0.4, -12.3), Vector3(-7.5, 0.3, -6), Vector3(7.5, 0.3, -4.5),
	Vector3(-7.5, 0.3, -2), Vector3(7.5, 0.3, 1),
]
# X'in animasyonları: [ad, dosya, dosyadaki ad]
const X_ANIMATIONS := [
	["idle", "res://assets/character/idle.fbx", "mixamo_com"],
	["walk", "res://assets/x/x.glb", "Walking"],
	["buyu", "res://assets/animations/spell/spell4.fbx", "mixamo_com"], # Standing 2H Cast Spell
]

@onready var x: Node3D = $X
@onready var x_player: AnimationPlayer = $X.find_child("AnimationPlayer")
@onready var x_skeleton: Skeleton3D = $X.find_child("Skeleton3D")
@onready var seals: Node3D = $Muhurler
@onready var lift: Node3D = $Muhurler/Kaldirma
@onready var seal_light: OmniLight3D = $Muhurler/MuhurIsigi
@onready var script_player: AnimationPlayer = $Senaryo

var x_walk_speed := 0.0 # X'in yürüme animasyonunun ayak hızı (metre / saniye)
var seal_materials: Array[StandardMaterial3D] = []
var spinning := false
var finished := false


func _ready() -> void:
	prepare_x()
	place_seals()
	script_player.play("acilis")


func prepare_x() -> void:
	var library := AnimationLibrary.new()
	for spec in X_ANIMATIONS:
		var animation := RigAnimations.take(spec[1], spec[2], x_player, x_skeleton, spec[0] != "buyu")
		RigAnimations.remove_root_motion(animation)
		library.add_animation(spec[0], animation)
	x_player.add_animation_library("sahne", library)
	x_walk_speed = RigAnimations.stride_speed(x_player, x_skeleton, "sahne/walk")
	x_player.play("sahne/idle")


## X'e bir animasyon oynat. speed > 0 ise yürüyüştür: animasyon o hıza (metre / saniye) uydurulur.
func x_play(animation: String, speed: float = 0.0) -> void:
	x_player.play("sahne/" + animation, 0.3)
	x_player.speed_scale = speed / x_walk_speed if speed > 0 and x_walk_speed > 0 else 1.0


# Üç gümüş mühür: mühür kaidesinin üstündeki üç yuvaya, üçgen dizilimle
func place_seals() -> void:
	var pedestal: Node3D = $YanikKutuphane/Parcalar.get_node_or_null("muhur-kaidesi-1")
	var top := Vector3(0, 1.2, -11.75)
	if pedestal:
		var box := Weapon.scene_aabb(pedestal, pedestal.get_parent().global_transform)
		top = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	seals.global_position = top + Vector3.UP * 0.03
	for i in 3:
		var angle := i * TAU / 3.0
		var material := StandardMaterial3D.new()
		material.albedo_color = SILVER
		material.metallic = 1.0
		material.roughness = 0.25
		material.emission_enabled = true
		material.emission = SILVER
		material.emission_energy_multiplier = 1.8
		seal_materials.append(material)
		var disc := CylinderMesh.new()
		disc.top_radius = SEAL_RADIUS
		disc.bottom_radius = SEAL_RADIUS
		disc.height = 0.035
		disc.material = material
		var seal := MeshInstance3D.new()
		seal.mesh = disc
		# Yuvasında dik duran bir madalyon gibi: yüzü kameraya (izometrik bakışa) dönük
		seal.position = Vector3(sin(angle), 0, cos(angle)) * SEAL_SPREAD + Vector3.UP * SEAL_RADIUS
		seal.rotation = Vector3(PI / 2, PI / 4, 0)
		lift.add_child(seal)
	seal_light.light_color = SILVER


## Mühürler gümüşten altına döner (X büyüyü tersine çeviriyor); yükselirken dönmeye başlarlar
func seals_reverse() -> void:
	spinning = true
	var tween := create_tween().set_parallel()
	for material in seal_materials:
		tween.tween_property(material, "albedo_color", GOLD, 0.8)
		tween.tween_property(material, "emission", GOLD, 0.8)
		tween.tween_property(material, "emission_energy_multiplier", 3.0, 0.8)
	tween.tween_property(seal_light, "light_color", GOLD, 0.8)


## Mühürler X'in göğsüne uçup içine çekilir
func seals_absorb() -> void:
	var chest := x.global_position + Vector3.UP * 1.3
	var tween := create_tween().set_parallel()
	tween.tween_property(lift, "global_position", chest, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_property(lift, "scale", Vector3.ONE * 0.05, 0.6).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func(): lift.visible = false)


## Altın kıvılcımlar X'ten raflara sıçrar, değdikleri yer tutuşur
func fire_wave() -> void:
	var from := x.global_position + Vector3.UP * 1.3
	for i in FIRE_POINTS.size():
		var point: Vector3 = FIRE_POINTS[i]
		get_tree().create_timer(i * SPARK_GAP).timeout.connect(func(): throw_spark(from, point))


func throw_spark(from: Vector3, to: Vector3) -> void:
	var spark := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = GOLD
	material.emission_enabled = true
	material.emission = GOLD
	material.emission_energy_multiplier = 4.0
	sphere.material = material
	spark.mesh = sphere
	add_child(spark)
	spark.global_position = from
	# Yay çizerek uçsun: önce yukarı, sonra hedefe
	var middle := (from + to) / 2 + Vector3.UP * 2.0
	var tween := create_tween()
	tween.tween_method(func(t: float): spark.global_position = from.lerp(middle, t).lerp(middle.lerp(to, t), t), 0.0, 1.0, SPARK_TIME)
	tween.tween_callback(ignite_at.bind(spark, to))


func ignite_at(spark: Node3D, at: Vector3) -> void:
	var fire := FIRE.instantiate()
	add_child(fire)
	fire.global_position = at
	fire.ignite()
	spark.queue_free()


func _process(delta: float) -> void:
	if spinning:
		lift.rotate_y(delta * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if (key and key.pressed and key.keycode == KEY_ESCAPE) or (click and click.pressed):
		finish()


## Oyuna geç: Ruh Kıran küller arasında, yerden kalkarak başlar
func finish() -> void:
	if finished:
		return
	finished = true
	MainScene.wake_at = WAKE_AT
	get_tree().change_scene_to_file(MAIN_SCENE)
