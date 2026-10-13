class_name Projectile
extends Node2D
## Base for a shot fired at one enemy: an arrow, a cannonball. Commits its damage to the
## battlefield's DamageLedger when launched, so towers don't overkill, and releases it exactly
## once: when it arrives, or when it leaves the tree. Follows its target while the target lives;
## if the target dies or leaves play mid-flight, it carries on to where it was aiming and lands
## without effect. Subclasses decide how it flies (`_advance`), what arriving looks like
## (`_arrive`), and how it is drawn. Works in the effects layer's (map-pixel) coordinates.

## Scene whose root is a Projectile.
static func fire(scene: PackedScene, world: Battlefield, from_global: Vector2, target: Enemy,
		hit: Hit, speed: float) -> Projectile:
	var projectile: Projectile = scene.instantiate()
	projectile.launch(world, from_global, target, hit, speed)
	return projectile


var _world: Battlefield
var _target: Enemy
var _hit: Hit
## Map pixels per second.
var _speed := 0.0
## Where it was launched from and where it is aiming, in layer coordinates.
var _from := Vector2.ZERO
var _aim := Vector2.ZERO
var _committed := 0.0
## Instance id of the enemy the committed damage is for; 0 once released.
var _committed_to := 0
var _arrived := false


## Launches from a canvas position at `target`. `speed` is in world units per second.
func launch(world: Battlefield, from_global: Vector2, target: Enemy, hit: Hit, speed: float) -> void:
	_world = world
	_target = target
	_hit = hit
	_speed = Units.px(speed)
	_committed = world.ledger.commit(target, hit.amount, hit.type)
	_committed_to = target.get_instance_id()
	var layer := world.effects
	layer.add_child(self)
	_from = layer.to_local(from_global)
	position = _from
	_aim = layer.to_local(target.aim_point())
	_launched()


func _process(delta: float) -> void:
	if _arrived:
		return
	var tracking := is_instance_valid(_target) and _target.is_alive()
	if tracking:
		_aim = get_parent().to_local(_target.aim_point())
	if not _advance(delta):
		return
	_arrived = true
	_release()
	if tracking:
		_target.take_hit(_hit)
	_arrive(tracking)


## Called once it is in the layer and aimed.
func _launched() -> void:
	pass


## Moves one frame toward `_aim`. Returns true on arrival.
func _advance(_delta: float) -> bool:
	return true


## It arrived: `struck` is true when it hit its target, false when it lands harmlessly.
## Free it here, or after an animation.
func _arrive(_struck: bool) -> void:
	queue_free()


func _exit_tree() -> void:
	_release()


## Hands the committed damage back to the ledger, once.
func _release() -> void:
	if _committed_to != 0:
		_world.ledger.release(_committed_to, _committed)
		_committed_to = 0
