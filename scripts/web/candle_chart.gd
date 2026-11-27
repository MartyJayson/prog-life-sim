extends Control

## Candlestick chart with volume bars, a price axis, a time axis, a live price tag and a hover
## crosshair. Feed it with `show_candles`; candles are dictionaries {"t", "o", "h", "l", "c", "v"}.

## The pointer moved over a candle (empty dictionary when it left the chart).
signal hovered(candle: Dictionary)

@export var up_color := Color("#16c784")
@export var down_color := Color("#ea3943")
@export var grid_color := Color(1, 1, 1, 0.06)
@export var axis_color := Color("#7d8795")
@export var crosshair_color := Color(1, 1, 1, 0.35)
@export var tag_text_color := Color("#ffffff")
@export var font_size := 14
## Width of the price axis on the right and height of the time axis at the bottom.
@export var axis_width := 96.0
@export var axis_height := 26.0
## Narrowest and widest room per candle: few candles are spread out up to the widest slot,
## many are squeezed down to the narrowest, and whatever still does not fit is cut off on the left.
@export var slot_width := 7.0
@export var max_slot_width := 18.0
## Share of the plot height used by volume bars at the bottom.
@export var volume_share := 0.18
@export var grid_lines := 6

var candles: Array[Dictionary] = []
## Shows seconds in time labels, for candles shorter than a minute.
var show_seconds := false
var live_price := 0.0
var _hover_index := -1
var _hover_y := -1.0

func _ready() -> void:
	mouse_exited.connect(_clear_hover)
	resized.connect(queue_redraw)

## How many candles fit across the current width.
func capacity() -> int:
	return maxi(int((size.x - axis_width) / slot_width), 1)

func show_candles(list: Array[Dictionary], price: float) -> void:
	candles = list.slice(maxi(list.size() - capacity(), 0))
	live_price = price
	if _hover_index >= candles.size():
		_hover_index = -1
	queue_redraw()
	if _hover_index >= 0:
		hovered.emit(candles[_hover_index])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index := _index_at(event.position.x)
		_hover_y = event.position.y if event.position.y < _plot_rect().end.y else -1.0
		if index != _hover_index:
			_hover_index = index
			hovered.emit(candles[index] if index >= 0 else {})
		queue_redraw()

func _clear_hover() -> void:
	_hover_index = -1
	_hover_y = -1.0
	hovered.emit({})
	queue_redraw()

func _plot_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x - axis_width, size.y - axis_height))

## Candles are drawn right-aligned so the newest one always sits next to the price axis.
func _slot_x(index: int) -> float:
	return _plot_rect().size.x - (candles.size() - index) * _slot()

func _slot() -> float:
	return clampf(_plot_rect().size.x / maxf(candles.size(), 1.0), slot_width, max_slot_width)

func _index_at(x: float) -> int:
	if candles.is_empty() or x > _plot_rect().size.x:
		return -1
	var index := candles.size() - 1 - floori((_plot_rect().size.x - x) / _slot())
	return index if index >= 0 and index < candles.size() else -1

