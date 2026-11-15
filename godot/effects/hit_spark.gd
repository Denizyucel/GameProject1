# Darbe kıvılcımı: kılıç, pençe ya da mızrak düşmanın zırhına çarpınca göğüs hizasında saçılan beyaz-sarı
# kıvılcımlar ve bir an parlayan küçük ışık. Kıvılcımlar vuranın tersine (darbenin gittiği yöne) saçılır.
# Sayısı, hızı, rengi editörde Kivilcimlar düğümünden ayarlanır. Efekt kendi kendine biter ve silinir.
# Kullanım: HitSpark.burst(sahne, nereden_vuruldu, düşmanın_konumu, güç 0..1)

class_name HitSpark
extends Node3D

const SCENE := preload("res://effects/hit_spark.tscn")
const CHEST := 1.1 # düşmanın göğsü: ayağından bu kadar yukarısı
const DURATION := 0.6
const LIGHT_PEAK := 3.0
const LIGHT_TIME := 0.15

@export var strength := 1.0 # 0..1; iskeletin hafif vuruşu daha az kıvılcım saçar

@onready var sparks: GPUParticles3D = $Kivilcimlar
@onready var light: OmniLight3D = $Isik

var time := 0.0


## Düşmanın göğsünde, vurandan uzağa doğru saçılan bir kıvılcım efekti koyar
static func burst(parent: Node, from: Vector3, at: Vector3, power: float) -> void:
	var away := Vector3(at.x - from.x, 0, at.z - from.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var spark: HitSpark = SCENE.instantiate()
	spark.strength = power
	parent.add_child(spark)
	# Düşmanın vurana bakan yüzeyinde (merkezden 0.3 m öne) çıkar; +z darbenin gittiği yön
	spark.global_position = Terrain.on_ground(at) + Vector3.UP * CHEST - away * 0.3
	spark.global_basis = Basis.looking_at(-away)


func _ready() -> void:
	sparks.amount_ratio = lerpf(0.4, 1.0, strength)
	sparks.restart()
	light.light_energy = LIGHT_PEAK * strength


func _process(delta: float) -> void:
	time += delta
	light.light_energy = LIGHT_PEAK * strength * maxf(0.0, 1.0 - time / LIGHT_TIME)
	if time >= DURATION:
		queue_free()
