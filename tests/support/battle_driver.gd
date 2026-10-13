extends RefCounted
## Runs a battle (scenes/main.tscn) inside a fixed-size SubViewport for tests: simulated taps,
## drags, and keys, fixed-step time, direct setup helpers, and read access to the battle's state.
## Tests only talk to the battle through this driver, so when the battle's internals move, only
## this file changes and the tests' expectations stay put.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WOODLAND := preload("res://data/levels/woodland.tres")
## Seconds per frame; run_tests.sh passes --fixed-fps 60.
const STEP := 1.0 / 60.0

const ARCHER := preload("res://data/cards/archer_tower.tres")
const CANNON := preload("res://data/cards/cannon_tower.tres")
const FIREBALL := preload("res://data/cards/fireball.tres")
const UPGRADE := preload("res://data/cards/upgrade.tres")
const REPAIR := preload("res://data/cards/repair.tres")
const BARRICADE := preload("res://data/cards/barricade.tres")
const OIL := preload("res://data/cards/oil_slick.tres")
const CHILL := preload("res://data/cards/chill.tres")

const CHILL_STATUS := preload("res://data/status/chill.tres")
const RATE_UPGRADE := preload("res://data/upgrades/rate.tres")
const AMMO_UPGRADE := preload("res://data/upgrades/ammo.tres")

const SKELETON := preload("res://scenes/enemies/skeleton.tscn")
const GOBLIN := preload("res://scenes/enemies/goblin.tscn")
const BIG_GOBLIN := preload("res://scenes/enemies/big_goblin.tscn")
const GIANT := preload("res://scenes/enemies/giant.tscn")
const ZOMBIE := preload("res://scenes/enemies/zombie.tscn")

var viewport: SubViewport
var main: Node
## Simulated seconds since the driver started.
var sim_time := 0.0

var _level: LevelConfig


## The woodland level, optionally with a fixed deck (listed once per copy) and a different
## preparation time. A long preparation keeps the first wave from marching during a test.
static func make_level(deck: Array = [], prepare_time := -1.0) -> LevelConfig:
	var level: LevelConfig = WOODLAND.duplicate()
	if not deck.is_empty():
		var cards: Array[CardData] = []
		for card: CardData in deck:
			cards.append(card)
		level.deck = cards
	if prepare_time > 0.0:
		level.prepare_time = prepare_time
	return level


## `host` is the GutTest (the viewport is freed after the test) or any node in the tree.
func _init(host: Node, level: LevelConfig = null, size := Vector2i(720, 1280)) -> void:
	_level = level
	viewport = SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	if host is GutTest:
		(host as GutTest).add_child_autofree(viewport)
	else:
		host.add_child(viewport)
	_spawn_main()


## Frees the battle and starts a fresh one, like the Restart button reloading the scene.
func restart() -> void:
	main.queue_free()
	await advance(STEP)
	_spawn_main()
	await advance(0.2)


func _spawn_main() -> void:
	main = MAIN_SCENE.instantiate()
	if _level:
		main.level = _level
	viewport.add_child(main)


# --- Time ---------------------------------------------------------------------------------------

func advance(seconds: float) -> void:
	var frames := maxi(1, ceili(seconds / (STEP * Engine.time_scale) - 0.001))
	for i in frames:
		await _frame()


## Steps frames until `condition` returns true. Returns false if `max_seconds` pass first.
func run_until(condition: Callable, max_seconds: float) -> bool:
	var start := sim_time
	while not condition.call():
		if sim_time - start >= max_seconds:
			return false
		await _frame()
	return true


func _frame() -> void:
	await viewport.get_tree().process_frame
	sim_time += STEP * Engine.time_scale


# --- Battle state -------------------------------------------------------------------------------

func field() -> Battlefield:
	return main.get_node("Battlefield")


func hand() -> Hand:
	return main.get_node("HandLayer/Hand")


func battle() -> Battle:
	return main.get_node("Battle")


func castle() -> Castle:
	return field().castle


func mana() -> float:
	return battle().mana.value


func set_mana(value: float) -> void:
	battle().mana.value = value


func max_mana() -> float:
	return battle().mana.max_value


func wave_number() -> int:
	return battle().wave_number


func wave_count() -> int:
	return battle().wave_count()


## "none", "victory", or "defeat".
func result() -> String:
	match battle().state:
		Battle.State.VICTORY:
			return "victory"
		Battle.State.DEFEAT:
			return "defeat"
	return "none"


func is_preparing() -> bool:
	return battle().state == Battle.State.PREPARING


func is_fighting() -> bool:
	return battle().state == Battle.State.COMBAT


func prepare_time_left() -> float:
	return battle().prepare_time_left()


func draw_pile_count() -> int:
	return battle().deck.draw_count()


func discard_pile_count() -> int:
	return battle().deck.discard_count()


func hand_cards() -> Array[Card]:
	return hand().get_cards()


func hand_titles() -> Array[String]:
	var titles: Array[String] = []
	for card in hand_cards():
		titles.append(card.data.title)
	titles.sort()
	return titles


