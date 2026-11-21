extends Control

## Chasing marquee bulbs drawn along the border of this control (casino decoration).

enum Mode { IDLE, FAST, BLINK }

const BULB_ON := Color("#ffe27a")
const BULB_OFF := Color("#6b3612")

@export var spacing := 30.0
@export var inset := 10.0
@export var mode := Mode.IDLE

var _time := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var frame := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
	if frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return
	var perimeter := 2.0 * (frame.size.x + frame.size.y)
	var count := maxi(4, int(perimeter / spacing))
	var chase := int(_time * (16.0 if mode == Mode.FAST else 4.0))
	var blink := int(_time * 6.0)
	for i in count:
		var point := _perimeter_point(frame, perimeter * i / count)
		var lit := (i + blink) % 2 == 0 if mode == Mode.BLINK else (i + chase) % 3 == 0
		if lit:
			draw_circle(point, 10.0, Color(BULB_ON, 0.22))
			draw_circle(point, 5.5, BULB_ON)
		else:
			draw_circle(point, 4.5, BULB_OFF)

func _perimeter_point(frame: Rect2, distance: float) -> Vector2:
	var w := frame.size.x
	var h := frame.size.y
	if distance < w:
		return frame.position + Vector2(distance, 0.0)
	distance -= w
	if distance < h:
		return frame.position + Vector2(w, distance)
	distance -= h
	if distance < w:
		return frame.position + Vector2(w - distance, h)
	return frame.position + Vector2(0.0, h - (distance - w))
