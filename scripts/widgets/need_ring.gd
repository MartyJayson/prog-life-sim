@tool
extends Control

## Circular progress ring: a full grey track with a coloured arc that starts at
## 12 o'clock and runs clockwise for `value` of the circle.

@export_range(0.0, 1.0, 0.01) var value := 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var color := Color(0.16, 0.45, 0.85):
	set(v):
		color = v
		queue_redraw()
@export var track_color := Color(0.86, 0.9, 0.95):
	set(v):
		track_color = v
		queue_redraw()
@export_range(1.0, 32.0, 0.5) var thickness := 8.0:
	set(v):
		thickness = v
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - thickness * 0.5
	if radius <= 0.0:
		return
	draw_arc(center, radius, 0.0, TAU, 64, track_color, thickness, true)
	if value <= 0.0:
		return
	var start := -PI * 0.5
	var end := start + TAU * value
	draw_arc(center, radius, start, end, maxi(8, int(64 * value)), color, thickness, true)
	# Rounded caps, like phone activity rings.
	var cap := thickness * 0.5
	draw_circle(center + Vector2.from_angle(start) * radius, cap, color)
	draw_circle(center + Vector2.from_angle(end) * radius, cap, color)
