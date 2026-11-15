# Açılış ara sahnesi (Hikaye.md, "Açılış: X gece mühürleri çalar, kütüphaneyi yakar. Ruh Kıran küller
# arasında uyanır."; burada uyumaz: ara sahneden sonra kapıdan girip olanları görür). Zaman çizelgesi
# Senaryo (AnimationPlayer) düğümünde, "acilis" animasyonunda:
# kamera, X'in yolu ve dönüşleri, ışıklar ve kararma oradaki anahtar karelerle; aşağıdaki fonksiyonlar da
# oradaki "Call Method" izinden belirli saniyelerde çağrılır. Zamanlamayı editörde, anahtar kareleri
# sürükleyerek değiştir. Esc ya da tık: sahneyi geç.

extends Node3D

const MAIN_SCENE := "res://main.tscn"
const FIRE := preload("res://effects/fire.tscn")
const SILVER := Color(0.82, 0.86, 0.95)
const GOLD := Color("#ffc95a")
const SEAL_RADIUS := 0.16
const SEAL_SPREAD := 0.28 # mühürlerin kaidenin ortasına uzaklığı (üçgen dizilim)
const SPARK_TIME := 0.45 # kıvılcımın X'ten rafa uçuş süresi
const SPARK_GAP := 0.18 # iki kıvılcım arası
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
		if spec[1].get_extension() == "fbx":
			match_rest(animation, spec[1])
			freeze_legs(animation)
		library.add_animation(spec[0], animation)
	x_player.add_animation_library("sahne", library)
	x_walk_speed = RigAnimations.stride_speed(x_player, x_skeleton, "sahne/walk")
	x_player.play("sahne/idle")


## Mixamo animasyonunu X'in iskeletine uyarla. X'in (Meshy) iskeletinde omuz ve kol kemiklerinin dinlenme hali Mixamo'dan
## ~140° farklı: dönüşleri olduğu gibi kopyalamak duruşu doğru gösterse de omuz ve kol birbirini telafi eden açılarda
## kalıyordu; X'in kendi animasyonuyla (yürüme) arasında geçerken (karışım) kollar bir an yana savruluyordu.
## Burada her kemiğin dünyada dinlenme halinden ne kadar döndüğü bulunur ve aynı dönüş X'in kemiğine verilir.
func match_rest(animation: Animation, source_path: String) -> void:
	var source: Node = (load(source_path) as PackedScene).instantiate()
	var source_skeleton: Skeleton3D = source.find_child("Skeleton3D")
	var rotation_tracks := {} # kemik adı → iz
	for track in animation.get_track_count():
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			rotation_tracks[String(animation.track_get_path(track)).get_slice(":", 1)] = track
	var bones := range(x_skeleton.get_bone_count()) # ebeveynler önce gelir (Skeleton3D sırası)
	var source_rest := {} # kemik adı → kaynakta dünyadaki dinlenme dönüşü
	var target_rest := {}
	for bone in bones:
		var bone_name := x_skeleton.get_bone_name(bone)
		target_rest[bone_name] = x_skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
		var source_bone := source_skeleton.find_bone(bone_name)
		source_rest[bone_name] = source_skeleton.get_bone_global_rest(source_bone).basis.get_rotation_quaternion() if source_bone != -1 else target_rest[bone_name]
	# Her karede: kaynakta kemiklerin dünyadaki dönüşü → dinlenmeden farkı → X'te dünya dönüşü → yerel dönüş
	var step := 1.0 / 30.0
	var frames := int(ceil(animation.length / step)) + 1
	var new_keys := {} # kemik adı → [zaman, dönüş] listesi
	for frame in frames:
		var time := minf(frame * step, animation.length)
		var source_global := {}
		var target_global := {}
		for bone in bones:
			var bone_name := x_skeleton.get_bone_name(bone)
			var source_bone := source_skeleton.find_bone(bone_name)
			var local: Quaternion
			if rotation_tracks.has(bone_name):
				local = animation.rotation_track_interpolate(rotation_tracks[bone_name], time)
			elif source_bone != -1:
				local = source_skeleton.get_bone_rest(source_bone).basis.get_rotation_quaternion()
			else:
				local = x_skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			var parent := x_skeleton.get_bone_parent(bone)
			var parent_name := x_skeleton.get_bone_name(parent) if parent != -1 else ""
			source_global[bone_name] = (source_global[parent_name] * local) if parent != -1 else local
			var turned: Quaternion = source_global[bone_name] * source_rest[bone_name].inverse()
			target_global[bone_name] = turned * target_rest[bone_name]
			if rotation_tracks.has(bone_name):
				var target_local: Quaternion = (target_global[parent_name].inverse() * target_global[bone_name]) if parent != -1 else target_global[bone_name]
				if not new_keys.has(bone_name):
					new_keys[bone_name] = []
				new_keys[bone_name].append([time, target_local.normalized()])
	for bone_name in new_keys:
		var track: int = rotation_tracks[bone_name]
		for key in range(animation.track_get_key_count(track) - 1, -1, -1):
			animation.track_remove_key(track, key)
		for pair in new_keys[bone_name]:
			animation.rotation_track_insert_key(track, pair[0], pair[1])
	source.free()


## X'in pelerini gövdeyle tek parça ve bacaklara bağlı: başka karakterler için yapılmış Mixamo animasyonları
## (bekleme, büyü) bacakları açıp bükünce pelerin bacakların arasında sıkışıp bozuluyordu. Bu animasyonlarda kalça ve
## bacaklar dik duruşta (kemiğin dinlenme hali) sabit tutulur; yalnızca bel, kollar ve baş oynar.
func freeze_legs(animation: Animation) -> void:
	for track in animation.get_track_count():
		var bone_name := String(animation.track_get_path(track)).get_slice(":", 1)
		if not (bone_name == RigAnimations.HIPS_BONE or bone_name.contains("UpLeg") or bone_name.contains("Leg") or bone_name.contains("Foot") or bone_name.contains("Toe")):
			continue
		var bone := x_skeleton.find_bone(bone_name)
		if bone == -1:
			continue
		var rest := x_skeleton.get_bone_rest(bone)
		var type := animation.track_get_type(track)
		for key in animation.track_get_key_count(track):
			if type == Animation.TYPE_ROTATION_3D:
				animation.track_set_key_value(track, key, rest.basis.get_rotation_quaternion())
			elif type == Animation.TYPE_POSITION_3D:
				animation.track_set_key_value(track, key, rest.origin)


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
	for i in MainScene.FIRE_POINTS.size():
		var point: Vector3 = MainScene.FIRE_POINTS[i]
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


## Oyuna geç: Ruh Kıran kapıdan yürüyerek girer (main.gd)
func finish() -> void:
	if finished:
		return
	finished = true
	MainScene.after_intro = true
	get_tree().change_scene_to_file(MAIN_SCENE)
