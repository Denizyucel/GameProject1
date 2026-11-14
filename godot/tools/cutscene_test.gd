# Açılış ara sahnesini baştan sona oynatıp zaman çizelgesinin önemli anlarında ekran görüntüsü alan
# yardımcı betik; sonunda oyuna geçişi ve karakterin kapıdan yürüyerek girmesini da kontrol eder.
# Çalıştırma:  godot --path godot --resolution 1280x720 -s tools/cutscene_test.gd -- <klasör>

extends SceneTree

# [zaman çizelgesindeki an (saniye), dosya adı]
const MOMENTS := [
	[4.0, "01-muhurler"], [9.0, "02-x-giriyor"], [16.5, "03-bekleyis"], [19.7, "04-altina-donus"],
	[21.3, "05-emis"], [23.5, "06-yangin"], [27.0, "07-cikis"],
]


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var cutscene: Node = (load("res://cutscenes/acilis.tscn") as PackedScene).instantiate()
	root.add_child(cutscene)
	current_scene = cutscene
	var timeline: AnimationPlayer = cutscene.get_node("Senaryo")
	for moment in MOMENTS:
		while is_instance_valid(timeline) and timeline.current_animation_position < moment[0]:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir + "/%s.png" % moment[1])
		print("%5.1f sn: %s" % [moment[0], moment[1]])

	# Bitince oyun sahnesine geçmeli ve karakter yerden kalkmalı
	while current_scene == cutscene or current_scene == null:
		await process_frame
	var player = current_scene.get_node("Player")
	await physics_frame
	print("Oyuna geçildi: oyuncu %s, giriyor mu %s, animasyon %s" % [player.global_position, player.entering, player.animation_player.current_animation])
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/08-giris.png")
	var started := Time.get_ticks_msec()
	while player.entering:
		await physics_frame
	print("Vardı (%.1f sn): oyuncu %s, animasyon %s, meşgul mü %s" % [(Time.get_ticks_msec() - started) / 1000.0, player.global_position, player.animation_player.current_animation, player.is_busy()])
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/09-ne-oldu.png")
	quit()
