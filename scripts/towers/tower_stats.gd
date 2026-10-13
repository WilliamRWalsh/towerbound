class_name TowerStats
extends Resource
## Combat stats a tower card gives the tower it places. Distances and speeds are in world units
## at the 720 × 1280 reference resolution.

@export var damage := 1.0
@export var damage_type: Damage.Type = Damage.Type.PIERCE
## Seconds between shots.
@export var fire_interval := 1.0
@export var attack_range := 180.0
## What it fires: a scene whose root is a Projectile (arrow, cannonball).
@export var projectile: PackedScene
@export var projectile_speed := 420.0
## Waves of firing before the tower must sit out a wave reloading. Firing at least once in a wave
## spends one charge. 0 means unlimited ammo (castle turrets).
@export var charges := 2
