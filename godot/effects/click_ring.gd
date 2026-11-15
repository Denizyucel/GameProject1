# Tıklama halkası (Diablo'daki gibi): zemine tıklanan yerde yere yatık, köz kırmızısı bir halka belirir, içe doğru
# küçülerek ~0.45 sn'de söner. Kodla kurulur (sahne dosyası yok). Kullanım: ClickRing.spawn(ebeveyn, nokta)

class_name ClickRing
extends MeshInstance3D

const COLOR := Color(1.0, 0.38, 0.18) # köz kırmızısı (oyuncunun tarafı)
const LIFE := 0.45 # saniye
const START_SCALE := 1.4
const END_SCALE := 0.55
const NAVMESH_LIFT := 0.25 # navmesh zeminden bu kadar yukarıda çıkıyor (ölçüldü)

var time := 0.0
var material := StandardMaterial3D.new()


static func spawn(parent: Node, at: Vector3) -> void:
	var ring := ClickRing.new()
	parent.add_child(ring)
	ring.global_position = Vector3(at.x, floor_height(ring, at) + 0.04, at.z) # zeminle üst üste binip titremesin


## Tıklanan yerin görünen zemin yüksekliği. Oyunun mantığı y = 0'da ama salonun taş zemini ~0.25 m, gotik binanın
## meydanı ~0.36 m yüksek: navmesh zeminden 0.25 m yukarıda çıktığı için oradan okunur. Köyde engebeli zemin (Terrain).
static func floor_height(node: Node3D, at: Vector3) -> float:
	var map := node.get_world_3d().navigation_map
	var nav := NavigationServer3D.map_get_closest_point_to_segment(map, at + Vector3.UP * 3.0, at + Vector3.DOWN * 2.0)
	var from_nav := nav.y - NAVMESH_LIFT if Vector2(nav.x - at.x, nav.z - at.z).length() < 0.5 else 0.0
	return maxf(Terrain.height_at(at), from_nav)


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
