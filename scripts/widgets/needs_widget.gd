extends PanelContainer

## Desktop status widget with the player's needs. Values are 0..100.
## Decay and refill mechanics will drive it through `set_need`.

signal need_changed(id: StringName, value: float)

const NEEDS: Array[StringName] = [&"sleep", &"hunger", &"happiness", &"social"]

func set_need(id: StringName, value: float) -> void:
	var gauge := _gauge(id)
	if gauge == null:
		push_warning("Unknown need: %s" % id)
		return
	gauge.value = value
	need_changed.emit(id, gauge.value)

func get_need(id: StringName) -> float:
	var gauge := _gauge(id)
	return gauge.value if gauge else 0.0

func _gauge(id: StringName) -> Control:
	return %Grid.get_node_or_null(NodePath(String(id)))
