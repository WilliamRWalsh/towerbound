extends SceneTree
## Compares two folders of screenshots from tools/capture_screens.gd, prints how much of each
## image changed, and writes a diff image (changed pixels in red over a dimmed copy) for each
## pair that differs:
##   godot --headless --path . -s tools/diff_screens.gd -- <before dir> <after dir> <diff dir>

## Per-channel difference (0–1) below which a pixel counts as unchanged.
const THRESHOLD := 0.04


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: -- <before dir> <after dir> <diff dir>")
		quit(1)
		return
	var before_dir: String = args[0]
	var after_dir: String = args[1]
	var diff_dir: String = args[2]
	DirAccess.make_dir_recursive_absolute(diff_dir)
	var files := DirAccess.get_files_at(before_dir)
	files.sort()
	for file in files:
		if not file.ends_with(".png"):
			continue
		var before := Image.load_from_file(before_dir.path_join(file))
		var after_path := after_dir.path_join(file)
		if not FileAccess.file_exists(after_path):
			print("%-34s missing after" % file)
			continue
		var after := Image.load_from_file(after_path)
		if before.get_size() != after.get_size():
			print("%-34s size %s -> %s" % [file, before.get_size(), after.get_size()])
			continue
		var changed := 0
		var diff := Image.create(before.get_width(), before.get_height(), false, Image.FORMAT_RGB8)
		for y in before.get_height():
			for x in before.get_width():
				var a := before.get_pixel(x, y)
				var b := after.get_pixel(x, y)
				if maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) > THRESHOLD:
					changed += 1
					diff.set_pixel(x, y, Color.RED)
				else:
					diff.set_pixel(x, y, b.darkened(0.7))
		var share := 100.0 * changed / (before.get_width() * before.get_height())
		print("%-34s %6.2f%% changed" % [file, share])
		if changed > 0:
			diff.save_png(diff_dir.path_join(file))
	quit()
