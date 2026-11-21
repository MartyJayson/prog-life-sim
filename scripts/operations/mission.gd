extends Node2D

signal ended(result: String)
signal notice(message: String)

const Unit = preload("res://scripts/operations/operative.gd")
const UnitScene = preload("res://scenes/operations/operative.tscn")
const Device = preload("res://scripts/operations/device.gd")
const Tactics = preload("res://scripts/operations/tactics.gd")
const ProjectileScene = preload("res://scenes/operations/projectile.tscn")
const MuzzleFlashScene = preload("res://scenes/operations/muzzle_flash.tscn")
const IDENTITY_COLORS := [Color("#FFD84D"), Color("#71DF83"), Color("#FF929C"), Color("#8ACBFF"), Color("#CB9BFF")]

@export var settings: Resource
@onready var layout: Node2D = $Layout
@onready var devices := $Layout/Devices
@onready var walls := $Layout/Walls

var units: Array[Unit] = []
var elapsed := 0.0
var running := false
var ready_to_start := false
var live_contacts := {}
var memory := {}
var scans := {}
var pending_door: Device
var pending_command := ""
var pending_time := 0.0
var rng := RandomNumberGenerator.new()
var scan_rng := RandomNumberGenerator.new()
var bomb_time := 0.0
var plant_progress := 0.0
var planter: Unit
var bomb_position := Vector2.ZERO
var defuse_progress := 0.0
var defuser: Unit
var contact_reports := {}
var bomb_carrier: Unit
var bomb_retriever: Unit
var bomb_dropped := false
var bomb_guards := {}
var defense_plan := ""
var attack_plan := ""
var projectiles: Array[Node2D] = []
var muzzle_flashes: Array[Node2D] = []

func _ready() -> void:
	ended.connect(_clear_combat_effects)

func load_layout(scene: PackedScene) -> void:
	running = false
	ready_to_start = false
	_clear_combat_effects()
	remove_child(layout)
	layout.queue_free()
	layout = scene.instantiate()
	add_child(layout)
	devices = layout.get_node("Devices")
	walls = layout.get_node("Walls")

func restart() -> void:
	running = false
	ready_to_start = false
	_clear_combat_effects()
	for unit in units:
		remove_child(unit)
		unit.queue_free()
	units.clear()
	live_contacts.clear()
	memory.clear()
	scans.clear()
	pending_door = null
	elapsed = 0.0
	bomb_time = 0.0
	plant_progress = 0.0
	defuse_progress = 0.0
	defuser = null
	planter = null
	contact_reports.clear()
	bomb_carrier = null
	bomb_retriever = null
	bomb_dropped = false
	bomb_guards.clear()
	if settings.seed_value == 0:
		rng.randomize()
		scan_rng.randomize()
	else:
		rng.seed = settings.seed_value
		scan_rng.seed = int(settings.seed_value) ^ 0x5CA4
	for device: Device in devices.get_children():
		device.reset()
	for team in range(2):
		_spawn_team(team)
	bomb_carrier = units[5 + rng.randi_range(0, 4)]
	bomb_position = bomb_carrier.position
	Tactics.assign(self)
	ready_to_start = true

func start() -> void:
	if not ready_to_start:
		return
	ready_to_start = false
	running = true

func _spawn_team(team: int) -> void:
	var names := ["Vector", "Lens", "Quartz", "Relay", "Spark"] if team == 0 else ["Nord", "Storm", "Ray", "Wedge", "Phantom"]
	var ys := [102.0, 230.0, 418.0, 74.0, 390.0]
	var start_x := 64.0 if team == 0 else 756.0
	var near_x := 315.0 if team == 0 else 510.0
	var far_x := 520.0 if team == 0 else 300.0
	var accuracy_range: Vector2 = settings.ally_accuracy if team == 0 else settings.enemy_accuracy
	for index in range(5):
		var unit: Unit = UnitScene.instantiate()
		unit.team = team
		unit.callsign = names[index]
		unit.identity_color = IDENTITY_COLORS[index]
		unit.health = settings.health
		unit.accuracy = rng.randf_range(accuracy_range.x, accuracy_range.y)
		unit.facing = Vector2.RIGHT if team == 0 else Vector2.LEFT
		unit.position = Vector2(start_x, ys[index])
		var lane: float = ys[index % 3]
		unit.route = PackedVector2Array([Vector2(near_x, lane), Vector2(far_x, lane), Vector2(far_x, 230), Vector2(near_x, 290)])
		if layout.has_method("route_points"):
			unit.position = layout.spawn_position(team, index)
			unit.route = layout.route_points(team, index % 3)
		add_child(unit)
		units.append(unit)
		if index >= 3:
			unit.partner = units[team * 5 + (0 if index == 3 else 2)]

