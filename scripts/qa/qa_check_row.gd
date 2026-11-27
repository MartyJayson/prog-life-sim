extends Button

## One checklist entry in the DEBUG window. Each click cycles: not tested -> works -> broken.

signal mark_changed(check: String, mark: int)

const STATES := {
	QaAssignment.Mark.NONE: [&"QaBox", "Not tested"],
	QaAssignment.Mark.PASS: [&"QaBoxPass", "Works"],
	QaAssignment.Mark.FAIL: [&"QaBoxFail", "Bug found"],
}

@export var pass_icon: Texture2D
@export var fail_icon: Texture2D

var check := ""
var mark := QaAssignment.Mark.NONE

func setup(check_id: String, value: QaAssignment.Mark) -> void:
	check = check_id
	%Caption.text = QaAssignment.caption_of(check_id)
	set_mark(value)

func set_mark(value: QaAssignment.Mark) -> void:
	mark = value
	%Box.theme_type_variation = STATES[mark][0]
	%State.text = STATES[mark][1]
	%Mark.texture = pass_icon if mark == QaAssignment.Mark.PASS else fail_icon if mark == QaAssignment.Mark.FAIL else null

func _cycle() -> void:
	if disabled:
		return
	set_mark(((mark + 1) % STATES.size()) as QaAssignment.Mark)
	mark_changed.emit(check, mark)
