extends VBoxContainer

var entry := "0"
var accumulator := 0.0
var operation := ""
var replace_entry := true

@onready var display: Label = %Display

func _press(key: String) -> void:
	if key == "C" or entry == "Error":
		_reset()
		if key == "C":
			display.text = entry
			return
	match key:
		"+", "−", "×", "÷", "=":
			if not operation.is_empty() and not replace_entry:
				if not _calculate():
					display.text = entry
					return
			accumulator = entry.to_float()
			operation = "" if key == "=" else key
			replace_entry = true
		"±":
			if entry != "0":
				entry = entry.trim_prefix("-") if entry.begins_with("-") else "-" + entry
				replace_entry = false
		"⌫":
			if not replace_entry:
				entry = entry.left(-1)
				if entry.is_empty() or entry == "-":
					entry = "0"
		_:
			if replace_entry:
				entry = "0"
				replace_entry = false
			if key == ".":
				if not entry.contains("."):
					entry += "."
			elif entry.length() < 14:
				entry = key if entry == "0" else entry + key
	display.text = entry

func _reset() -> void:
	entry = "0"
	accumulator = 0.0
	operation = ""
	replace_entry = true

func _calculate() -> bool:
	var operand := entry.to_float()
	match operation:
		"+": accumulator += operand
		"−": accumulator -= operand
		"×": accumulator *= operand
		"÷":
			if operand == 0.0:
				entry = "Error"
				operation = ""
				replace_entry = true
				return false
			accumulator /= operand
	entry = String.num(accumulator, 12).trim_suffix(".0")
	return true
