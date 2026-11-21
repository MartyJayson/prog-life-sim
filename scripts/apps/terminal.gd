extends PanelContainer

## Terminal — a command prompt in the style of the classic Windows console.
## Built-in commands: COLOR (console colours), CLS, HELP, EXIT.

signal close_requested

const PROMPT := "C:\\Users\\User>"
const DEFAULT_ATTRIBUTE := "07"
const MAX_LINES := 400
const HEADER := "OS [Version 1.0.2026]\n(c) OS. All rights reserved.\n\n"
# Console palette indexed by the hex digit used in `color XY`.
const PALETTE := [
	["Black", Color("#0c0c0c")],
	["Blue", Color("#0037da")],
	["Green", Color("#13a10e")],
	["Aqua", Color("#3a96dd")],
	["Red", Color("#c50f1f")],
	["Purple", Color("#881798")],
	["Yellow", Color("#c19c00")],
	["White", Color("#cccccc")],
	["Gray", Color("#767676")],
	["Light Blue", Color("#3b78ff")],
	["Light Green", Color("#16c60c")],
	["Light Aqua", Color("#61d6d6")],
	["Light Red", Color("#e74856")],
	["Light Purple", Color("#b4009e")],
	["Light Yellow", Color("#f9f1a5")],
	["Bright White", Color("#f2f2f2")]
]
const COMMANDS := {
	"CLS": "Clears the screen.",
	"COLOR": "Sets the console foreground and background colors.",
	"EXIT": "Quits the terminal.",
	"HELP": "Lists the available commands."
}

var background := 0
var foreground := 7
## Everything printed so far; the input row continues on the line after it.
var buffer := ""
var _history: Array[String] = []
var _history_index := 0
var _panel_style: StyleBoxFlat

@onready var output: Label = %Output
@onready var prompt: Label = %Prompt
@onready var input: LineEdit = %Input
@onready var scroller: ScrollContainer = %Scroller

func _ready() -> void:
	# Own copy so recolouring one terminal never touches the shared scene resource.
	_panel_style = get_theme_stylebox("panel").duplicate()
	add_theme_stylebox_override("panel", _panel_style)
	prompt.text = PROMPT
	_write(HEADER)
	_apply_colors()

func set_active(active: bool) -> void:
	if active and is_inside_tree():
		input.grab_focus.call_deferred()

## Runs one command line exactly as if it was typed and confirmed with Enter.
func submit(line: String) -> void:
	var command := line.strip_edges()
	input.clear()
	if command.is_empty():
		_write(PROMPT + "\n")
		return
	_history.append(command)
	_history_index = _history.size()
	_write(PROMPT + line + "\n")
	var result: Variant = execute(command)
	if result != null:
		_write(result + ("\n" if not result.is_empty() else "") + "\n")

## Returns the text to print, or null when the command already handled the screen itself.
func execute(command: String) -> Variant:
	var parts := command.split(" ", false, 1)
	var keyword := parts[0].to_upper()
	var argument := parts[1].strip_edges() if parts.size() > 1 else ""
	match keyword:
		"COLOR":
			return _color(argument)
		"CLS":
			buffer = ""
			_render()
			return null
		"HELP":
			return _help(argument)
		"EXIT":
			close_requested.emit()
			return null
	return "'%s' is not recognized as an internal or external command,\noperable program or batch file." % parts[0]

func _color(argument: String) -> String:
	if argument == "/?":
		return _color_help()
	if argument.is_empty():
		argument = DEFAULT_ATTRIBUTE
	var digits := argument.to_upper()
	if digits.length() > 2 or not digits.is_valid_hex_number():
		return _color_help()
	if digits.length() == 1:
		digits = "0" + digits
	var new_background := digits.substr(0, 1).hex_to_int()
	var new_foreground := digits.substr(1, 1).hex_to_int()
	if new_background == new_foreground:
		return "The foreground and background colors must not be the same."
	background = new_background
	foreground = new_foreground
	_apply_colors()
	return ""

func _color_help() -> String:
	var lines := PackedStringArray([
		"Sets the console foreground and background colors.",
		"",
		"COLOR [attr]",
		"",
		"  attr      Two hex digits: the first sets the background color,",
		"            the second sets the text color. A single digit changes",
		"            only the text color, on a black background.",
		"",
		"Colors:",
	])
	for index in 8:
		lines.append("    %X = %-16s %X = %s" % [index, PALETTE[index][0], index + 8, PALETTE[index + 8][0]])
	lines.append_array([
		"",
		"COLOR without arguments restores the default colors (07).",
		"The foreground and background colors must not be the same.",
		"",
		"Example: \"COLOR 0A\" gives light green text on a black background.",
	])
	return "\n".join(lines)

func _help(argument: String) -> String:
	if not argument.is_empty():
		var keyword := argument.to_upper()
		if keyword == "COLOR":
			return _color_help()
		if COMMANDS.has(keyword):
			return "%s — %s" % [keyword, COMMANDS[keyword]]
		return "This command is not supported."
	var lines := PackedStringArray(["For more information on a specific command, type HELP command-name", ""])
	for keyword: String in COMMANDS:
		lines.append("%-10s%s" % [keyword, COMMANDS[keyword]])
	return "\n".join(lines)

func _apply_colors() -> void:
	var back: Color = PALETTE[background][1]
	var text: Color = PALETTE[foreground][1]
	_panel_style.bg_color = back
	for label: Label in [output, prompt]:
		label.add_theme_color_override("font_color", text)
	input.add_theme_color_override("font_color", text)
	input.add_theme_color_override("caret_color", text)
	input.add_theme_color_override("selection_color", Color(text, 0.35))

func _write(text: String) -> void:
	var lines := (buffer + text).split("\n")
	if lines.size() > MAX_LINES:
		lines = lines.slice(lines.size() - MAX_LINES)
	buffer = "\n".join(lines)
	_render()
	_scroll_to_end.call_deferred()

func _render() -> void:
	# The last newline is where the input row starts, so the label must not draw it again.
	output.text = buffer.trim_suffix("\n")
	output.visible = not output.text.is_empty()

func _scroll_to_end() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		scroller.scroll_vertical = int(scroller.get_v_scroll_bar().max_value)

func _input_key(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or _history.is_empty():
		return
	if event.keycode == KEY_UP:
		_history_index = maxi(_history_index - 1, 0)
	elif event.keycode == KEY_DOWN:
		_history_index = mini(_history_index + 1, _history.size())
	else:
		return
	input.text = _history[_history_index] if _history_index < _history.size() else ""
	input.caret_column = input.text.length()
	input.accept_event()

func _surface_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		input.grab_focus()
