# Düşman can barı (Diablo tarzı, ekranın üst ortasında tek bar). Hangi düşmanı gösterir (öncelik sırasıyla):
#   1. imlecin üzerindeki düşman, 2. oyuncunun tıklayıp kovaladığı düşman, 3. son 3 saniyede vurulan düşman.
# Üstte düşmanın adı (dövüş tarzı), altında bar: koyu kırmızı dolu kısım, vurulunca açık renkli "kayıp" kısım bir an
# kalıp iner (can küresindeki gibi). Düşman ölünce bar boşalır ve yavaşça söner. Kimse yoksa görünmez.
# Boyut, renk ve yer hud.tscn'de editörden (DusmanCani).

extends Control

const RECENT_HIT := 3.0 # vurulan düşman bu kadar saniye gösterilir
const LOST_DELAY := 0.4 # kayıp kısmın açık renkte bekleme süresi
const LOST_SPEED := 0.8 # kayıp kısmın inme hızı (bar / saniye)
const FADE_SPEED := 4.0 # görünme / sönme hızı (saniyede)
const DEAD_LINGER := 0.8 # ölen düşmanın boş barı bu kadar saniye kalır

@onready var name_label: Label = $Ad
@onready var lost_rect: ColorRect = $Kayip
@onready var fill_rect: ColorRect = $Dolu

var player: Node3D
var shown: Node3D # şu an gösterilen düşman
var fill := 1.0
var lost := 1.0
var lost_wait := 0.0
var dead_left := 0.0
var full_width := 0.0


func _ready() -> void:
	full_width = fill_rect.size.x
	modulate.a = 0.0


func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("oyuncu")
		if player == null:
			return
	var enemy := pick_enemy()
	if enemy != shown:
		shown = enemy
		if shown:
			# Yeni düşman: bar onun canından başlar, kayıp kısım sıfırlanır
			fill = current_fill(shown)
			lost = fill
			lost_wait = 0.0
			# Az önce vurulduğu için açıldıysa o vuruşun götürdüğü kısım da bir an açık renkte görünsün
			if Time.get_ticks_msec() / 1000.0 - shown.hit_time < 0.3:
				lost = minf(1.0, fill + shown.last_damage / float(shown.style["health"]))
				lost_wait = LOST_DELAY
			dead_left = DEAD_LINGER
			name_label.text = shown.style["name"]
	if shown:
		var now_fill := current_fill(shown)
		if now_fill < fill - 0.001:
			lost = maxf(lost, fill)
			lost_wait = LOST_DELAY
		fill = now_fill
		if not shown.alive:
			dead_left -= delta
	if lost_wait > 0:
		lost_wait -= delta
	else:
		lost = move_toward(lost, fill, LOST_SPEED * delta)
	lost = maxf(lost, fill)
	fill_rect.size.x = full_width * fill
	lost_rect.size.x = full_width * lost
	var visible_target := 1.0 if shown and (shown.alive or dead_left > 0) else 0.0
	modulate.a = move_toward(modulate.a, visible_target, FADE_SPEED * delta)


func current_fill(enemy: Node3D) -> float:
	if not is_instance_valid(enemy) or not enemy.alive:
		return 0.0
	return clampf(enemy.health / float(enemy.style["health"]), 0.0, 1.0)


func pick_enemy() -> Node3D:
	if not player.alive:
		return null
	var hovered: Node3D = player.enemy_under_cursor(get_viewport().get_mouse_position())
	if hovered:
		return hovered
	if player.is_target_valid():
		return player.attack_target
	# Son vurulan (oyuncu, iskelet ya da mızrak); ölen de bir süre kalsın diye şu ankini koru
	if shown and is_instance_valid(shown) and (not shown.alive) and dead_left > 0:
		return shown
	var best: Node3D = null
	var best_time := -INF
	var now := Time.get_ticks_msec() / 1000.0
	for enemy in get_tree().get_nodes_in_group("dusman"):
		if now - enemy.hit_time < RECENT_HIT and enemy.hit_time > best_time:
			best = enemy
			best_time = enemy.hit_time
	return best
