# Bir modeli önden ve yandan, düz ışıkta çizip kaydeden yardımcı betik (yeni gelen modeli görmek için).
# Çalıştırma:  godot --path godot --resolution 900x700 -s tools/model_shot.gd -- res://...glb <çıktı.png>

extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#2a2730")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	world.add_child(light)
	for i in 2:
		var model: Node3D = (load(args[0]) as PackedScene).instantiate()
		model.position.x = -0.9 + i * 1.8
		model.rotation_degrees.y = 0 if i == 0 else 90
		world.add_child(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.1
	cam.position = Vector3(0, 0.9, 5)
	world.add_child(cam)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit()
