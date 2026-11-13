# Silahı ve kalkanı Mixamo kemik adlı bir karakterin eline takma.
# Karakter de iskeletler de aynı kemik adlarını kullandığı için hepsi bunu kullanır.

class_name Weapon

# Bir elin kemikleri: el ve yumruğun iki ucundaki parmak dipleri. İşaret parmağı yoksa (yeni Necromancer
# modelinde yok) orta parmak kullanılır; ikisi de yumruğun aynı tarafında.
const FINGER_A := ["HandIndex1", "HandMiddle1"]
const FINGER_B := "HandPinky1"


## Pivotu modelin eline bağla ve item'ı pivotun içine koy. Pivotun eksenleri:
## x = yan, y = sap (yumruğun içinden öne), z = bıçak (elin sırtı yönünde).
## Elde gerekli kemikler yoksa false döner. skeleton sahnede (ağaçta) olmalı.
static func attach_to_hand(skeleton: Skeleton3D, hand: String, item: Node3D) -> bool:
	var bone := skeleton.find_bone("mixamorig_%sHand" % hand)
	var finger_a := -1
	for finger in FINGER_A:
		finger_a = skeleton.find_bone("mixamorig_%s%s" % [hand, finger])
		if finger_a != -1:
			break
	var finger_b := skeleton.find_bone("mixamorig_%s%s" % [hand, FINGER_B])
	if bone == -1 or finger_a == -1 or finger_b == -1:
		return false

	# Parmak kemiklerinin dinlenme konumu elin kendi ekseninde (el onların ebeveyni)
	var a := skeleton.get_bone_rest(finger_a).origin
	var b := skeleton.get_bone_rest(finger_b).origin
	# Sap: serçe parmak dibinden öteki parmağın dibine (kılıç tutar gibi, uç öne bakar)
	var shaft := (a - b).normalized()
	# Bıçak sapa dik, elin sırtı yönünde (parmakların tersi, elin -y ekseni)
	var blade := (Vector3(0, -1, 0) + shaft * shaft.y).normalized()
	var side := shaft.cross(blade)

	# BoneAttachment3D: bir kemiği her karede takip eden düğüm; içine konan her şey elle birlikte hareket eder
	var attachment := BoneAttachment3D.new()
	attachment.name = "%sElSilahi" % hand
	attachment.bone_name = skeleton.get_bone_name(bone)
	skeleton.add_child(attachment)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.transform = Transform3D(Basis(side, shaft, blade), (a + b) / 2)
	# Karakter ölçeklendiyse silah da ölçeklenmesin: silahın boyu metre olarak kalsın
	pivot.scale = Vector3.ONE / skeleton.global_basis.get_scale().x
	attachment.add_child(pivot)
	pivot.add_child(item)
	return true


## Kılıç modelini pivota uygun hale getir: kabzası pivotun ortasında, bıçağı pivotun y ekseni boyunca,
## keskin kenarı z yönünde. Meshy kılıçlarında bıçak -y'de, kabza +y'de, geniş taraf x'te.
## length: uçtan kabzaya boy (metre); grip: elin tuttuğu yer, bıçak ucundan ölçülen boy oranı.
static func prepare_sword(model: Node3D, length: float, grip: float) -> Node3D:
	var box := scene_aabb(model, Transform3D.IDENTITY)
	var center := box.get_center()
	# İç düğüm: modeli, tutulan nokta (kabzanın ortası) tam ortaya gelecek şekilde kaydır
	var inner := Node3D.new()
	model.position = Vector3(-center.x, -(box.position.y + box.size.y * grip), -center.z)
	inner.add_child(model)
	# Dış düğüm: döndür ve ölçekle. Model x → pivot z, model -y → pivot y, model z → pivot x.
	var sword := Node3D.new()
	sword.name = "Kilic"
	sword.basis = Basis(Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(1, 0, 0)).scaled(Vector3.ONE * length / box.size.y)
	sword.add_child(inner)
	return sword


## Bir sahnedeki bütün şekillerin, sahnenin kendi eksenindeki toplam sınır kutusu
static func scene_aabb(node: Node, parent: Transform3D) -> AABB:
	var xform := parent
	if node is Node3D:
		xform = parent * (node as Node3D).transform
	var box := AABB()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		box = xform * (node as MeshInstance3D).mesh.get_aabb()
	for child in node.get_children():
		var child_box := scene_aabb(child, xform)
		if child_box.size != Vector3.ZERO:
			box = child_box if box.size == Vector3.ZERO else box.merge(child_box)
	return box
