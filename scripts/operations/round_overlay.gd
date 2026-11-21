extends CenterContainer

signal start_requested
signal new_round_requested

const READY_COLOR := Color("#8ACBFF")
const VICTORY_COLOR := Color("#71DFB2")
const DEFEAT_COLOR := Color("#FF929C")
const DRAW_COLOR := Color("#FFD84D")

func show_ready() -> void:
	$Panel/Content/Title.text = "OPERATION"
	$Panel/Content/Title.modulate = READY_COLOR
	$Panel/Content/Accent.color = READY_COLOR
	$Panel/Content/Description.text = "Dust II · CT Defence"
	$Panel/Content/Start.show()
	$Panel/Content/NewRound.hide()
	show()

func show_result(result: String) -> void:
	var parts := result.split(" · ", true, 1)
	var tint := DRAW_COLOR
	if parts[0] == "Victory":
		tint = VICTORY_COLOR
	elif parts[0] == "Defeat":
		tint = DEFEAT_COLOR
	$Panel/Content/Title.text = parts[0].to_upper()
	$Panel/Content/Title.modulate = tint
	$Panel/Content/Accent.color = tint
	$Panel/Content/Description.text = parts[1].left(1).to_upper() + parts[1].substr(1) if parts.size() > 1 else "Round over"
	$Panel/Content/Start.hide()
	$Panel/Content/NewRound.show()
	show()

func _start_pressed() -> void:
	start_requested.emit()

func _new_round_pressed() -> void:
	new_round_requested.emit()
