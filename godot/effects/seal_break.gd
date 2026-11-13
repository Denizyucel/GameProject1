# Mühür kırılma anı (Hikaye.md, çekirdek döngü): Altın Ölümsüz'ün sahte ölümsüzlük mührü kırılır.
#   1. Kırılma: göğüs hizasında altın parlama, açılan ışık halkası, dört yana saçılan altın kıymıklar
#   2. Ruh: mavi parçacıklar dönerek göğe yükselir; ışık altından maviye döner ve yavaşça söner
# Parçacıkların sayısı, hızı, rengi editörde Kiymiklar ve Ruh düğümlerinden ayarlanır.
# release = true: kırılacak mühür yok (serbest bırakılan iskelet): altın yok, sadece mavi parlama ve ruh.
# Efekt kendi kendine biter ve silinir.

extends Node3D

const GOLD := Color("#ffc95a")
const SOUL_BLUE := Color("#7cc4ff")
const DURATION := 3.2 # bu kadar saniye sonra silinir
const FLASH_TIME := 0.35
const RING_TIME := 0.5
const RING_SCALE := 1.6 # halkanın en son boyu (kat)
const SOUL_DELAY := 0.15 # ruh kırılmadan bu kadar sonra yükselmeye başlar
# Işık: altın kalma süresi, maviye dönüş süresi, en parlak hali, kaç saniyede söndüğü, ne kadar yükseldiği
const LIGHT_GOLD_TIME := 0.3
const LIGHT_TO_BLUE := 0.6
const LIGHT_PEAK := 6.0
const LIGHT_TIME := 3.0
const LIGHT_RISE := 1.2

@export var release := false

@onready var flash: MeshInstance3D = $Parlama
@onready var ring: MeshInstance3D = $Halka
@onready var shards: GPUParticles3D = $Kiymiklar
@onready var soul: GPUParticles3D = $Ruh
@onready var light: OmniLight3D = $Isik

var time := 0.0


func _ready() -> void:
	var burst := SOUL_BLUE if release else GOLD
	(flash.material_override as StandardMaterial3D).albedo_color = burst
	(ring.material_override as StandardMaterial3D).albedo_color = burst
	light.light_color = burst
	light.light_energy = 0.0
	if not release:
		shards.restart() # tek seferlik: hepsini birden fırlat
	get_tree().create_timer(SOUL_DELAY, false).timeout.connect(soul.restart)


func _process(delta: float) -> void:
	time += delta
	var t := time

	# Parlama: hızla büyüyüp söner
	var f := minf(t / FLASH_TIME, 1.0)
	flash.scale = Vector3.ONE * (0.3 + f * 1.4)
	(flash.material_override as StandardMaterial3D).albedo_color.a = 1.0 - f
	flash.visible = f < 1.0

	# Halka: dışa açılırken söner
	var r := minf(t / RING_TIME, 1.0)
	ring.scale = Vector3.ONE * (0.2 + (1.0 - pow(1.0 - r, 3)) * RING_SCALE)
	(ring.material_override as StandardMaterial3D).albedo_color.a = (1.0 - r) * 0.9
	ring.visible = r < 1.0

	# Işık: altın → mavi, kırılma anında en parlak, sonra yavaşça söner ve ruhla biraz yükselir
	var life := minf(t / LIGHT_TIME, 1.0)
	var gold_time := -LIGHT_TO_BLUE if release else LIGHT_GOLD_TIME
	var to_blue := clampf((t - gold_time) / LIGHT_TO_BLUE, 0.0, 1.0)
	light.light_color = GOLD.lerp(SOUL_BLUE, to_blue)
	light.light_energy = LIGHT_PEAK * minf(t / 0.05, 1.0) * pow(1.0 - life, 2)
	light.position.y = 1.2 + life * LIGHT_RISE

	if t >= DURATION:
		queue_free()
