extends Control

## One vertical reel of the Slots OS machine. Shows three rows of its strip, spins freely
## after start_spin() and brakes onto a given stop within half a second after stop_at().

signal stopped

const COLORS := {
	"10": Color("#4aa8ff"),
	"J": Color("#3fd47f"),
	"Q": Color("#c47dff"),
	"K": Color("#ff5a64"),
	"$": Color("#ffd23f"),
	"💩": Color("#8a5528")
}
const POOP := "💩"
const POOP_TEXTURE = preload("res://assets/generated/poop.svg")
const ROWS := 3
const FREE_SPEED := 17.0
const ACCELERATION := 60.0
const BRAKE_SYMBOLS := 4
const BRAKE_TIME := 0.38
const SETTLE_TIME := 0.12
const OVERSHOOT := 0.2

var strip: Array = []
var roll := 0.0
var highlight: Array[int] = []
var spinning := false
var stopping := false
var _free_speed := 0.0
var _free_spin := false
var _tween: Tween
# While braking, symbols that have not entered the window yet are drawn from the final stop,
# so the reel lands on it after a short, fixed distance.
var _brake_stop := -1
var _brake_base := 0
var _speed := 0.0
var _last_roll := 0.0
var _time := 0.0
var _card := StyleBoxFlat.new()

func _ready() -> void:
	_card.set_corner_radius_all(12)
	_card.set_border_width_all(3)
	_card.anti_aliasing = true
	resized.connect(queue_redraw)

func setup(symbols: Array, stop: int) -> void:
	strip = symbols
	roll = float(stop)
	_last_roll = roll
	queue_redraw()

func symbol_at(row: int) -> String:
	return strip[posmod(roundi(roll) + row, strip.size())]

func start_spin() -> void:
	var count := strip.size()
	roll = float(posmod(roundi(roll), count))
	_last_roll = roll
	highlight.clear()
	spinning = true
	stopping = false
	_free_spin = false
	_free_speed = 0.0
	# A short pull upwards before the reel rolls down, like a real lever-driven reel.
	_tween = create_tween()
	_tween.tween_property(self, "roll", roll + 0.3, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _free_spin = true)

func stop_at(stop: int) -> bool:
	if not spinning or stopping:
		return false
	stopping = true
	_free_spin = false
	if _tween:
		_tween.kill()
	var top := floori(roll)
	_brake_base = top - BRAKE_SYMBOLS
	_brake_stop = stop
	var target := float(_brake_base)
	_tween = create_tween()
	_tween.tween_property(self, "roll", target - OVERSHOOT, BRAKE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "roll", target, SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_finish.bind(float(stop)))
	return true

func _symbol(index: int) -> String:
	if _brake_stop >= 0 and index <= _brake_base + 2:
		return strip[posmod(_brake_stop + index - _brake_base, strip.size())]
	return strip[posmod(index, strip.size())]

func _finish(target: float) -> void:
	roll = float(posmod(roundi(target), strip.size()))
	_last_roll = roll
	_speed = 0.0
	_brake_stop = -1
	spinning = false
	stopping = false
	queue_redraw()
	stopped.emit()

func _process(delta: float) -> void:
	_time += delta
	if _free_spin:
		_free_speed = minf(FREE_SPEED, _free_speed + ACCELERATION * delta)
		roll -= _free_speed * delta
	_speed = absf(roll - _last_roll) / maxf(delta, 0.001)
	_last_roll = roll
	if spinning or not highlight.is_empty():
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#150b26"))
	if strip.is_empty():
		return
	var step := size.y / ROWS
	var top := floori(roll)
	var offset := roll - top
	var blur := clampf((_speed - 5.0) / 20.0, 0.0, 1.0)
	for k in range(-1, ROWS + 1):
		var symbol := _symbol(top + k)
		var cell := Rect2(0.0, (k - offset) * step, size.x, step)
		_draw_symbol(symbol, cell, blur, not spinning and highlight.has(k))
	_draw_shade(step)

func _draw_symbol(symbol: String, cell: Rect2, blur: float, lit: bool) -> void:
	var color: Color = COLORS[symbol]
	var jackpot := symbol == "$"
	var card := cell.grow_individual(-8.0, -6.0, -8.0, -6.0)
	if lit:
		var pulse := 1.0 + 0.06 * sin(_time * 9.0)
		card = Rect2(card.get_center() - card.size * pulse * 0.5, card.size * pulse)
	var face := Color("#3b2600") if jackpot else Color("#fff8ec").lerp(color, 0.1)
	if symbol == POOP:
		face = Color("#efe2cf")
	_card.bg_color = Color(face, 1.0 - 0.45 * blur)
	_card.border_color = Color(color.lightened(0.35) if lit else color.darkened(0.15), 1.0 - 0.5 * blur)
	_card.shadow_color = Color(color, 0.75)
	_card.shadow_size = 16 if lit else 0
	draw_style_box(_card, card)
	if symbol == POOP:
		var side := minf(card.size.x, card.size.y) * 0.84
		var picture := Rect2(card.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		if blur > 0.0:
			for ghost in [-1.0, 1.0]:
				draw_texture_rect(POOP_TEXTURE, Rect2(picture.position + Vector2(0.0, ghost * cell.size.y * 0.18 * blur), picture.size), false, Color(1, 1, 1, 0.3 * blur))
		draw_texture_rect(POOP_TEXTURE, picture, false, Color(1, 1, 1, 1.0 - 0.5 * blur))
		return
	var font := get_theme_default_font()
	var font_size := int(cell.size.y * (0.42 if symbol == "10" else 0.5))
	var text_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(
		card.get_center().x - text_size.x * 0.5,
		card.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	var ink := color.lightened(0.25) if jackpot else color.darkened(0.12)
	var outline := Color("#2a1200") if jackpot else Color(color.darkened(0.6), 0.85)
	if blur > 0.0:
		for ghost in [-1.0, 1.0]:
			var shifted := baseline + Vector2(0.0, ghost * cell.size.y * 0.18 * blur)
			draw_string(font, shifted, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(ink, 0.3 * blur))
	draw_string_outline(font, baseline, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(outline, 1.0 - 0.6 * blur))
	draw_string(font, baseline, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(ink, 1.0 - 0.5 * blur))

func _draw_shade(step: float) -> void:
	var dark := Color(0.03, 0.0, 0.08, 0.7)
	var clear := Color(0.03, 0.0, 0.08, 0.0)
	var band := step * 0.32
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, band), Vector2(0.0, band)]),
		PackedColorArray([dark, dark, clear, clear])
	)
	draw_polygon(
		PackedVector2Array([Vector2(0.0, size.y - band), Vector2(size.x, size.y - band), size, Vector2(0.0, size.y)]),
		PackedColorArray([clear, clear, dark, dark])
	)
	draw_rect(Rect2(size.x * 0.06, 0.0, size.x * 0.14, size.y), Color(1, 1, 1, 0.035))