## The first card in hand with this title, or null.
func card(title: String) -> Card:
	for c in hand_cards():
		if c.data.title == title:
			return c
	return null


func card_play() -> CardPlayController:
	return main.get_node("CardPlay")


func selected_card() -> Card:
	return card_play()._active_card


func is_discarding() -> bool:
	return card_play().is_discarding()


func discard_button() -> Button:
	return main.get_node("HandLayer/DiscardButton")


func chooser() -> UpgradeChooser:
	return main.get_node("HandLayer/UpgradeChooser")


func chooser_open() -> bool:
	return chooser().is_open()


func chooser_buttons() -> Array[Button]:
	return chooser()._buttons


func towers() -> Array[Tower]:
	var result_towers: Array[Tower] = []
	for child in field().grid.get_node("Towers").get_children():
		if child is Tower and not child.is_queued_for_deletion():
			result_towers.append(child)
	return result_towers


func tower_at(cell: Vector2i) -> Tower:
	return field().grid.tower_at(cell)


## Every enemy still in play (walking, striking, or downed and waiting to rise).
func enemies() -> Array[Enemy]:
	return field().enemies.in_play()


func living_enemies() -> Array[Enemy]:
	return field().enemies.living()


func spawns_pending() -> bool:
	return not field().spawner.done


func ledger_is_empty() -> bool:
	return field().ledger.is_empty()


func on_enemy_spawned(callback: Callable) -> void:
	battle().enemy_spawned.connect(callback)


func on_wave_cleared(callback: Callable) -> void:
	battle().wave_cleared.connect(callback)


func on_preparation_started(callback: Callable) -> void:
	battle().preparation_started.connect(callback)


# --- Positions (viewport canvas coordinates) ----------------------------------------------------

func cell_pos(cell: Vector2i) -> Vector2:
	var grid := field().grid
	return grid.to_global(grid.cell_center(cell))


func buildable_cells() -> Array[Vector2i]:
	var grid := field().grid
	var cells: Array[Vector2i] = []
	for cell: Vector2i in grid._states:
		if grid.can_build(cell):
			cells.append(cell)
	cells.sort()
	return cells


func blocked_cells() -> Array[Vector2i]:
	var grid := field().grid
	var cells: Array[Vector2i] = []
	for cell: Vector2i in grid._states:
		if grid._states[cell] == BuildGrid.CellState.BLOCKED:
			cells.append(cell)
	cells.sort()
	return cells


## A buildable cell whose center is within `max_px` canvas pixels of the road.
func cell_near_road(max_px := 120.0) -> Vector2i:
	for cell in buildable_cells():
		if distance_to_road(cell_pos(cell)) <= max_px:
			return cell
	return Vector2i(-1, -1)


## A buildable cell whose center is at least `min_px` canvas pixels from the road.
func cell_far_from_road(min_px := 260.0) -> Vector2i:
	for cell in buildable_cells():
		if distance_to_road(cell_pos(cell)) >= min_px:
			return cell
	return Vector2i(-1, -1)


func path() -> Path2D:
	return field().path


func road_length() -> float:
	return path().curve.get_baked_length()


func road_pos(progress: float) -> Vector2:
	var p := path()
	return p.to_global(p.curve.sample_baked(progress))


func distance_to_road(pos: Vector2) -> float:
	var p := path()
	var local := p.to_local(pos)
	var nearest := p.curve.sample_baked(p.curve.get_closest_offset(local))
	return p.to_global(nearest).distance_to(pos)


## Canvas pixels per map pixel at this viewport size.
func map_scale() -> float:
	return field().scale.x


# --- Input --------------------------------------------------------------------------------------

func tap(pos: Vector2) -> void:
	_push_button(pos, true)
	await _frame()
	_push_button(pos, false)
	await _frame()


