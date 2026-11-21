extends Control

signal device_selected(device: Node2D)

const MAP_SIZE := Vector2(672, 704)
const ALLY := Color("#2874B8")
const HOSTILE := Color("#B83A46")
const DEVICE := Color("#ffc174")
const DeviceScript = preload("res://scripts/operations/device.gd")
const Arena = preload("res://scripts/operations/arena.gd")

var mission
var scale_factor := 1.0
var margin := Vector2.ZERO
var cones := {}
var refresh_in := 0.0
var wall_texture: ImageTexture
var wall_layout_id := 0
var stopped_refreshed := false

func reset_view() -> void:
	cones.clear()
	refresh_in = 0.0
	stopped_refreshed = false
	queue_redraw()

# Walls are static scene geometry. Upload them once instead of submitting
# thousands of rectangles again whenever a unit or projectile moves.
func _cache_walls() -> void:
	var layout_id: int = mission.layout.get_instance_id()
	if wall_layout_id == layout_id:
		return
	var arena := mission.layout as Arena
	var color := arena.wall_color if arena else Color("#171717")
	var border := color.lightened(0.2)
	var image := Image.create(int(MAP_SIZE.x), int(MAP_SIZE.y), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for wall in mission.walls.get_children():
		var dimensions: Vector2 = wall.get_node("Shape").shape.size
		var rect := Rect2i(Rect2(wall.position - dimensions * 0.5, dimensions))
		image.fill_rect(rect, color)
		# One-pixel shared edges retain the authored tile grid without doubling
		# the border thickness between adjacent wall cells.
		image.fill_rect(Rect2i(rect.position, Vector2i(rect.size.x + 1, 1)), border)
		image.fill_rect(Rect2i(rect.position + Vector2i(0, rect.size.y), Vector2i(rect.size.x + 1, 1)), border)
		image.fill_rect(Rect2i(rect.position, Vector2i(1, rect.size.y + 1)), border)
		image.fill_rect(Rect2i(rect.position + Vector2i(rect.size.x, 0), Vector2i(1, rect.size.y + 1)), border)
	wall_texture = ImageTexture.create_from_image(image)
	wall_layout_id = layout_id

func _physics_process(delta: float) -> void:
	if not is_instance_valid(mission):
		return
	if not mission.running:
		if stopped_refreshed:
			return
		stopped_refreshed = true
		refresh_in = 0.0
	else:
		stopped_refreshed = false
	queue_redraw()
	refresh_in -= delta
	if refresh_in > 0.0:
		return
	refresh_in = 0.08
	cones.clear()
	for unit in mission.units:
		if unit.health <= 0:
			continue
		var points := PackedVector2Array([unit.position])
		var angle := deg_to_rad(float(mission.settings.vision_half_angle))
		for index in range(25):
			var direction: Vector2 = unit.facing.rotated(lerpf(-angle, angle, index / 24.0))
			var end: Vector2 = unit.position + direction * mission.settings.vision_range
			var ray := PhysicsRayQueryParameters2D.create(unit.global_position, mission.to_global(end), 1)
			var hit: Dictionary = mission.get_world_2d().direct_space_state.intersect_ray(ray)
			points.append(end if hit.is_empty() else mission.to_local(hit.position))
		cones[unit.get_instance_id()] = [points, Color(ALLY if unit.team == 0 else HOSTILE, 0.12)]
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(mission) or size.x <= 0 or size.y <= 0:
		return
	scale_factor = minf(size.x / MAP_SIZE.x, size.y / MAP_SIZE.y)
	margin = (size - MAP_SIZE * scale_factor) * 0.5
	draw_set_transform(margin, 0.0, Vector2.ONE * scale_factor)
	var arena := mission.layout as Arena
	var floor_color := arena.floor_color if arena else Color("#101b29")
	var grid_color := arena.grid_color if arena else Color("#1a2939")
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), floor_color)
	for x in range(0, int(MAP_SIZE.x), 20):
		draw_line(Vector2(x, 0), Vector2(x, MAP_SIZE.y), grid_color)
	for y in range(0, int(MAP_SIZE.y), 20):
		draw_line(Vector2(0, y), Vector2(MAP_SIZE.x, y), grid_color)
	if arena:
		_draw_sites(arena)
	else:
		for marker in [[Vector2(340, 77), "A"], [Vector2(340, 222), "MID"], [Vector2(340, 397), "B"]]:
			draw_string(ThemeDB.fallback_font, marker[0], marker[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("#6d8ba8"))
	for cone in cones.values():
		draw_colored_polygon(cone[0], cone[1])
	_cache_walls()
	draw_texture(wall_texture, Vector2.ZERO)
	if arena:
		_draw_callouts(arena)
		for approach: Marker2D in arena.get_node("Approaches").get_children():
			var start := approach.position
			var end: Vector2 = approach.get_meta("aim")
			var direction := start.direction_to(end)
			draw_line(start, end, Color("#d5c493"), 1.5, true)
			draw_line(end, end - direction.rotated(0.5) * 8.0, Color("#d5c493"), 1.5, true)
			draw_line(end, end - direction.rotated(-0.5) * 8.0, Color("#d5c493"), 1.5, true)
			draw_string(ThemeDB.fallback_font, start + Vector2(8, -5), approach.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#d5c493"))
	for unit in mission.units:
		if unit.health <= 0:
			var color := ALLY if unit.team == 0 else HOSTILE
			draw_line(unit.position - Vector2(5, 5), unit.position + Vector2(5, 5), color, 2.0, true)
			draw_line(unit.position + Vector2(-5, 5), unit.position + Vector2(5, -5), color, 2.0, true)
		if unit.team == 1 and unit.health > 0:
			draw_circle(unit.position, 5, HOSTILE, true, -1.0, true)
			draw_arc(unit.position, 5.75, 0, TAU, 32, unit.identity_color, 1.0, true)
			if mission.live_contacts.has(unit.get_instance_id()):
				draw_arc(unit.position, 9.5, 0, TAU, 32, Color("#ffdc44"), 1.0, true)
	for unit in mission.units:
		if unit.team == 0 and unit.health > 0:
			draw_circle(unit.position, 5, ALLY, true, -1.0, true)
			draw_arc(unit.position, 5.75, 0, TAU, 32, unit.identity_color, 1.0, true)
	for device in mission.devices.get_children():
		var point: Vector2 = device.position
		var active: bool = mission.elapsed < device.access_until
		var color := ALLY if active else DEVICE
		var caption: String = device.caption
		if device.kind == DeviceScript.Kind.DOOR:
			color = ALLY if device.is_open else DEVICE
			if device.locked:
				color = HOSTILE
			var dimensions: Vector2 = device.get_node("Barrier/Shape").shape.size
			draw_rect(Rect2(point - dimensions / 2.0, dimensions), color, not device.is_open, 2.0 if device.is_open else -1.0)
		elif device.kind == DeviceScript.Kind.TURRET:
			draw_circle(point, 10, color, false, 2.0, true)
			draw_line(point, point + device.current_facing(mission.elapsed) * 14.0, color, 3.0, true)
		else:
			draw_rect(Rect2(point - Vector2(9, 9), Vector2(18, 18)), color, false, 2.0)
		if active:
			caption += " · %d s" % ceili(device.access_until - mission.elapsed)
		draw_string(ThemeDB.fallback_font, point + Vector2(18, -9), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	for bullet in mission.projectiles:
		bullet.draw_on(self)
	for flash in mission.muzzle_flashes:
		flash.draw_on(self)
	var bomb_point: Vector2 = mission.bomb_position
	if is_instance_valid(mission.bomb_carrier):
		bomb_point = mission.bomb_carrier.position + Vector2(12, -13)
	var bomb_color := Color("#ffdc44")
	draw_rect(Rect2(bomb_point - Vector2(6, 5), Vector2(12, 10)), bomb_color)
	draw_rect(Rect2(bomb_point - Vector2(6, 5), Vector2(12, 10)), Color("#322a12"), false, 1.0)
	draw_polyline(PackedVector2Array([bomb_point + Vector2(-2, -5), bomb_point + Vector2(-2, -9), bomb_point + Vector2(3, -9), bomb_point + Vector2(5, -6)]), bomb_color, 2.0, true)
	if mission.bomb_time > 0.0:
		draw_string(ThemeDB.fallback_font, bomb_point + Vector2(10, 4), "%d s" % ceili(maxf(0.0, mission.bomb_time - mission.elapsed)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, bomb_color)
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("#627f99"), false, 1.0)

func _draw_sites(arena: Arena) -> void:
	var font := ThemeDB.fallback_font
	for marker: Marker2D in arena.get_node("Callouts").get_children():
		if not marker.get_meta("site", false):
			continue
		var width := maxf(96.0, font.get_string_size(marker.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 20.0)
		var area := Rect2(marker.position - Vector2(width / 2.0, 25), Vector2(width, 50))
		draw_rect(area, Color(arena.position_color, 0.09))
		draw_rect(area, Color(arena.position_color, 0.36), false, 1.0)

func _draw_callouts(arena: Arena) -> void:
	var font := ThemeDB.fallback_font
	for marker: Marker2D in arena.get_node("Callouts").get_children():
		var caption: String = marker.name
		var site: bool = marker.get_meta("site", false)
		var font_size := 19 if site else 13
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos := marker.position + Vector2(-width / 2.0, font_size * 0.34)
		draw_string(font, pos + Vector2.ONE, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, arena.floor_color)
		draw_string(font, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, arena.position_color)

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(mission) or not mission.running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = (event.position - margin) / scale_factor
		for device in mission.devices.get_children():
			if device.position.distance_to(point) <= 18.0:
				device_selected.emit(device)
				accept_event()
				return
