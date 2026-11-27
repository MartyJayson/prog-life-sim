@tool
extends VBoxContainer

## One need on the status widget: a ring with an icon inside, the need's name
## and its value in percent. `value` is 0..100.

@export var title := "Need":
	set(v):
		title = v
		_refresh()
@export var icon: Texture2D:
	set(v):
		icon = v
		_refresh()
@export var color := Color(0.16, 0.45, 0.85):
	set(v):
		color = v
		_refresh()
@export_range(0.0, 100.0, 1.0) var value := 100.0:
	set(v):
		value = clampf(v, 0.0, 100.0)
		_refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	%Ring.value = value / 100.0
	%Ring.color = color
	%Icon.texture = icon
	%Title.text = title
	%Value.text = "%d%%" % roundi(value)
	tooltip_text = "%s: %d%%" % [title, roundi(value)]
