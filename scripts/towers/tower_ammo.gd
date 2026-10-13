class_name TowerAmmo
extends RefCounted
## A tower's ammo, counted in charges: firing at least once in a wave spends one charge for that
## whole wave. A tower that spends its last charge keeps firing until the wave ends, then sits out
## the next wave reloading and comes back full: fire, fire, reload. A tower that never fires keeps
## its charges. A capacity of 0 means unlimited ammo (castle turrets).

## Something the pips show changed: charges, capacity, or reloading.
signal changed
## A charge was just spent (the pip pops).
signal spent

var capacity := 0
var left := 0
## Sitting out the current (or next) wave; can't fire.
var reloading := false
var _fired_this_wave := false


func _init(charges: int) -> void:
	capacity = charges
	left = charges


func is_unlimited() -> bool:
	return capacity <= 0


## True while it can shoot: unlimited, a charge left, or this wave's charge already paid.
func can_fire() -> bool:
	return is_unlimited() or (not reloading and (_fired_this_wave or left > 0))


## Records a shot: the first one in a wave spends a charge.
func note_shot() -> void:
	if is_unlimited() or _fired_this_wave:
		return
	_fired_this_wave = true
	left -= 1
	spent.emit()


## A wave's combat began.
func begin_wave() -> void:
	_fired_this_wave = false


## A wave was cleared: a reloading tower refills, and an empty one starts reloading (it shows as
## reloading through the next preparation and sits out that wave).
func end_wave() -> void:
	_fired_this_wave = false
	if is_unlimited():
		return
	if reloading:
		reloading = false
		left = capacity
	elif left <= 0:
		reloading = true
	changed.emit()


## Adds `extra` charges to the capacity, and to the charges left unless reloading (a reloading
## tower comes back with the new full amount).
func add_capacity(extra: int) -> void:
	capacity += extra
	if not reloading:
		left += extra
	changed.emit()
