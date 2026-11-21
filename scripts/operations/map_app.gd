extends VBoxContainer

signal hack_requested(device: Node2D)
signal operation_reset

const AllyRowScene = preload("res://scenes/operations/ally_row.tscn")

@onready var mission := $Simulation/Mission

func _ready() -> void:
	%Map.mission = mission
	_restart()

func _process(_delta: float) -> void:
	for row in %AllyRows.get_children():
		row.refresh()

func _restart() -> void:
	operation_reset.emit()
	mission.restart()
	%Map.reset_view()
	%RoundOverlay.show_ready()
	for row in %AllyRows.get_children():
		%AllyRows.remove_child(row)
		row.queue_free()
	for unit in mission.units:
		if unit.team == 0:
			var row = AllyRowScene.instantiate()
			%AllyRows.add_child(row)
			row.bind(unit, mission.settings)

func _start() -> void:
	mission.start()
	if mission.running:
		%RoundOverlay.hide()

func _select_device(device: Node2D) -> void:
	hack_requested.emit(device)

func _on_ended(result: String) -> void:
	%RoundOverlay.show_result(result)
