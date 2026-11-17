# Beceri çubuğu (HUD, altta can küresinin hemen sağından başlar, sağa doğru dizilir; hud.tscn Beceriler). Her beceri bir yuva
# (hud/skill_slot.gd); görsellerde tuş da yazıyor. Bu betik her kare oyunun durumuna bakıp yuvaları günceller:
#   - Iskelet (1 tuşu, iskelet kaldır): yakında (8 m) ceset varsa ve mana yetiyorsa parlak, yoksa soluk.
#   - Golem (2 tuşu, kemik golemi): hak kazanılana kadar gizli. Golem ayaktayken üstünde
#     can barı; ölünce geri sayım; hazırken mana yetmiyorsa soluk.
# Durumu main.gd'den okur (nearest_corpse, has_golem, golem, golem_cooldown).

extends HBoxContainer

@onready var skeleton_slot: Control = $Iskelet
@onready var golem_slot: Control = $Golem


func _process(_delta: float) -> void:
	var main := get_tree().current_scene
	if main == null or not "has_golem" in main:
		return
	var player: Node = main.player
	skeleton_slot.usable = player.alive and player.mana >= player.RAISE_MANA and main.nearest_corpse() != null

	golem_slot.visible = main.has_golem
	if not main.has_golem:
		return
	var golem: Variant = main.golem
	var standing := is_instance_valid(golem)
	golem_slot.bar = clampf(golem.health / golem.max_health, 0.0, 1.0) if standing else -1.0
	golem_slot.set_cooldown(0.0 if standing else main.golem_cooldown, main.GOLEM_COOLDOWN)
	golem_slot.usable = standing or (player.alive and player.mana >= main.GOLEM_MANA)
