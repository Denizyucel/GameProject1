# Engebeli bir bölgenin zemin bilgisi: kare kare yükseklik ve "yürünemez" işareti.
# tools/build_village_terrain.gd köy modelinden üretir (levels/harabe_koy_terrain.res).

class_name TerrainData
extends Resource

@export var cell := 0.25 # bir karenin kenarı (metre)
@export var origin := Vector2.ZERO # ızgaranın kuzeybatı köşesi (dünya x, z)
@export var size_x := 0 # x boyunca kare sayısı
@export var size_z := 0
@export var heights := PackedFloat32Array() # kare ortasındaki zemin yüksekliği (satır satır: z * size_x + x)
@export var blocked := PackedByteArray() # 1 = yürünemez (ev, duvar, dik yamaç)
