extends VBoxContainer

## DEBUG window that opens next to a TinySoft test build: the task checklist and SUBMIT.
## Follows whichever session was opened last in the browser (`Jobs.assignment_opened`).

@export var row_scene: PackedScene

var assignment: QaAssignment

@onready var rows: VBoxContainer = %Rows
@onready var submit: Button = %Submit

func _ready() -> void:
	Jobs.assignment_opened.connect(show_assignment)
	show_assignment(Jobs.active)

func show_assignment(value: QaAssignment) -> void:
	assignment = value
	for row in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	%Idle.visible = assignment == null
	if assignment == null:
		%Title.text = "TinySoft QA  ·  Test report"
		%Session.text = "No active session"
		_refresh()
		return
	%Title.text = "TinySoft QA  ·  " + ("Trial task" if assignment.trial else "Task " + assignment.title())
	%Session.text = "Session " + assignment.uuid
	for check in assignment.checks:
		var row: Button = row_scene.instantiate()
		rows.add_child(row)
		row.setup(check, assignment.mark(check))
		row.disabled = assignment.submitted
		row.mark_changed.connect(_mark_changed)
	_refresh()

func _mark_changed(check: String, mark: int) -> void:
	assignment.set_mark(check, mark as QaAssignment.Mark)
	_refresh()

func _refresh() -> void:
	if assignment == null:
		%Progress.text = ""
		submit.disabled = true
		return
	if assignment.submitted:
		%Progress.text = "Report sent. The result will arrive by mail."
		submit.text = "SUBMITTED"
		submit.disabled = true
		return
	submit.text = "SUBMIT"
	%Progress.text = "%d of %d checked" % [assignment.marked_count(), assignment.checks.size()]
	submit.disabled = not assignment.is_complete()

func _submit() -> void:
	if assignment == null:
		return
	Jobs.submit(assignment)
	for row in rows.get_children():
		row.disabled = assignment.submitted
	_refresh()
