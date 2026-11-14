# Can iksiri: ölen düşmandan ara sıra düşer (main.gd, POTION_CHANCE). Düştüğü yerden küçük bir yayla
# yanına sıçrar, yerde yavaşça dönüp süzülür. Oyuncu yanına gelince (PICKUP_RADIUS) kendiliğinden alınır
# ve HEAL kadar can verir; oyuncunun canı tamsa alınmaz, yerde bekler.

extends Node3D

const HEAL := 25.0 # verdiği can (oyuncunun canı 100)
const PICKUP_RADIUS := 1.1 # metre
const POP_TIME := 0.45 # düşmandan yere sıçrama süresi (saniye)
const POP_HEIGHT := 1.2 # sıçramanın tepe yüksekliği
const SPIN := 1.6 # yerde dönme hızı (radyan/sn)
const BOB_HEIGHT := 0.06 # yerde süzülürken aşağı yukarı oynama (metre)
const BOB_SPEED := 2.5
const TAKE_TIME := 0.25 # alınınca küçülüp kaybolma süresi

@onready var body: Node3D = $Govde

var pop_from := Vector3.ZERO
var pop_to := Vector3.ZERO
var pop_time := -1.0 # sıçrıyorsa kaç saniyedir; -1 ise yerde
var age := 0.0
var taken := false


## Düşmanın öldüğü yerden (from) yanındaki bir noktaya (to) sıçrayarak düş
func drop(from: Vector3, to: Vector3) -> void:
	pop_from = from
	pop_to = to
	pop_time = 0.0
	global_position = from


func _process(delta: float) -> void:
	age += delta
	body.rotation.y += SPIN * delta
	if pop_time >= 0:
		pop_time += delta
		var t := minf(pop_time / POP_TIME, 1.0)
		global_position = pop_from.lerp(pop_to, t) + Vector3.UP * (4.0 * t * (1.0 - t) * POP_HEIGHT) # yay
		if t >= 1.0:
			pop_time = -1.0
		return
	body.position.y = (sin(age * BOB_SPEED) + 1.0) * 0.5 * BOB_HEIGHT
	if taken:
		return
	var player := get_tree().get_first_node_in_group("oyuncu") as Node3D
	if player == null or not player.alive or player.health >= player.max_health:
		return
	if player.global_position.distance_to(global_position) <= PICKUP_RADIUS:
		taken = true
		player.heal(HEAL)
		# Alındı: oyuncuya doğru yükselip küçülerek kaybol
		var tween := create_tween().set_parallel()
		tween.tween_property(self, "scale", Vector3.ONE * 0.01, TAKE_TIME).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "global_position", player.global_position + Vector3.UP * 1.2, TAKE_TIME)
		tween.chain().tween_callback(queue_free)
