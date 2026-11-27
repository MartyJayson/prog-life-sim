extends PanelContainer

## One vacancy on stupidjob.oc with its "Apply now" button, kept in sync with the `Jobs` status.

const JobBoard = preload("res://scripts/jobs/job_board.gd")
const STATUS_TEXT := {
	JobBoard.Status.APPLIED: ["Application sent", "Check your mail — the employer will send a test assignment."],
	JobBoard.Status.HIRED: ["Hired", "You work here. New tasks arrive by mail."],
	JobBoard.Status.FIRED: ["Position closed", "The employer ended your engagement. You can no longer apply."],
}

@export var tag_scene: PackedScene

var listing: JobListing

func show_listing(value: JobListing) -> void:
	listing = value
	%Title.text = listing.title
	%Company.text = "%s  ·  %s" % [listing.company, listing.location]
	%Initials.text = listing.initials
	var logo: StyleBoxFlat = %Logo.get_theme_stylebox("panel").duplicate()
	logo.bg_color = listing.logo_color
	%Logo.add_theme_stylebox_override("panel", logo)
	%Summary.text = listing.summary
	%Posted.text = listing.posted
	%Pay.text = listing.pay
	for tag in listing.tags:
		var chip: Label = tag_scene.instantiate()
		chip.text = tag
		%Tags.add_child(chip)
	if not Jobs.status_changed.is_connected(_status_changed):
		Jobs.status_changed.connect(_status_changed)
	refresh()

func refresh() -> void:
	var state := Jobs.status(listing.id)
	var apply: Button = %Apply
	apply.disabled = state != JobBoard.Status.OPEN
	apply.text = STATUS_TEXT[state][0] if STATUS_TEXT.has(state) else "Apply now"
	%Status.visible = STATUS_TEXT.has(state)
	%Status.text = STATUS_TEXT[state][1] if STATUS_TEXT.has(state) else ""

func _apply() -> void:
	Jobs.apply(listing)

func _status_changed(listing_id: String) -> void:
	if listing and listing_id == listing.id:
		refresh()
