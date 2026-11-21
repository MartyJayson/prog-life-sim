extends Control

## Draws the marquee bulbs around the reels and the glowing winning lines on top of them.

enum Mode { IDLE, SPIN, WIN }

const BULB_ON := Color("#ffe27a")
const BULB_OFF := Color("#6b3612")
const BULB_SPACING := 30.0
const REVEAL_TIME := 0.35

var reels: Array[Control] = []
var mode := Mode.IDLE
var _lines: Array[Dictionary] = []
var _time := 0.0
var _shown_at := 0.0

func show_lines(lines: Array[Dictionary]) -> void:
	_lines = lines
	_shown_at = _time
	mode = Mode.WIN

func clear() -> void:
	_lines.clear()
	mode = Mode.IDLE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if reels.size() < 3:
		return
	var first := _to_local(reels[0], Vector2.ZERO)
	var last := _to_local(reels[2], reels[2].size)
	_draw_bulbs(Rect2(first, last - first).grow(11.0))
	var reveal := clampf((_time - _shown_at) / REVEAL_TIME, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)
	for line in _lines:
		var cells: Array = line.cells
		var start := _cell_center(cells[0])
		var finish := _cell_center(cells[2])
		var extension := (finish - start) * 0.2
		start -= extension
		finish = start.lerp(finish + extension, reveal)
		var color: Color = line.color
		draw_line(start, finish, Color(color, 0.22 + 0.2 * pulse), 20.0, true)
		draw_line(start, finish, Color(color.lightened(0.45), 0.95), 6.0, true)
		draw_circle(start, 9.0, color.lightened(0.3))
		draw_circle(finish, 9.0, color.lightened(0.3))

func _draw_bulbs(frame: Rect2) -> void:
	var perimeter := 2.0 * (frame.size.x + frame.size.y)
	var count := maxi(4, int(perimeter / BULB_SPACING))
	var chase := int(_time * (16.0 if mode == Mode.SPIN else 4.0))
	var blink := int(_time * 6.0)
	for i in count:
		var point := _perimeter_point(frame, perimeter * i / count)
		var lit := (i + blink) % 2 == 0 if mode == Mode.WIN else (i + chase) % 3 == 0
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

func _cell_center(cell: Vector2i) -> Vector2:
	var reel := reels[cell.x]
	return _to_local(reel, Vector2(reel.size.x * 0.5, reel.size.y * (cell.y + 0.5) / 3.0))

func _to_local(node: Control, point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * (node.get_global_transform() * point)
