extends Button

## A disk in My Computer: icon, name, a used-space bar and optional "Plug in" and "Destroy"
## buttons. Destroy asks once more before it fires.

signal plug_pressed
## The player pressed Destroy and then confirmed it.
signal destroy_confirmed

const CONFIRM_SECONDS := 3.0

var _confirming := false

func _ready() -> void:
	%Plug.pressed.connect(plug_pressed.emit)
	%Destroy.pressed.connect(_destroy_pressed)

## Shows the Destroy button (for the player's own flash drives).
func allow_destroy() -> void:
	%Destroy.show()
	_fit_actions()

func _destroy_pressed() -> void:
	if _confirming:
		destroy_confirmed.emit()
		return
	_confirming = true
	%Destroy.text = "Sure? Destroy"
	get_tree().create_timer(CONFIRM_SECONDS).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_confirming = false
			%Destroy.text = "Destroy")

## [param used] and [param total] are in KB; [param pluggable] shows the Plug in button and
## turns the tile itself into a passive card.
func setup(texture: Texture2D, tint: Color, title: String, used: int, total: int, pluggable := false) -> void:
	%Icon.texture = texture
	%Icon.self_modulate = tint
	%Title.text = title
	%Bar.value = clampf(float(used) / maxf(total, 1.0), 0.0, 1.0)
	%Bar.visible = not pluggable
	%Detail.text = "In the drawer · %s" % format_size(total) if pluggable else "%s free of %s" % [format_size(total - used), format_size(total)]
	%Plug.visible = pluggable
	_fit_actions()
	disabled = pluggable
	mouse_default_cursor_shape = Control.CURSOR_ARROW if pluggable else Control.CURSOR_POINTING_HAND

## The tile is a Button and does not grow with its children: make room for the action row.
func _fit_actions() -> void:
	%Actions.visible = %Plug.visible or %Destroy.visible
	custom_minimum_size.y = 124.0 if %Actions.visible else 86.0

## "512 KB", "3.4 MB", "15.6 GB".
static func format_size(kb: int) -> String:
	if kb >= 1048576:
		return "%s GB" % String.num(kb / 1048576.0, 1)
	if kb >= 1024:
		return "%s MB" % String.num(kb / 1024.0, 1)
	return "%d KB" % kb