func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	_advance_combat_effects(delta)
	if pending_door and elapsed >= pending_time:
		_apply_door()
	_update_bomb_ownership()
	for unit in units:
		unit.update_ai(self, elapsed)
	for device: Device in devices.get_children():
		_update_device(device)
	_update_contacts()
	_update_bomb(delta)
	if not running:
		return
	var allies := 0
	var enemies := 0
	for unit in units:
		if unit.health > 0:
			allies += int(unit.team == 0)
			enemies += int(unit.team == 1)
	if allies == 0 or (bomb_time == 0.0 and (enemies == 0 or elapsed >= settings.round_seconds)):
		running = false
		pending_door = null
		ended.emit("Draw" if allies == enemies or elapsed >= settings.round_seconds else ("Victory" if enemies == 0 else "Defeat"))

func _update_bomb(delta: float) -> void:
	if bomb_time > 0.0:
		if defuser != null and (defuser.health <= 0 or defuser.target != null):
			defuser = null
			defuse_progress = 0.0
		if defuser == null:
			var nearest := INF
			for unit in units:
				if unit.team == 0 and unit.health > 0 and unit.target == null:
					var distance := unit.position.distance_squared_to(bomb_position)
					if distance < nearest:
						nearest = distance
						defuser = unit
			defuse_progress = 0.0
		var defusing := false
		for unit in units:
			if unit.team == 0 and unit.health > 0:
				var destination := bomb_position
				if unit != defuser:
					var offset := Vector2.RIGHT.rotated(TAU * units.find(unit) / 5.0) * 35.0
					destination = NavigationServer2D.map_get_closest_point(get_world_2d().navigation_map, bomb_position + offset)
				unit.route = PackedVector2Array([destination])
				unit.waypoint = 0
				if unit == defuser and unit.position.distance_to(bomb_position) < 18.0 and unit.target == null:
					var ray := PhysicsRayQueryParameters2D.create(unit.global_position, to_global(bomb_position), 1)
					if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
						continue
					defusing = true
					unit.action = "Defusing"
		defuse_progress = defuse_progress + delta if defusing else 0.0
		if defuse_progress >= 5.0 or elapsed >= bomb_time:
			running = false
			ended.emit("Victory · bomb defused" if defuse_progress >= 5.0 else "Defeat · bomb exploded")
		return
	var candidate: Unit
	for unit in units:
		if unit == bomb_carrier and unit.health > 0 and unit.target == null and unit.waypoint == unit.route.size() - 1 and unit.position.distance_to(unit.route[-1]) < 14.0:
			candidate = unit
			break
	if candidate != planter:
		planter = candidate
		plant_progress = 0.0
	if planter:
		planter.action = "Planting the bomb"
		plant_progress += delta
		if plant_progress >= 3.0:
			bomb_position = planter.position
			bomb_time = elapsed + 40.0
			bomb_carrier = null
			bomb_retriever = null
			bomb_guards.clear()
			notice.emit("Bomb planted · 40 seconds")

