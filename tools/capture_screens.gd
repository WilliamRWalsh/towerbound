extends SceneTree
## Renders reference screenshots of the battle in fixed situations, for reviewing visual changes
## side by side. Needs a display (not --headless):
##   godot --path . --fixed-fps 60 -s tools/capture_screens.gd -- <output dir>
## Writes <size>_<name>.png for 720 × 1280 and 720 × 1560.

const Driver := preload("res://tests/support/battle_driver.gd")
const SIZES := [Vector2i(720, 1280), Vector2i(720, 1560)]

var _out := ""
var _host: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("user://screens")
	DirAccess.make_dir_recursive_absolute(_out)
	_host = Node.new()
	root.add_child(_host)
	_run.call_deferred()


func _run() -> void:
	for size: Vector2i in SIZES:
		var prefix := "%dx%d" % [size.x, size.y]
		await _prepare(size, prefix)
		await _aim_tower(size, prefix)
		await _discard(size, prefix)
		await _chooser(size, prefix)
		await _reloading(size, prefix)
		await _combat(size, prefix)
		await _defeat(size, prefix)
	print("Screenshots written to ", _out)
	quit()


func _start(size: Vector2i, level: LevelConfig = null) -> Driver:
	for child in _host.get_children():
		child.queue_free()
	var d := Driver.new(_host, level, size)
	d.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return d


func _snap(d: Driver, file: String) -> void:
	await RenderingServer.frame_post_draw
	d.viewport.get_texture().get_image().save_png(_out.path_join(file + ".png"))


func _prepare(size: Vector2i, prefix: String) -> void:
	var d := _start(size)
	await d.advance(1.5)
	await _snap(d, prefix + "_01_prepare")


func _aim_tower(size: Vector2i, prefix: String) -> void:
	var d := _start(size, Driver.make_level([Driver.ARCHER, Driver.CANNON, Driver.UPGRADE, Driver.FIREBALL], 999.0))
	await d.advance(6.0)  # let the opening banners pass
	await d.tap_card("Archer Tower")
	await d.hover(d.cell_pos(d.cell_near_road(100.0)))
	await d.advance(0.3)
	await _snap(d, prefix + "_02_aim_tower")
	await d.press_cancel()
	await d.tap_card("Fireball")
	await d.hover(d.road_pos(900.0))
	await d.advance(0.3)
	await _snap(d, prefix + "_03_aim_fireball")


func _discard(size: Vector2i, prefix: String) -> void:
	var d := _start(size, Driver.make_level([Driver.BARRICADE, Driver.OIL, Driver.CHILL, Driver.REPAIR], 999.0))
	await d.advance(6.0)  # let the opening banners pass
	await d.press_discard()
	await d.advance(0.3)
	await _snap(d, prefix + "_04_discard")


func _chooser(size: Vector2i, prefix: String) -> void:
	var d := _start(size, Driver.make_level([Driver.UPGRADE, Driver.OIL, Driver.CHILL, Driver.REPAIR], 999.0))
	await d.advance(6.0)  # let the opening banners pass
	var cell := d.buildable_cells()[30]
	d.place_tower(cell)
	await d.play_card("Upgrade", d.cell_pos(cell))
	await d.advance(0.3)
	await _snap(d, prefix + "_05_upgrade_chooser")


func _reloading(size: Vector2i, prefix: String) -> void:
	var d := _start(size, Driver.make_level([Driver.UPGRADE, Driver.OIL, Driver.CHILL, Driver.REPAIR], 999.0))
	await d.advance(6.0)  # let the opening banners pass
	d.silence_turrets()
	var near := d.cell_near_road(100.0)
	var tower := d.place_tower(near, Driver.CANNON)
	var upgraded := d.place_tower(d.buildable_cells()[45])
	d.upgrade_rate(upgraded)
	d.upgrade_ammo(upgraded)
	for wave in 2:
		d.begin_wave()
		var enemy := d.spawn(Driver.SKELETON, maxf(0.0, d.progress_near(d.cell_pos(near)) - 60.0))
		await d.run_until(func() -> bool: return not is_instance_valid(enemy) or not enemy.is_alive(), 6.0)
		d.end_wave()
	await d.advance(2.0)
	await _snap(d, prefix + "_06_reloading")


func _combat(size: Vector2i, prefix: String) -> void:
	var d := _start(size, Driver.make_level([Driver.FIREBALL, Driver.OIL, Driver.CHILL, Driver.BARRICADE], 1.0))
	await d.advance(0.3)
	for cell in [d.buildable_cells()[2], d.buildable_cells()[20], d.buildable_cells()[33]]:
		d.place_tower(cell, Driver.CANNON)
	d.place_tower(d.buildable_cells()[12])
	d.set_mana(10.0)
	await d.play_card("Oil Slick", d.road_pos(1150.0))
	await d.play_card("Barricade", d.road_pos(950.0))
	await d.advance(6.0)
	for scene in [Driver.ZOMBIE, Driver.BIG_GOBLIN, Driver.GIANT]:
		d.spawn(scene, 700.0 + randf() * 100.0)
	await d.advance(3.0)
	d.set_mana(10.0)
	await d.play_card("Fireball", d.road_pos(1000.0))
	await d.play_card("Chill", d.road_pos(820.0))
	await d.advance(0.6)
	await _snap(d, prefix + "_07_combat")


func _defeat(size: Vector2i, prefix: String) -> void:
	var d := _start(size, Driver.make_level([], 999.0))
	await d.advance(0.3)
	d.castle().take_damage(25.0)
	await d.advance(0.6)
	await _snap(d, prefix + "_08_defeat")
