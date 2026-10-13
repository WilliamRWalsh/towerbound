class_name ManaPool
extends RefCounted
## The player's mana for one battle: spent on cards, earned from kills, capped at a maximum, and
## never regenerating on its own. Fractional, since kills pay tenths; values snap to hundredths
## and costs compare with a small tolerance so float rounding never blocks a play.

signal changed(value: float)

const TOLERANCE := 0.001

var value := 0.0:
	set(new_value):
		value = snappedf(clampf(new_value, 0.0, max_value), 0.01)
		changed.emit(value)
var max_value := 10.0


func _init(starting := 0.0, maximum := 10.0) -> void:
	reset(starting, maximum)


func reset(starting: float, maximum: float) -> void:
	max_value = maximum
	value = starting


func can_afford(cost: float) -> bool:
	return cost <= value + TOLERANCE


## Spends `cost` and returns true, or returns false and spends nothing.
func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	value -= cost
	return true


## How much of `amount` fits under the cap.
func room_for(amount: float) -> float:
	return clampf(max_value - value, 0.0, amount)


func add(amount: float) -> void:
	value += amount
