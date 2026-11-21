extends Node2D

@export var floor_color := Color("#101b29")
@export var grid_color := Color("#1a2939")
@export var wall_color := Color("#4b6177")
@export var position_color := Color("#86a5c2")

func spawn_position(team: int, index: int) -> Vector2:
	return $Teams.get_child(team).get_node("Spawns").get_child(index).position

func route_points(team: int, lane: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for marker: Marker2D in $Teams.get_child(team).get_node("Route%d" % lane).get_children():
		points.append(marker.position)
	return points
