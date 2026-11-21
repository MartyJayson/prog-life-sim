extends PanelContainer

## One playing card on the blackjack table: face with corner indices, or the casino back.

const INK := Color("#152b37")
const RED := Color("#ad2842")

@export var face_style: StyleBox
@export var back_style: StyleBox

@onready var face: Label = $Face
@onready var top_corner: Label = $TopCorner
@onready var bottom_corner: Label = $BottomCorner

func show_face(rank: String, suit: String, red: bool) -> void:
	var ink := RED if red else INK
	add_theme_stylebox_override("panel", face_style)
	face.text = "%s\n%s" % [rank, suit]
	for label: Label in [face, top_corner, bottom_corner]:
		label.add_theme_color_override("font_color", ink)
	top_corner.text = "%s\n%s" % [rank, suit]
	bottom_corner.text = top_corner.text
	top_corner.show()
	bottom_corner.show()

func show_back() -> void:
	add_theme_stylebox_override("panel", back_style)
	face.text = "◆"
	face.add_theme_color_override("font_color", Color("#ffcf4a"))
	top_corner.hide()
	bottom_corner.hide()

## Slides the card in from the shoe (top right) after `delay` seconds.
func deal_in(delay: float) -> void:
	modulate.a = 0.0
	pivot_offset = custom_minimum_size * 0.5
	scale = Vector2.ONE * 0.6
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.18).set_delay(delay)
	tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Turns the card over: squeeze to an edge, then open on the new side.
func flip_in() -> void:
	pivot_offset = custom_minimum_size * 0.5
	scale = Vector2(0.0, 1.0)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
