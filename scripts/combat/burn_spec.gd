class_name BurnSpec
extends Resource
## How a patch of burning ground burns: damage per second to each enemy standing in it, and how
## long it lasts. Shared by Fireball's scorch and an ignited oil slick's blaze.

@export var damage_per_second := 1.0
@export var duration := 4.0
