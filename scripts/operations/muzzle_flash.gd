extends Node2D

@export var duration := 0.07
var age := 0.0

func advance(delta: float) -> bool:
	age += delta
	return age < duration

func draw_on(canvas: CanvasItem) -> void:
	for shape: Polygon2D in get_children():
		var points := PackedVector2Array()
		for point in shape.polygon:
			points.append(position + point.rotated(rotation))
		var tint := shape.color
		tint.a *= 1.0 - age / duration
		canvas.draw_colored_polygon(points, tint)
