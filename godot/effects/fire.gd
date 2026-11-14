# Ateş: alev parçacıkları, yükselen duman ve titreyen turuncu ışık. Sahneye sönük gelir; ignite()
# çağrılınca bir saniyede büyüyerek tutuşur. Açılış ara sahnesinde X'in kıvılcımları rafları tutuşturur.
# Alevin ve dumanın ayarları editörde Alev ve Duman düğümlerinden.

extends Node3D

const LIGHT_ENERGY := 2.6 # ışığın ortalama parlaklığı
const FLICKER := 0.9 # titremenin genişliği
const IGNITE_TIME := 1.0

@onready var flames: GPUParticles3D = $Alev
@onready var smoke: GPUParticles3D = $Duman
@onready var light: OmniLight3D = $Isik

var burning := 0.0 # 0 = sönük, 1 = tam yanıyor
var time := randf() * 10.0 # her ateş farklı titresin


func _ready() -> void:
	light.light_energy = 0.0


func ignite() -> void:
	flames.emitting = true
	smoke.emitting = true
	create_tween().tween_property(self, "burning", 1.0, IGNITE_TIME)


func _process(delta: float) -> void:
	if burning <= 0.0:
		return
	time += delta
	# İki farklı hızdaki dalganın toplamı: düzensiz, canlı bir titreme
	var flicker := sin(time * 13.0) * 0.5 + sin(time * 7.3 + 1.7) * 0.5
	light.light_energy = (LIGHT_ENERGY + flicker * FLICKER) * burning
