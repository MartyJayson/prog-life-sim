extends VBoxContainer

const GRID := Vector2i(20, 16)

var body: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var pending_turn := Vector2i.RIGHT
var food := Vector2i.ZERO
var turn_queued := false
var score := 0
var elapsed := 0.0
var active := false
var started := false
var finished := false
var won := false

@onready var board: Control = %Board
@onready var status: Label = %Status

func _ready() -> void:
	_restart()

func _queue_board_redraw() -> void:
	%Board.queue_redraw()

func set_active(value: bool) -> void:
	active = value

func _restart() -> void:
	body.assign([Vector2i(9, 8), Vector2i(8, 8), Vector2i(7, 8)])
	direction = Vector2i.RIGHT
	pending_turn = direction
	turn_queued = false
	score = 0
	elapsed = 0.0
	started = false
	finished = false
	won = false
	_spawn_food()
	_update_status()

func _input(event: InputEvent) -> void:
	if not active or finished or not (event is InputEventKey) or not event.pressed:
		return
	var turn := Vector2i.ZERO
	match event.physical_keycode:
		KEY_UP, KEY_W: turn = Vector2i.UP
		KEY_DOWN, KEY_S: turn = Vector2i.DOWN
		KEY_LEFT, KEY_A: turn = Vector2i.LEFT
		KEY_RIGHT, KEY_D: turn = Vector2i.RIGHT
	if turn == Vector2i.ZERO:
		return
	get_viewport().set_input_as_handled()
	if not turn_queued and turn != -direction:
		pending_turn = turn
		turn_queued = turn != direction
		started = true
		_update_status()

func _process(delta: float) -> void:
	if not active or not started or finished:
		return
	elapsed += delta
	var interval := maxf(0.065, 0.22 - score * 0.012)
	if elapsed >= interval:
		elapsed -= interval
		_tick()

func _tick() -> void:
	direction = pending_turn
	turn_queued = false
	var next := body[0] + direction
	var eating := next == food
	var hits_body := body.has(next) and (eating or next != body[body.size() - 1])
	if not Rect2i(Vector2i.ZERO, GRID).has_point(next) or hits_body:
		finished = true
	else:
		if not eating:
			body.pop_back()
		body.push_front(next)
		if eating:
			score += 1
			_spawn_food()
	_update_status()

func _spawn_food() -> void:
	var free: Array[Vector2i] = []
	for y in GRID.y:
		for x in GRID.x:
			var cell := Vector2i(x, y)
			if not body.has(cell):
				free.append(cell)
	if free.is_empty():
		finished = true
		won = true
	else:
		food = free.pick_random()

func _update_status() -> void:
	var suffix := ""
	if finished:
		suffix = "   ·   You win!" if won else "   ·   Game Over"
	elif not started:
		suffix = "   ·   Press a direction to start"
	status.text = "Score %d%s" % [score, suffix]
	board.queue_redraw()

func _draw_board() -> void:
	var cell := floorf(minf(board.size.x / GRID.x, board.size.y / GRID.y))
	if cell < 2:
		return
	var extent := Vector2(GRID) * cell
	var origin := ((board.size - extent) * 0.5).floor()
	board.draw_rect(Rect2(Vector2.ZERO, board.size), Color("#10222b"))
	for y in GRID.y:
		for x in GRID.x:
			var color := Color("#1e3540") if (x + y) % 2 == 0 else Color("#203945")
			board.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2.ONE * cell), color)
	if not won:
		board.draw_circle(origin + (Vector2(food) + Vector2(0.5, 0.5)) * cell, cell * 0.31, Color("#ff896a"))
	for i in body.size():
		var color := Color("#b1f49a") if i == 0 else Color("#60c777")
		board.draw_rect(Rect2(origin + Vector2(body[i]) * cell + Vector2.ONE, Vector2.ONE * (cell - 2)), color)
	if finished:
		board.draw_rect(Rect2(origin, extent), Color(0.02, 0.08, 0.11, 0.68))
		var caption := "YOU WIN" if won else "GAME OVER"
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 33).x
		board.draw_string(font, board.size * 0.5 + Vector2(-width * 0.5, 11), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 33, Color("#d1f5dd"))