func _draw() -> void:
	var plot := _plot_rect()
	var font := get_theme_default_font()
	if candles.is_empty() or plot.size.x <= 0.0 or plot.size.y <= 0.0:
		return
	var price_height := plot.size.y * (1.0 - volume_share)
	var low := INF
	var high := -INF
	var top_volume := 0.0
	for candle in candles:
		low = minf(low, candle.l)
		high = maxf(high, candle.h)
		top_volume = maxf(top_volume, candle.v)
	low = minf(low, live_price)
	high = maxf(high, live_price)
	var padding := maxf((high - low) * 0.08, high * 0.001)
	low = maxf(low - padding, 0.0)
	high += padding
	var to_y := func(value: float) -> float:
		return 8.0 + (high - value) / (high - low) * (price_height - 16.0)

	# Grid and price axis; labels next to the live price tag are skipped.
	var live_y: float = to_y.call(live_price)
	for i in grid_lines + 1:
		var value := low + (high - low) * i / grid_lines
		var y: float = to_y.call(value)
		draw_line(Vector2(0, y), Vector2(plot.size.x, y), grid_color)
		if absf(y - live_y) < font_size * 1.3:
			continue
		draw_string(font, Vector2(plot.size.x + 10.0, y + font_size * 0.35), _price_text(value), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, axis_color)
	draw_line(Vector2(plot.size.x, 0), Vector2(plot.size.x, plot.size.y), grid_color)
	draw_line(Vector2(0, plot.size.y), Vector2(plot.size.x, plot.size.y), grid_color)

	# Time axis: a label roughly every 110 px.
	var slot := _slot()
	var label_every := maxi(int((140.0 if show_seconds else 110.0) / slot), 1)
	for i in candles.size():
		if (candles.size() - 1 - i) % label_every != 0:
			continue
		var x := _slot_x(i) + slot * 0.5
		draw_line(Vector2(x, 0), Vector2(x, plot.size.y), grid_color)
		var text := GameClock.format_time(candles[i].t, show_seconds)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if x - width * 0.5 >= 0.0:
			draw_string(font, Vector2(x - width * 0.5, plot.size.y + axis_height * 0.5 + font_size * 0.4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, axis_color)

	# Candles and volume.
	var body_width := maxf(slot * 0.7, 1.0)
	for i in candles.size():
		var candle: Dictionary = candles[i]
		var color := up_color if candle.c >= candle.o else down_color
		var center := _slot_x(i) + slot * 0.5
		if top_volume > 0.0:
			var bar: float = plot.size.y * volume_share * 0.9 * candle.v / top_volume
			draw_rect(Rect2(center - body_width * 0.5, plot.size.y - bar, body_width, bar), Color(color, 0.28))
		draw_line(Vector2(center, to_y.call(candle.h)), Vector2(center, to_y.call(candle.l)), color, 1.0)
		var body_top: float = to_y.call(maxf(candle.o, candle.c))
		var body_bottom: float = to_y.call(minf(candle.o, candle.c))
		draw_rect(Rect2(center - body_width * 0.5, body_top, body_width, maxf(body_bottom - body_top, 1.0)), color)

	# Live price line and tag.
	var last: Dictionary = candles[-1]
	var live_color := up_color if live_price >= last.o else down_color
	_dashed_line(Vector2(0, live_y), Vector2(plot.size.x, live_y), Color(live_color, 0.8))
	_tag(font, live_y, _price_text(live_price), live_color)

	# Crosshair.
	if _hover_index >= 0:
		var x := _slot_x(_hover_index) + slot * 0.5
		draw_line(Vector2(x, 0), Vector2(x, plot.size.y), crosshair_color)
		var stamp := GameClock.format_time(candles[_hover_index].t, show_seconds)
		var stamp_width := font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 14.0
		var box := Rect2(clampf(x - stamp_width * 0.5, 0.0, plot.size.x - stamp_width), plot.size.y + 2.0, stamp_width, axis_height - 4.0)
		draw_rect(box, Color("#2a3442"))
		draw_string(font, box.position + Vector2(7.0, box.size.y * 0.5 + font_size * 0.35), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tag_text_color)
	if _hover_y >= 0.0 and _hover_y <= price_height:
		draw_line(Vector2(0, _hover_y), Vector2(plot.size.x, _hover_y), crosshair_color)
		var value := high - (_hover_y - 8.0) / (price_height - 16.0) * (high - low)
		_tag(font, _hover_y, _price_text(value), Color("#2a3442"))

func _tag(font: Font, y: float, text: String, color: Color) -> void:
	var box := Rect2(_plot_rect().size.x + 2.0, y - font_size * 0.75, axis_width - 4.0, font_size * 1.5)
	draw_rect(box, color)
	draw_string(font, Vector2(box.position.x + 8.0, y + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tag_text_color)

func _dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var length := from.distance_to(to)
	var direction := (to - from).normalized()
	var offset := 0.0
	while offset < length:
		draw_line(from + direction * offset, from + direction * minf(offset + 6.0, length), color, 1.0)
		offset += 10.0

## Axis prices: fewer digits than in the page labels, without the dollar sign.
func _price_text(value: float) -> String:
	var decimals := 2 if value >= 1.0 else (4 if value >= 0.01 else 6)
	return SkamMarket.format_number(value, decimals)
