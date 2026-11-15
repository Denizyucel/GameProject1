# Hit stop (darbe yavaşlaması): oyuncunun kılıcı isabet edince oyun bir anlığına çok yavaşlar
# (Engine.time_scale küçülür), sonra yumuşakça hızlanıp normal hızına (1) döner. Göz bunu "tok bir darbe" olarak
# algılar. Süre gerçek saatle ölçülür. Hızı her kare ağaçtaki küçük bir yardımcı düğüm ayarlar (oyun yavaşken de
# çalışır, PROCESS_MODE_ALWAYS); süre bitince hızı kesin olarak 1'e çeker, yavaşlıkta takılı kalamaz.
# Kullanım: HitStop.freeze(saniye) her yerden. Üst üste gelirse yenisi baştan başlar.

class_name HitStop
extends Node

const SLOW := 0.1 # darbe anındaki oyun hızı (0 = tam durur, 1 = normal)

static var helper: HitStop
static var start_usec := 0
static var duration_usec := 0


static func freeze(seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if helper == null or not is_instance_valid(helper):
		helper = HitStop.new()
		helper.name = "HitStop"
		helper.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(helper)
	start_usec = Time.get_ticks_usec()
	duration_usec = int(seconds * 1_000_000.0)
	Engine.time_scale = SLOW


func _process(_delta: float) -> void:
	if duration_usec <= 0:
		return
	var t := float(Time.get_ticks_usec() - start_usec) / duration_usec
	if t >= 1.0:
		duration_usec = 0
		Engine.time_scale = 1.0
		return
	# Yavaştan normale: önce yavaş kalır, sonra hızlanarak 1'e varır
	Engine.time_scale = lerpf(SLOW, 1.0, t * t)


func _exit_tree() -> void:
	Engine.time_scale = 1.0 # sahne kapanırken yavaş kalmasın
