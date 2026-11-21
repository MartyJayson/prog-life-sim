extends VBoxContainer

const Device = preload("res://scripts/operations/device.gd")
const SYMBOLS := ["▲", "■", "●", "◆"]
const WIRES := {3: "└", 5: "│", 6: "┌", 9: "┘", 10: "─", 12: "┐"}

var mission
var device: Device
var random := RandomNumberGenerator.new()
var phase := ""
var started := 0.0
var sequence: Array[int] = []
var entered := 0
var solved_tiles: Array[int] = []
var tiles: Array[int] = []
var hits := 0
var target := 0.5
var cursor := 0.0

func configure(round_controller, selected: Device) -> void:
	mission = round_controller
	device = selected
	%Title.text = selected.caption
	random.randomize()
	_begin()

func owns_attempt() -> bool:
	return phase in ["attempt", "commands"]

func _begin() -> void:
	if not is_instance_valid(mission) or not mission.running:
		return
	started = mission.elapsed
	phase = "attempt"
	%Retry.hide()
	%Commands.hide()
	%Terminal.visible = device.kind == Device.Kind.TERMINAL
	%Door.visible = device.kind == Device.Kind.DOOR
	%Turret.visible = device.kind == Device.Kind.TURRET
	match device.kind:
		Device.Kind.TERMINAL:
			sequence.clear()
			entered = 0
			for index in range(4):
				sequence.append(random.randi_range(0, 3))
		Device.Kind.DOOR:
			# Left inlet to right outlet, above or below the centre row.
			solved_tiles.assign([0, 6, 12, 10, 9, 3, 0, 0, 0] if random.randi_range(0, 1) == 0 else [0, 0, 0, 10, 12, 6, 0, 3, 9])
			tiles.clear()
			for mask in solved_tiles:
				var tile := mask if mask != 0 else int(WIRES.keys()[random.randi_range(0, WIRES.size() - 1)])
				for rotation in range(random.randi_range(1, 3)):
					tile = _rotated(tile)
				tiles.append(tile)
			if _door_solved():
				tiles[3] = _rotated(tiles[3])
			_show_tiles()
		Device.Kind.TURRET:
			hits = 0
			_pick_target()
	_process(0.0)

func _process(_delta: float) -> void:
	if not is_instance_valid(mission) or not is_instance_valid(device):
		return
	if not mission.running and phase != "ended":
		_finish("Round over", false)
		phase = "ended"
		return
	if phase == "commands":
		_refresh_commands()
		return
	if phase != "attempt":
		return
	var elapsed: float = mission.elapsed - started
	var remaining: float = mission.settings.hack_seconds - elapsed
	if remaining <= 0.0:
		_finish("Time is up", true)
		return
	match device.kind:
		Device.Kind.TERMINAL:
			if elapsed < 2.8:
				var index := mini(int(elapsed / 0.7), 3)
				%Status.text = "Remember  %s    %d/4" % [SYMBOLS[sequence[index]], index + 1]
				%Terminal.hide()
			else:
				%Terminal.show()
				%Status.text = "Repeat the sequence  %d/4 · %d s" % [entered, ceili(remaining)]
		Device.Kind.DOOR:
			%Status.text = "Connect the left input to the right output in the middle row · %d s" % ceili(remaining)
		Device.Kind.TURRET:
			cursor = pingpong(elapsed * 1.05, 1.0)
			%Track.cursor = cursor
			%Track.target = target
			%Track.queue_redraw()
			%Status.text = "Hits in a row  %d/3 · %d s" % [hits, ceili(remaining)]

func _enter_symbol(index: int) -> void:
	if phase != "attempt" or mission.elapsed - started < 2.8:
		return
	if sequence[entered] != index:
		_finish("Wrong sequence", true)
		return
	entered += 1
	if entered == sequence.size():
		_grant()

func _rotated(mask: int) -> int:
	return ((mask << 1) & 15) | (mask >> 3)

func _rotate_tile(index: int) -> void:
	if phase != "attempt":
		return
	tiles[index] = _rotated(tiles[index])
	_show_tiles()
	if _door_solved():
		phase = "commands"
		%Door.hide()
		%Commands.show()
		%Status.text = "Circuit restored. Choose a command"
		_refresh_commands()

func _door_solved() -> bool:
	var position := Vector2i(0, 1)
	var inlet := 8
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for step in range(9):
		var wire := tiles[position.y * 3 + position.x]
		if (wire & inlet) == 0:
			return false
		var outlet := wire ^ inlet
		var direction := [1, 2, 4, 8].find(outlet)
		position += directions[direction]
		if position == Vector2i(3, 1):
			return true
		if not Rect2i(0, 0, 3, 3).has_point(position):
			return false
		inlet = 1 << ((direction + 2) % 4)
	return false

func _show_tiles() -> void:
	for index in range(9):
		var tile: Button = %Door.get_child(index)
		var wire: String = WIRES[tiles[index]]
		tile.text = ("→ " + wire if index == 3 else (wire + " →" if index == 5 else wire))

func _pick_target() -> void:
	if hits == 0:
		target = random.randf_range(0.17, 0.83)
	elif target < 0.5:
		target = random.randf_range(0.62, 0.83)
	else:
		target = random.randf_range(0.17, 0.38)

func _stop_indicator() -> void:
	if phase != "attempt":
		return
	if absf(cursor - target) > 0.11:
		hits = 0
		return
	hits += 1
	if hits >= 3:
		_grant()
	else:
		_pick_target()

func _grant() -> void:
	if mission.running:
		mission.grant_access(device)
		_finish("Access granted", false)

func _refresh_commands() -> void:
	var busy: bool = mission.pending_door != null
	%Commands.get_node("open").disabled = busy or device.is_open or device.locked
	%Commands.get_node("close").disabled = busy or not device.is_open
	%Commands.get_node("lock").disabled = busy or device.is_open or device.locked
	%Commands.get_node("unlock").disabled = busy or not device.locked

func _command(command: String) -> void:
	if phase == "commands" and mission.request_door(device, command):
		%Status.text = "Command sent"

func _finish(message: String, retry: bool) -> void:
	phase = "result"
	%Status.text = message
	%Terminal.hide()
	%Door.hide()
	%Turret.hide()
	%Commands.hide()
	%Retry.visible = retry
