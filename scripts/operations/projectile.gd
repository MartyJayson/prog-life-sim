extends Node2D

@export var speed := 900.0
@export var max_distance := 900.0

var direction := Vector2.RIGHT
var team := 0
var damage := 24
var travelled := 0.0

# Sweep the entire step so even a fast projectile cannot skip a wall or unit.
func advance(mission, delta: float) -> bool:
	var distance := minf(speed * delta, max_distance - travelled)
	var end := position + direction * distance
	var ray := PhysicsRayQueryParameters2D.create(mission.to_global(position), mission.to_global(end), 3)
	ray.hit_from_inside = true
	var ignored: Array[RID] = []
	for unit in mission.units:
		if unit.team == team or unit.health <= 0:
			ignored.append(unit.get_rid())
	ray.exclude = ignored
	var hit: Dictionary = mission.get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		position = mission.to_local(hit.position)
		var body = hit.collider
		if body is CharacterBody2D and body in mission.units and body.team != team and body.health > 0:
			mission._damage(body, damage)
		return false
	position = end
	travelled += distance
	return travelled < max_distance

func draw_on(canvas: CanvasItem) -> void:
	var trace: Line2D = $Trace
	var length := minf(travelled, trace.points[0].distance_to(trace.points[1]))
	canvas.draw_line(position - direction * length, position, trace.default_color, trace.width, true)
