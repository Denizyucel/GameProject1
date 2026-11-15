# Tıklama halkası (Diablo'daki gibi): zemine tıklanan yerde yere yatık, köz kırmızısı bir halka belirir, içe doğru
# küçülerek ~0.45 sn'de söner. Kodla kurulur (sahne dosyası yok). Kullanım: ClickRing.spawn(ebeveyn, nokta)

class_name ClickRing
extends MeshInstance3D

const COLOR := Color(1.0, 0.38, 0.18) # köz kırmızısı (oyuncunun tarafı)
const LIFE := 0.45 # saniye
const START_SCALE := 1.4
const END_SCALE := 0.55

var time := 0.0
var material := StandardMaterial3D.new()


static func spawn(parent: Node, at: Vector3) -> void:
	var ring := ClickRing.new()
	parent.add_child(ring)
	ring.global_position = Vector3(at.x, Terrain.visible_floor(ring, at) + 0.04, at.z) # zeminle üst üste binip titremesin


func _ready() -> void:
	var torus := TorusMesh.new() # halka yatay düzlemde (y ekseni çevresinde) durur
	torus.inner_radius = 0.32
	torus.outer_radius = 0.4
	torus.rings = 32
	torus.ring_segments = 6
	mesh = torus
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = COLOR
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	update_look()


func _process(delta: float) -> void:
	time += delta
	if time >= LIFE:
		queue_free()
		return
	update_look()


func update_look() -> void:
	var t := time / LIFE
	var size := lerpf(START_SCALE, END_SCALE, 1.0 - pow(1.0 - t, 2)) # hızlı başlar, yavaşlar
	scale = Vector3(size, 0.15, size) # basık: yere yatık ince bir halka
	material.albedo_color.a = 1.0 - t * t
