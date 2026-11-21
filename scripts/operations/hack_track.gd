extends Control

var cursor := 0.0
var target := 0.5

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#152336"))
	draw_rect(Rect2(size.x * (target - 0.11), 0, size.x * 0.22, size.y), Color("#296e64"))
	draw_line(Vector2(size.x * cursor, 0), Vector2(size.x * cursor, size.y), Color("#ffce87"), 4.0)
