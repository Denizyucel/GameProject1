# Mixamo kemik adlı karakterler için ortak animasyon işleri: başka bir dosyadaki animasyonu bu modele
# uyarlamak, yürüme hızını ayaktan ölçmek, vuruşun darbe anını bulmak. Oyuncu ve düşmanlar kullanır.

class_name RigAnimations

const HIPS_BONE := "mixamorig_Hips"


## Bir dosyadaki animasyonun kopyasını al ve hedef modelin iskeletine uyarla: iz yolları hedef iskelete
## yönlendirilir, kalça konumu iki karakterin kalça yüksekliği oranında ölçeklenir.
static func take(path: String, animation_name: String, player: AnimationPlayer, skeleton: Skeleton3D, loop := true) -> Animation:
	var source: Node = (load(path) as PackedScene).instantiate()
	var source_player: AnimationPlayer = source.find_child("AnimationPlayer")
	var source_skeleton: Skeleton3D = source.find_child("Skeleton3D")
	var animation: Animation = source_player.get_animation(animation_name).duplicate()

	var target_path := String(player.get_node(player.root_node).get_path_to(skeleton))
	var height_ratio := hips_height(skeleton) / hips_height(source_skeleton)
	for track in animation.get_track_count():
		var bone := String(animation.track_get_path(track)).get_slice(":", 1)
		animation.track_set_path(track, NodePath(target_path + ":" + bone))
		if bone == HIPS_BONE and animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
			for key in animation.track_get_key_count(track):
				animation.track_set_key_value(track, key, animation.track_get_key_value(track, key) * height_ratio)
	source.free()
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return animation


static func hips_height(target: Skeleton3D) -> float:
	var bone := target.find_bone(HIPS_BONE)
	return target.get_bone_global_rest(bone).origin.y if bone != -1 else 1.0


## Kalçanın yatay kaymasını (root motion) sil: karakteri oyun yürütür, animasyon yerinde oynasın
static func remove_root_motion(animation: Animation) -> void:
	for track in animation.get_track_count():
		if not String(animation.track_get_path(track)).ends_with(":" + HIPS_BONE):
			continue
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		var first: Vector3 = animation.track_get_key_value(track, 0)
		for key in animation.track_get_key_count(track):
			var value: Vector3 = animation.track_get_key_value(track, key)
			animation.track_set_key_value(track, key, Vector3(first.x, value.y, first.z))


## Yürüme/koşma animasyonunda ayakların karakteri ne hızla taşıdığı (metre / saniye, oyundaki ölçekte).
## Yere basan ayak bir adım boyunca geriye kayar; bir döngüde iki adım atılır.
static func stride_speed(player: AnimationPlayer, skeleton: Skeleton3D, animation_name: String) -> float:
	var foot := skeleton.find_bone("mixamorig_LeftFoot")
	var animation := player.get_animation(animation_name)
	if foot == -1 or animation == null:
		return 0.0
	var min_z := INF
	var max_z := -INF
	player.play(animation_name)
	const SAMPLES := 40
	for i in SAMPLES:
		player.seek(animation.length * i / SAMPLES, true)
		var z := skeleton.get_bone_global_pose(foot).origin.z
		min_z = minf(min_z, z)
		max_z = maxf(max_z, z)
	player.stop()
	return 2.0 * (max_z - min_z) / animation.length * skeleton.global_basis.get_scale().x


## Bir vuruşun darbe anı (0..1): sağ elin en hızlı hareket ettiği an (kılıç ya da pençe en hızlı o an iner)
static func fastest_hand_moment(player: AnimationPlayer, skeleton: Skeleton3D, animation_name: String, fallback := 0.45) -> float:
	var hand := skeleton.find_bone("mixamorig_RightHand")
	var animation := player.get_animation(animation_name)
	if hand == -1 or animation == null:
		return fallback
	player.play(animation_name)
	const SAMPLES := 60
	var previous := Vector3.ZERO
	var best_speed := -1.0
	var best_step := 0
	for step in SAMPLES + 1:
		player.seek(animation.length * step / SAMPLES, true)
		var current := skeleton.get_bone_global_pose(hand).origin
		if step > 0 and current.distance_to(previous) > best_speed:
			best_speed = current.distance_to(previous)
			best_step = step
		previous = current
	player.stop()
	return float(best_step) / SAMPLES


## Ajanın bulduğu yolda bir adım yürü. Gidilen yönü döndürür (yürümediyse sıfır); dönüşü çağıran yapar.
static func step_along_path(agent: NavigationAgent3D, body: Node3D, speed: float, delta: float) -> Vector3:
	if agent.is_navigation_finished():
		return Vector3.ZERO
	var next := agent.get_next_path_position()
	var to_next := Vector3(next.x - body.global_position.x, 0, next.z - body.global_position.z)
	var step := speed * delta
	if to_next.length() <= step:
		body.global_position = Vector3(next.x, body.global_position.y, next.z)
	else:
		body.global_position += to_next.normalized() * step
	return to_next
