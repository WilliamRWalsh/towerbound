class_name RateUpgrade
extends TowerUpgrade
## Makes a tower fire faster.

## 0.5 = 50% more shots per second.
@export var attack_rate_bonus := 0.5


func apply(tower: Tower) -> void:
	tower.set_fire_interval(tower.stats.fire_interval / (1.0 + attack_rate_bonus))


func label() -> String:
	return "Rate of Fire\n%s speed" % amount_text()


func amount_text() -> String:
	return "+%d%%" % roundi(attack_rate_bonus * 100.0)
