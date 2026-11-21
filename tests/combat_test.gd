extends SceneTree

# Run with: godot --headless --path . --script res://tests/combat_test.gd
const Operations = preload("res://scenes/apps/operations.tscn")
const LegacyLayout = preload("res://scenes/operations/layout.tscn")
const DustLayout = preload("res://scenes/operations/maps/dust_ii.tscn")
var failures := 0
var app
var mission

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	if not condition:
		failures += 1
		push_error(caption)
	else:
		print("PASS: ", caption)

func settle() -> void:
	await physics_frame
	await physics_frame

func arrange(shooter_team: int = 0) -> Array:
	mission._clear_combat_effects()
	for index in range(mission.units.size()):
		var unit = mission.units[index]
		unit.position = Vector2(2000 + index * 30, 2000)
		unit.health = 100
		unit.get_node("Agent").avoidance_enabled = false
		unit.get_node("Shape").disabled = false
	var shooter = mission.units[shooter_team * 5]
	var friend = mission.units[shooter_team * 5 + 1]
	var target = mission.units[(1 - shooter_team) * 5]
	var behind = mission.units[(1 - shooter_team) * 5 + 1]
	shooter.position = Vector2(100, 50)
	friend.position = Vector2(130, 50)
	target.position = Vector2(220, 50)
	behind.position = Vector2(250, 50)
	shooter.accuracy = 1.0
	return [shooter, friend, target, behind]

func run() -> void:
	app = Operations.instantiate()
	root.add_child(app)
	mission = app.mission
	mission.set_physics_process(false)
	mission.load_layout(LegacyLayout)
	for team in range(2):
		var actors := arrange(team)
		await settle()
		mission.fire(actors[0], actors[2])
		check(actors[2].health == 100, "team %d: firing does not apply instant damage" % team)
		check(mission.muzzle_flashes.size() == 1, "team %d: muzzle flash created" % team)
		mission._advance_combat_effects(0.01)
		check(actors[2].health == 100, "team %d: damage waits for flight" % team)
		mission._advance_combat_effects(0.2)
		check(actors[2].health == 100 - mission.settings.damage, "team %d: swept hit damages first enemy" % team)
		check(actors[1].health == 100 and actors[3].health == 100, "team %d: no friendly fire or penetration" % team)
		check(mission.projectiles.is_empty() and mission.muzzle_flashes.is_empty(), "hit and flash expire")
	var actors := arrange()
	actors[0].accuracy = 0.0
	await settle()
	mission.fire(actors[0], actors[2])
	mission._advance_combat_effects(0.2)
	check(actors[2].health == 100, "miss uses physical spread")
	mission.projectiles[0].position = Vector2(1500, -100)
	mission._advance_combat_effects(2.0)
	check(mission.projectiles.is_empty(), "range limit removes missed bullets")
	actors = arrange()
	await settle()
	mission.fire(actors[0], actors[2])
	actors[2].position.y += 30
	actors[3].position.y += 30
	await settle()
	mission._advance_combat_effects(0.2)
	check(actors[2].health == 100, "moving target can dodge")
	actors = arrange()
	actors[0].position = Vector2(350, 230)
	actors[1].position = Vector2(350, 260)
	actors[2].position = Vector2(470, 230)
	actors[3].position = Vector2(470, 260)
	var door = mission.devices.get_node("Door0")
	door.set_open(false)
	await settle()
	mission.fire(actors[0], actors[2])
	mission._advance_combat_effects(0.2)
	check(actors[2].health == 100 and mission.projectiles.is_empty(), "closed door stops bullet")
	door.set_open(true)
	await settle()
	mission.fire(actors[0], actors[2])
	mission._advance_combat_effects(0.2)
	check(actors[2].health == 100 - mission.settings.damage, "open door passes bullet")
	actors[0].position = Vector2(350, 180)
	actors[2].position = Vector2(470, 180)
	await settle()
	mission.fire(actors[0], actors[2])
	mission._advance_combat_effects(0.2)
	check(actors[2].health == 100 - mission.settings.damage and mission.projectiles.is_empty(), "wall stops high speed bullet")
	actors = arrange()
	mission.fire(actors[0], actors[2])
	mission.running = false
	mission.ended.emit("test")
	check(mission.projectiles.is_empty() and mission.muzzle_flashes.is_empty(), "round end clears effects")
	mission.load_layout(DustLayout)
	mission.fire(actors[0], actors[2])
	app._restart()
	check(mission.projectiles.is_empty() and mission.muzzle_flashes.is_empty(), "restart clears effects")
	var rows = app.get_node("Body/Roster/List/AllyRows")
	check(rows.get_child_count() == 5, "roster has five allies")
	var ally = mission.units[0]
	mission._damage(ally, 24)
	rows.get_child(0).refresh()
	check(rows.get_child(0).get_node("Heading/HP").text == "76 HP", "roster refreshes damage")
	mission._damage(ally, 100)
	rows.get_child(0).refresh()
	check(rows.get_child(0).get_node("State").visible and rows.get_child(0).get_node("Health").value == 0, "roster keeps eliminated allies")
	app._restart()
	await settle()
	var map = app.get_node("Body/Map")
	map.refresh_in = 0.0
	map._physics_process(0.1)
	check(map.cones.size() == 10, "both teams have vision cones")
	check(mission.units[0].identity_color == mission.units[5].identity_color, "teams reuse identity palette")
	map._cache_walls()
	var cached_walls = map.wall_texture
	check(cached_walls.get_image().get_pixel(4, 4).a == 1.0, "wall cache contains opaque walls")
	check(cached_walls.get_image().get_pixel(80, 80).a == 0.0, "wall cache leaves floors transparent for vision cones")
	app._restart()
	map._cache_walls()
	check(map.wall_texture == cached_walls, "restart reuses static wall cache")
	mission.fire(mission.units[0], mission.units[5])
	mission.load_layout(LegacyLayout)
	check(mission.projectiles.is_empty() and mission.muzzle_flashes.is_empty(), "layout change clears effects")
	map._cache_walls()
	check(map.wall_texture != cached_walls and map.wall_layout_id == mission.layout.get_instance_id(), "layout change rebuilds wall cache")
	app.queue_free()
	await process_frame
	print("Combat checks finished; failures: ", failures)
	quit(1 if failures else 0)