func _update_bomb_ownership() -> void:
	if bomb_time > 0.0:
		return
	if is_instance_valid(bomb_carrier):
		bomb_position = bomb_carrier.position
		if bomb_carrier.health <= 0:
			bomb_carrier = null
			bomb_dropped = true
			planter = null
			plant_progress = 0.0
			notice.emit("Bomb dropped")
	if bomb_dropped:
		bomb_retriever = null
		var nearest := INF
		for unit in units:
			if unit.team != 1 or unit.health <= 0:
				continue
			var distance := unit.position.distance_squared_to(bomb_position)
			if distance < nearest:
				nearest = distance
				bomb_retriever = unit
		if bomb_retriever and nearest < 100.0:
			var ray := PhysicsRayQueryParameters2D.create(to_global(bomb_retriever.position), to_global(bomb_position), 1)
			if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				bomb_carrier = bomb_retriever
				bomb_retriever = null
				bomb_dropped = false
				bomb_carrier.next_path = 0.0
				notice.emit("%s picked up the bomb" % bomb_carrier.callsign)
	for unit in units:
		if unit.team != 0 or unit.health <= 0:
			continue
		var id := unit.get_instance_id()
		if bomb_dropped and can_see(unit.position, unit.facing, bomb_position, settings.vision_range, settings.vision_half_angle):
			bomb_guards[id] = bomb_position
		elif bomb_guards.has(id) and can_see(unit.position, unit.facing, bomb_guards[id], settings.vision_range, settings.vision_half_angle):
			bomb_guards.erase(id)

func bomb_task_position(unit: Unit) -> Vector2:
	if unit == bomb_retriever and bomb_dropped:
		unit.action = "Retrieve the bomb"
		return bomb_position
	if unit.team == 0 and bomb_guards.has(unit.get_instance_id()):
		unit.action = "Guarding the bomb"
		var point: Vector2 = bomb_guards[unit.get_instance_id()]
		if unit.position.distance_to(point) <= 65.0:
			return unit.position
		return point
	return Vector2.INF

