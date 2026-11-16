# HUD'daki golem yuvasının simgesini üretir: golem modelinin başını saydam zeminde, önden çizip kaydeder.
# Kaynak: assets/minion/bone-golem.glb  →  Çıktı: assets/hud/golem-icon.png (kare; golem_slot.gd daire içine çizer).
# Model değişirse yeniden çalıştır, sonra `godot --headless --path godot --import`.
# Çalıştırma:  godot --path godot --resolution 256x256 -s tools/make_golem_icon.gd

extends SceneTree

const MODEL := "res://assets/minion/bone-golem.glb"
const OUTPUT := "res://assets/hud/golem-icon.png"
const HEAD_HEIGHT := 1.55 # kafatasının ortası (model 1.7 m)
const VIEW := 0.44 # karenin gördüğü yükseklik (metre): kafatası karenin üçte ikisini doldurur


func _initialize() -> void:
	root.transparent_bg = true
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	world.add_child(env)
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 30, 0)
	light.light_energy = 1.4
	world.add_child(light)
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	model.rotation_degrees.y = -18 # hafif yandan
	world.add_child(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = VIEW
	cam.position = Vector3(0, HEAD_HEIGHT, 5)
	world.add_child(cam)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("Kaydedildi: %s (%d x %d)" % [OUTPUT, image.get_width(), image.get_height()])
	quit()
