extends Node2D

enum Kind { TERMINAL, DOOR, TURRET }

@export var kind: Kind
@export var caption: String
@export var coverage := Rect2()
@export var turret_range := 145.0
@export var turret_facing := Vector2.LEFT

var is_open := true
var locked := false
var access_until := 0.0
var next_action := 0.0

func reset() -> void:
	locked = false
	access_until = 0.0
	next_action = 0.0
	if kind == Kind.DOOR:
		set_open(true)

func set_open(value: bool) -> void:
	is_open = value
	$Link.enabled = value
	$Barrier/Shape.set_deferred("disabled", value)

func occupied() -> bool:
	return $Occupancy.has_overlapping_bodies()

func current_facing(elapsed: float) -> Vector2:
	return -turret_facing if elapsed < access_until else turret_facing