# Ana sahneyi açıp birkaç kare çizdikten sonra ekran görüntüsü alan ve kapanan yardımcı betik.
# Değişiklikleri editörü açmadan hızlıca kontrol etmek için.
#
# Çalıştırma:  godot --path godot -s tools/screenshot.gd -- <kayıt yolu.png> [bekleme karesi]

extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://screenshot.png"
	var frames: int = int(args[1]) if args.size() > 1 else 60
	var main: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	root.add_child(main.instantiate())
	# Gölgeler ve shader'lar ilk karelerde hazırlanır; biraz bekle
	for i in frames:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(out_path)
	print("Ekran görüntüsü: ", out_path)
	quit()
