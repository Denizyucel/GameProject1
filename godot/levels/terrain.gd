# Zemin yüksekliği. Oyunun mantığı düz kalır (herkesin konumu y = 0'da; yol bulma, uzaklıklar, vuruşlar
# hep yatay düzlemde); engebeli yerde yalnızca GÖRÜNTÜ zeminin yüksekliği kadar yukarı kaldırılır:
# karakterler modellerini, efektler ve eşyalar kendilerini Terrain.height(x, z) kadar kaldırır.
# Engebeli bölge yoksa (data null) ya da nokta bölgenin dışındaysa yükseklik 0'dır.

class_name Terrain

static var data: TerrainData # engebeli bölgenin verisi; levels/village.gd sahneye girince koyar


## Dünyadaki (x, z) noktasında zeminin yüksekliği (metre); komşu dört karenin arasında yumuşak geçişli
static func height(x: float, z: float) -> float:
	if data == null:
		return 0.0
	var fx := (x - data.origin.x) / data.cell - 0.5
	var fz := (z - data.origin.y) / data.cell - 0.5
	if fx < -0.5 or fz < -0.5 or fx > data.size_x - 0.5 or fz > data.size_z - 0.5:
		return 0.0
	var x0 := clampi(floori(fx), 0, data.size_x - 1)
	var z0 := clampi(floori(fz), 0, data.size_z - 1)
	var x1 := mini(x0 + 1, data.size_x - 1)
	var z1 := mini(z0 + 1, data.size_z - 1)
	var tx := clampf(fx - x0, 0.0, 1.0)
	var tz := clampf(fz - z0, 0.0, 1.0)
	var north := lerpf(data.heights[z0 * data.size_x + x0], data.heights[z0 * data.size_x + x1], tx)
	var south := lerpf(data.heights[z1 * data.size_x + x0], data.heights[z1 * data.size_x + x1], tx)
	return lerpf(north, south, tz)


## Aynı şey, bir konum için
static func height_at(point: Vector3) -> float:
	return height(point.x, point.z)


## Noktayı zeminin üstüne koy (y = zemin yüksekliği)
static func on_ground(point: Vector3) -> Vector3:
	return Vector3(point.x, height(point.x, point.z), point.z)


## Kameradan gelen ışının zemine değdiği nokta (y = 0 olarak döner: oyunun mantığı düz). Zemin engebeliyse
## birkaç adımda yaklaşır: ışını o anki tahminin yüksekliğindeki düzlemle keser, yüksekliği yeniden okur.
static func ray_to_ground(origin: Vector3, direction: Vector3) -> Variant:
	var hit = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	if hit == null or data == null:
		return hit
	for i in 6:
		var again = Plane(Vector3.UP, height(hit.x, hit.z)).intersects_ray(origin, direction)
		if again == null:
			break
		hit = again
	return Vector3(hit.x, 0, hit.z)
