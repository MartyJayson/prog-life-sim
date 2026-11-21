extends SceneTree

# Run with: godot --headless --path . --script res://tests/operation_ui_test.gd
const Operations = preload("res://scenes/apps/operations.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	if condition:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)

func settle() -> void:
	await physics_frame
	await physics_frame

func run() -> void:
	var app = Operations.instantiate()
	root.add_child(app)
	var mission = app.mission
	var overlay = app.get_node("Body/Map/RoundOverlay")
	var start_button = overlay.get_node("Panel/Content/Start")
	var new_round = overlay.get_node("Panel/Content/NewRound")
	var title = overlay.get_node("Panel/Content/Title")
	var description = overlay.get_node("Panel/Content/Description")
	var position: Vector2 = mission.units[0].position
	await settle()
	check(not mission.running and mission.ready_to_start and mission.elapsed == 0.0, "opening operation waits for Start")
	check(mission.units.size() == 10 and mission.units[0].position == position and mission.projectiles.is_empty(), "prepared units stay still without firing")
	check(overlay.visible and start_button.visible and not new_round.visible, "Start button is available before round")
	check(not app.has_node("Header"), "old status header removed")
	var rows = app.get_node("Body/Roster/List/AllyRows")
	var stats: String = rows.get_child(0).get_node("Stats").text
	var reaction: Vector2 = mission.settings.ally_reaction
	check(stats.contains("Accuracy %d%%" % roundi(mission.units[0].accuracy * 100.0)) and stats.contains("Damage %d" % mission.settings.damage), "roster shows actual accuracy and damage")
	check(stats.contains("%.2f–%.2f s" % [reaction.x, reaction.y]) and stats.contains("%.2f s" % mission.settings.shot_interval), "roster shows actual reaction range and shot interval")
	start_button.pressed.emit()
	await settle()
	check(mission.running and mission.elapsed > 0.0 and not overlay.visible, "Start begins simulation and hides overlay")
	var unit_id: int = mission.units[0].get_instance_id()
	start_button.pressed.emit()
	check(mission.units[0].get_instance_id() == unit_id, "repeated Start does not reset round")
	for unit in mission.units:
		if unit.team == 1:
			mission._damage(unit, 1000)
	await settle()
	check(not mission.running and overlay.visible and title.text == "VICTORY", "victory appears in centre overlay")
	check(not start_button.visible and new_round.visible and mission.projectiles.is_empty(), "finished round offers New Round and clears bullets")
	start_button.pressed.emit()
	check(not mission.running, "finished round cannot resume through Start")
	new_round.pressed.emit()
	await settle()
	check(not mission.running and mission.elapsed == 0.0 and mission.units[0].health == 100, "New Round prepares fresh units without auto-start")
	check(title.text == "OPERATION" and start_button.visible and not new_round.visible, "New Round restores Start screen")
	start_button.pressed.emit()
	for unit in mission.units:
		if unit.team == 0:
			mission._damage(unit, 1000)
	await settle()
	check(not mission.running and overlay.visible and title.text == "DEFEAT", "defeat appears in centre overlay")
	mission.ended.emit("Victory · bomb defused")
	check(title.text == "VICTORY" and description.text == "Bomb defused", "result keeps bomb outcome explanation")
	mission.ended.emit("Draw")
	check(title.text == "DRAW", "draw result is supported")
	app.queue_free()
	await process_frame
	print("Operation UI checks finished; failures: ", failures)
	quit(1 if failures else 0)
