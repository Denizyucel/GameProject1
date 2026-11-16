# Hareketli çarpışma: oyuncu, düşmanlar, iskeletler ve köylüler birbirinin içinden geçmesin. Fizik motoru kullanmaz: her
# karakter yerde bir daire sayılır; her fizik karesinde, herkes kendi hareketini yaptıktan sonra (bu düğüm en son
# çalışır, process_physics_priority) üst üste binen her ikili birbirinden itilir. İtme ağırlığa göre paylaşılır:
# ağır olan az kayar (oyuncu ağır: iskeletler ona yol verir, düşmanlar onu kolay kolay itemez). İtilen karakter
# navmesh'in en yakın noktasına çekilir, duvarın içine itilmez.
# main.gd açılışta ekler.

extends Node

# Grup → [yarıçap (metre), ağırlık]
const BODIES := {
	"oyuncu": [0.4, 4.0],
	"dusman": [0.45, 2.0], # düşmanın boyu (style.size) ile büyür
	"iskelet": [0.35, 1.0],
	"koylu": [0.35, 1000.0], # köylüler (npcs/villager.gd) yerinden oynamaz
}
const ROUNDS := 2 # kalabalıkta bir itme başka bir çakışma yaratabilir; iki tur çoğu zaman yeter


func _ready() -> void:
	process_physics_priority = 100 # herkesin _physics_process'inden sonra


func _physics_process(_delta: float) -> void:
	var bodies: Array[Dictionary] = []
	for group in BODIES:
		for node in get_tree().get_nodes_in_group(group):
			if not node.alive:
				continue # ölüler ve topraktan henüz çıkmamış iskeletler engel değil
			var radius: float = BODIES[group][0]
			var weight: float = BODIES[group][1]
			if group == "dusman":
				radius *= float(node.style["size"])
			if "body_radius" in node: # iskelet ve golem kendi ölçüsünü söyler (golem daha geniş ve ağır)
				radius = node.body_radius
				weight = node.body_weight
			bodies.append({"node": node, "radius": radius, "weight": weight, "moved": false})
	if bodies.size() < 2:
		return
	for round in ROUNDS:
		for i in bodies.size():
			for j in range(i + 1, bodies.size()):
				separate(bodies[i], bodies[j])
	# İtilenleri yürünebilir yere çek (yatayda: navmesh yüksekliği yerden farklı olabilir)
	for body in bodies:
		if body["moved"]:
			var node: Node3D = body["node"]
			var map: RID = node.get_world_3d().navigation_map
			var at := node.global_position
			var found := NavigationServer3D.map_get_closest_point_to_segment(map, at + Vector3.UP * 2.0, at + Vector3.DOWN * 1.0)
			node.global_position = Vector3(found.x, at.y, found.z)


func separate(a: Dictionary, b: Dictionary) -> void:
	var node_a: Node3D = a["node"]
	var node_b: Node3D = b["node"]
	var offset := Vector2(node_b.global_position.x - node_a.global_position.x, node_b.global_position.z - node_a.global_position.z)
	var distance := offset.length()
	var needed: float = a["radius"] + b["radius"]
	if distance >= needed:
		return
	# Tam üst üste ise rastgele değil, sabit bir yöne it (her karede başka yöne zıplamasın)
	var direction := offset / distance if distance > 0.001 else Vector2(1, 0).rotated(float(node_a.get_instance_id() % 628) / 100.0)
	var overlap := needed - distance
	var total: float = a["weight"] + b["weight"]
	var push_a: Vector2 = -direction * overlap * float(b["weight"]) / total
	var push_b: Vector2 = direction * overlap * float(a["weight"]) / total
	node_a.global_position += Vector3(push_a.x, 0, push_a.y)
	node_b.global_position += Vector3(push_b.x, 0, push_b.y)
	a["moved"] = true
	b["moved"] = true
