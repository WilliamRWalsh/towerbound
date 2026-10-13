class_name StatusEffects
extends RefCounted
## The status effects on one enemy and how long each has left. Answers what they add up to: the
## walking speed and strike interval multipliers, extra damage taken by type, and the tint.

## Effect → seconds left.
var _left: Dictionary[StatusEffect, float] = {}


## Applies `effect` for `duration` seconds, keeping the longer duration if it is already on.
func apply(effect: StatusEffect, duration: float) -> void:
	_left[effect] = maxf(_left.get(effect, 0.0), duration)


func tick(delta: float) -> void:
	for effect in _left.keys():
		_left[effect] -= delta
		if _left[effect] <= 0.0:
			_left.erase(effect)


func has(id: StringName) -> bool:
	for effect in _left:
		if effect.id == id:
			return true
	return false


## The strongest slow, or 1.0.
func speed_multiplier() -> float:
	var multiplier := 1.0
	for effect in _left:
		multiplier = minf(multiplier, effect.speed_multiplier)
	return multiplier


## The longest strike delay, or 1.0.
func strike_interval_multiplier() -> float:
	var multiplier := 1.0
	for effect in _left:
		multiplier = maxf(multiplier, effect.strike_interval_multiplier)
	return multiplier


## Every active effect's multiplier on damage of `type`, multiplied together.
func damage_multiplier(type: int) -> float:
	var multiplier := 1.0
	for effect in _left:
		multiplier *= effect.damage_taken.get(type, 1.0)
	return multiplier


## The strongest tint, with its alpha as strength (fading out as its effect runs out).
func tint() -> Color:
	var strongest := Color(0, 0, 0, 0)
	for effect in _left:
		if effect.tint.a <= 0.0:
			continue
		var strength := effect.tint.a * minf(1.0, _left[effect] / maxf(0.001, effect.tint_fade))
		if strength > strongest.a:
			strongest = Color(effect.tint, strength)
	return strongest
