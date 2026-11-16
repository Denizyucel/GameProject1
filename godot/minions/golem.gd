# Kemik golemi: gotik binanın mahzenindeki rün halkasında kazanılan büyük minion (yan görev zincirinin sonu).
# X'in halkaya bağladığı kemikler tek bir beden hâlinde, gönüllü olarak kalkar. İskeletin betiğini (minion.gd)
# genişletir: efendisini takip eder, yakındaki düşmana koşup vurur, canı var, düşmanlar ona da saldırır.
# Farkları: silahsız (pençesiyle vurur), iri (2.55 m), dayanıklı ve ağır vurur; vuruşu ekranı hafifçe sarsar.
# Aynı anda tek golem olur; 2 tuşuyla çağrılır (main.gd: summon_golem). Model: assets/minion/bone-golem.glb
# (Meshy SmartRig; içinde Walking ve Running). Bekleme ve vuruşlar düşmanların "Creature" animasyonlarından.

extends "res://minions/minion.gd"

const GOLEM_ANIMATIONS := [
	["idle", "res://assets/animations/creature/mutant-breathing-idle.fbx", "mixamo_com", true],
	["run", "res://assets/minion/bone-golem.glb", "Running", true],
	["vurus1", "res://assets/animations/creature/mutant-swiping.fbx", "mixamo_com", false],
	["vurus2", "res://assets/animations/sword/attack3.fbx", "mixamo_com", false],
]
const HIT_SHAKE := 0.25 # vuruşu değince ekran sarsıntısı (oyuncunun kılıcı 0.35)


func _init() -> void:
	kind = "golem"
	animations = GOLEM_ANIMATIONS
	move_speed = 3.3
	slot_distance = 2.4 # iri olduğu için efendisinden biraz uzakta durur
	attack_range = 1.9
	hit_reach = 2.7
	damage = 14.0 # iskeletin yaklaşık üç katı; düşmanı şaşırtır (enemy.STUN_MIN_DAMAGE 8)
	max_health = 160.0
	attack_time_scale = 1.2
	attack_cooldown = 0.8
	rise_duration = 1.5
	rise_depth = 2.7
	body_radius = 0.65
	body_weight = 3.0


func _ready() -> void:
	super()
	add_to_group("golem")


## Silahsız: pençesiyle vurur
func attach_gear() -> void:
	pass


func on_hit_landed() -> void:
	GameCamera.shake(HIT_SHAKE)
