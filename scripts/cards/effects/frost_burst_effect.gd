class_name FrostBurstEffect
extends CardEffect
## A burst of frost over the targeted area: light frost damage and a chill on every enemy inside.

@export var damage := 0.5
## The status it puts on enemies, and for how long before each enemy's frost multiplier.
@export var chill: StatusEffect
@export var chill_duration := 5.0


func apply(world: Battlefield, target: CardTarget, _choice: int) -> void:
	FrostBurst.cast(world, target.position, damage, target.radius, chill, chill_duration)


func damage_type() -> int:
	return Damage.Type.FROST


func describe(values: Dictionary) -> void:
	values["damage"] = decimal(damage)
	values["chill_seconds"] = str(roundi(chill_duration))
	values["chill_slow"] = percent(1.0 - chill.speed_multiplier)
	values["brittle"] = "+" + percent(chill.damage_taken.get(Damage.Type.CRUSH, 1.0) - 1.0)
