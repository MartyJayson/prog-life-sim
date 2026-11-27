@tool
extends PanelContainer

## Product tile in the TinySoft test store. The node name is the product id ("mouse", "lamp"…).

signal add_requested

@export var product_name := "Product":
	set(value):
		product_name = value
		_apply()
@export var price := 0:
	set(value):
		price = value
		_apply()
@export var color := Color("#6b4bd8"):
	set(value):
		color = value
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_node_ready():
		return
	%Name.text = product_name
	%Price.text = "$%d" % price
	%Glyph.text = product_name.left(1)
	var picture: StyleBoxFlat = %Picture.get_theme_stylebox("panel").duplicate()
	picture.bg_color = color
	%Picture.add_theme_stylebox_override("panel", picture)

func _add_pressed() -> void:
	add_requested.emit()