func can_see(origin: Vector2, facing: Vector2, point: Vector2, distance_limit: float, half_angle: float) -> bool:
	var offset := point - origin
	if offset.length_squared() > distance_limit * distance_limit:
		return false
	if offset != Vector2.ZERO and facing.dot(offset.normalized()) < cos(deg_to_rad(half_angle)):
		return false
	var ray := PhysicsRayQueryParameters2D.create(to_global(origin), to_global(point), 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func objective_urgent(unit: Unit) -> bool:
	return (unit.independent_bomber and unit == bomb_carrier) or (unit == planter and plant_progress > 0.0) or (unit.team == 0 and bomb_time > 0.0)

func report_contact(reporter: Unit, observed_position: Vector2) -> void:
	var id := reporter.get_instance_id()
	if elapsed < float(contact_reports.get(id, -1.0)):
		return
	contact_reports[id] = elapsed + 0.5
	for teammate in units:
		if teammate == reporter or teammate.team != reporter.team or teammate.health <= 0 or objective_urgent(teammate):
			continue
		if attack_plan == "Fake attack" and bomb_time == 0.0 and teammate.team == 1 and teammate.assignment != reporter.assignment:
			continue
		if teammate.target != null and is_instance_valid(teammate.target) and teammate.target.health > 0:
			continue
		if elapsed < teammate.assistance_until and teammate.assistance_source != reporter.callsign and teammate.position.distance_squared_to(teammate.assistance_position) < teammate.position.distance_squared_to(observed_position):
			continue
		var new_request := elapsed >= teammate.assistance_until
		teammate.assistance_position = observed_position
		teammate.assistance_source = reporter.callsign
		teammate.assistance_until = elapsed + 6.0
		if new_request:
			teammate.next_path = 0.0

func find_target(observer: Unit) -> Unit:
	var best: Unit
	var distance := INF
	for unit in units:
		if unit.team == observer.team or unit.health <= 0:
			continue
		var candidate := observer.position.distance_squared_to(unit.position)
		if candidate < distance and can_see(observer.position, observer.facing, unit.position, settings.vision_range, settings.vision_half_angle):
			best = unit
			distance = candidate
	return best

func reaction(team: int) -> float:
	var limits: Vector2 = settings.ally_reaction if team == 0 else settings.enemy_reaction
	return rng.randf_range(limits.x, limits.y)

func fire(shooter: Unit, enemy: Unit) -> void:
	var direction := shooter.position.direction_to(enemy.position)
	if rng.randf() >= shooter.accuracy:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		direction = direction.rotated(deg_to_rad(rng.randf_range(6.0, 12.0) * side))
	var bullet = ProjectileScene.instantiate()
	# Start at the shooter's centre so the first sweep also checks the muzzle.
	bullet.position = shooter.position
	bullet.direction = direction
	bullet.team = shooter.team
	bullet.damage = settings.damage
	add_child(bullet)
	projectiles.append(bullet)
	var flash = MuzzleFlashScene.instantiate()
	flash.position = shooter.position + direction * 7.0
	flash.rotation = direction.angle()
	add_child(flash)
	muzzle_flashes.append(flash)

func _advance_combat_effects(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var bullet = projectiles[index]
		if not bullet.advance(self, delta):
			projectiles.remove_at(index)
			bullet.queue_free()
	for index in range(muzzle_flashes.size() - 1, -1, -1):
		var flash = muzzle_flashes[index]
		if not flash.advance(delta):
			muzzle_flashes.remove_at(index)
			flash.queue_free()

func _clear_combat_effects(_result: String = "") -> void:
	for effect in projectiles + muzzle_flashes:
		remove_child(effect)
		effect.queue_free()
	projectiles.clear()
	muzzle_flashes.clear()

func _damage(unit: Unit, amount: int) -> void:
	unit.take_damage(amount)
	if unit.health == 0 and (unit.team == 0 or live_contacts.has(unit.get_instance_id())):
		notice.emit("%s eliminated" % unit.callsign)

func _update_contacts() -> void:
	var previous := live_contacts
	live_contacts = {}
	for enemy in units:
		if enemy.team != 1:
			continue
		var id := enemy.get_instance_id()
		if enemy.health <= 0:
			if previous.has(id):
				memory.erase(id)
			continue
		for ally in units:
			if ally.team == 0 and ally.health > 0 and can_see(ally.position, ally.facing, enemy.position, settings.vision_range, settings.vision_half_angle):
				live_contacts[id] = enemy.position
				memory[id] = [enemy.position, elapsed + settings.memory_seconds]
				break
	for id in memory.keys():
		if elapsed >= memory[id][1]:
			memory.erase(id)

func _update_device(device: Device) -> void:
	match device.kind:
		Device.Kind.TERMINAL:
			if elapsed >= device.access_until:
				scans.clear()
			elif elapsed >= device.next_action:
				_scan(device)
		Device.Kind.TURRET:
			if elapsed < device.next_action:
				return
			var team := 0 if elapsed < device.access_until else 1
			var target: Unit
			var distance := INF
			for unit in units:
				var candidate := device.position.distance_squared_to(unit.position)
				if unit.team != team and unit.health > 0 and candidate < distance and can_see(device.position, device.current_facing(elapsed), unit.position, device.turret_range, 32.0):
					target = unit
					distance = candidate
			if target:
				_damage(target, 16)
				device.next_action = elapsed + 0.75

func _scan(device: Device) -> void:
	scans.clear()
	for unit in units:
		if unit.team == 1 and unit.health > 0 and device.coverage.has_point(unit.position):
			scans[unit.get_instance_id()] = unit.position
	device.next_action = elapsed + scan_rng.randf_range(settings.scan_interval.x, settings.scan_interval.y)

func grant_access(device: Device) -> void:
	if device.kind == Device.Kind.TERMINAL:
		device.access_until = elapsed + settings.terminal_duration
		device.next_action = elapsed
	elif device.kind == Device.Kind.TURRET:
		device.access_until = elapsed + settings.turret_duration

func request_door(device: Device, command: String) -> bool:
	if not running or pending_door:
		return false
	pending_door = device
	pending_command = command
	pending_time = elapsed + 0.5
	return true

func _apply_door() -> void:
	var door := pending_door
	pending_door = null
	match pending_command:
		"open":
			if door.locked:
				notice.emit("Unlock the gate first")
				return
			door.set_open(true)
		"close":
			if door.occupied():
				notice.emit("Gate is blocked. Cannot close")
				return
			door.set_open(false)
		"lock":
			if not door.is_open:
				door.locked = true
		"unlock":
			door.locked = false
	notice.emit("%s · %s" % [door.caption, "open" if door.is_open else ("locked" if door.locked else "closed")])
