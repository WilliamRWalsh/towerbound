class_name FireballEffect
extends CardEffect
## Drops a fireball on the targeted area: fire damage to every enemy inside, then ground that
## keeps burning.

@export var damage := 3.0
## How the patch it leaves behind burns.
@export var burn: BurnSpec


func apply(world: Battlefield, target: CardTarget, _choice: int) -> void:
	Fireball.cast(world, target.position, damage, target.radius, burn)


func damage_type() -> int:
	return Damage.Type.FIRE


func describe(values: Dictionary) -> void:
	values["damage"] = decimal(damage)
	values["burn_seconds"] = str(roundi(burn.duration))
	values["burn_dps"] = decimal(burn.damage_per_second)