## Moves the pointer without pressing, e.g. to aim a selected card.
func hover(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	viewport.push_input(motion)
	await _frame()


## A point on the visible part of a card (tucked or raised).
func card_point(c: Card) -> Vector2:
	var rect := c.get_global_rect()
	return Vector2(rect.get_center().x, rect.position.y + 50.0)


func tap_card(title: String) -> void:
	var c := card(title)
	assert(c != null, "no %s card in hand" % title)
	await tap(card_point(c))
	await advance(0.25)


## Taps a card, then a target: the tap-to-play flow.
func play_card(title: String, target: Vector2) -> void:
	await tap_card(title)
	await tap(target)
	await advance(0.25)


## Drags a card from the hand and drops it at `target`.
func drag_card(title: String, target: Vector2) -> void:
	var c := card(title)
	assert(c != null, "no %s card in hand" % title)
	var from := card_point(c)
	_push_button(from, true)
	await _frame()
	for i in range(1, 9):
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(target, i / 8.0)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		viewport.push_input(motion)
		await _frame()
	_push_button(target, false)
	await _frame()
	await advance(0.25)


func press_cancel() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	viewport.push_input(event)
	await _frame()
	event = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = false
	viewport.push_input(event)
	await _frame()


func press_discard() -> void:
	await tap(discard_button().get_global_rect().get_center())


## Picks a chooser option by the start of its label ("Rate", "Ammo").
func choose(label_start: String) -> void:
	for button in chooser_buttons():
		if button.text.begins_with(label_start):
			await tap(button.get_global_rect().get_center())
			await advance(0.1)
			return
	assert(false, "no chooser option starting with " + label_start)


func _push_button(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = pos
	event.global_position = pos
	viewport.push_input(event)


# --- Direct setup -------------------------------------------------------------------------------

## Places a tower without a card or mana, as if a tower card had been played there.
func place_tower(cell: Vector2i, card_data: CardData = ARCHER) -> Tower:
	var place := card_data.find_effect(PlaceTowerEffect) as PlaceTowerEffect
	var grid := field().grid
	assert(grid.place_tower(cell, place.tower_scene, place.tower_stats), "cell %s not buildable" % cell)
	return grid.tower_at(cell)


func upgrade_rate(tower: Tower) -> bool:
	return tower.upgrade(RATE_UPGRADE)


func upgrade_ammo(tower: Tower) -> bool:
	return tower.upgrade(AMMO_UPGRADE)


func charges_left(tower: Tower) -> int:
	return tower.ammo.left


func max_charges(tower: Tower) -> int:
	return tower.ammo.capacity


func is_reloading(tower: Tower) -> bool:
	return tower.ammo.reloading


func fire_interval(tower: Tower) -> float:
	return tower.stats.fire_interval


## Tells the placed towers a wave's combat began or ended, without running a wave.
func begin_wave() -> void:
	for tower in towers():
		tower.begin_wave()


func end_wave() -> void:
	for tower in towers():
		tower.end_wave()


## Stops the castle wall's turrets so only placed towers shoot.
func silence_turrets() -> void:
	for child in castle().get_children():
		if child is Tower:
			child.process_mode = Node.PROCESS_MODE_DISABLED


## Puts an enemy on the road `progress` map pixels from the Badlands gate, wired into the battle
## like a spawned one (it counts toward the wave and pays mana when killed).
func spawn(scene: PackedScene, progress: float, h_offset := 0.0) -> Enemy:
	var enemy := field().spawn_enemy(scene, h_offset)
	enemy.progress = progress
	field().spawner.enemy_spawned.emit(enemy)
	return enemy


func hit(enemy: Enemy, amount: float, type: int = Damage.NONE) -> void:
	enemy.take_hit(Hit.new(amount, type))


func chill(enemy: Enemy, duration: float) -> void:
	enemy.apply_status(CHILL_STATUS, duration)


## A plain slow to `factor` × speed, like an oil slick's.
func slow(enemy: Enemy, factor: float, duration: float) -> void:
	var effect := StatusEffect.new()
	effect.id = &"test_slow"
	effect.speed_multiplier = factor
	enemy.apply_status(effect, duration)


func speed_multiplier(enemy: Enemy) -> float:
	return enemy.speed_multiplier()


func is_chilled(enemy: Enemy) -> bool:
	return enemy.has_status(&"chill")


func is_downed(enemy: Enemy) -> bool:
	return enemy.is_downed()


func is_at_gate(enemy: Enemy) -> bool:
	return enemy.is_at_gate()


func is_blocked(enemy: Enemy) -> bool:
	return enemy.is_blocked()


## Places a barricade across the road at a distance along it, without a card.
func place_barricade(progress: float) -> Barricade:
	var layer := field().barricades
	var health: float = (BARRICADE.find_effect(PlaceBarricadeEffect) as PlaceBarricadeEffect).health
	assert(layer.place(road_pos(progress), health), "barricade spot invalid")
	var newest: Barricade = null
	for child in layer.get_children():
		if child is Barricade and not child.preview:
			newest = child
	return newest


## Lights a patch of burning ground, as a Fireball leaves behind. `radius` is in map pixels.
func ignite_ground(pos: Vector2, radius: float, dps: float, duration: float) -> void:
	var burn := BurnSpec.new()
	burn.damage_per_second = dps
	burn.duration = duration
	BurningGround.ignite(field(), pos, radius, burn)


## Road distance of the point on the road nearest to a canvas position.
func progress_near(pos: Vector2) -> float:
	var p := path()
	return p.curve.get_closest_offset(p.to_local(pos))


## Calls `callback(projectile)` for every arrow or cannonball launched from now on.
func on_projectile_launched(callback: Callable) -> void:
	projectile_layer().child_entered_tree.connect(func(node: Node) -> void:
		if node is Projectile:
			callback.call(node))


func projectile_layer() -> Node2D:
	return field().effects


func ground_layer() -> Node2D:
	return field().ground


## Children of a layer that are instances of `type` (a class), ignoring ones being freed.
func count_in(layer: Node, type: Variant) -> int:
	var n := 0
	for child in layer.get_children():
		if is_instance_of(child, type) and not child.is_queued_for_deletion():
			n += 1
	return n
