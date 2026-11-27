extends VBoxContainer

signal launch_requested(id: String)

const HOME := "home.oc"
const SEARCH := "search.oc"
const PAGES := {
	HOME: preload("res://scenes/web/home.tscn"),
	SEARCH: preload("res://scenes/web/search.tscn"),
	"news.oc": preload("res://scenes/web/news.tscn"),
	"news.oc/desk": preload("res://scenes/web/desk.tscn"),
	"about.oc": preload("res://scenes/web/about.tscn"),
	"casino.oc": preload("res://scenes/web/casino.tscn"),
	"casino.oc/blackjack": preload("res://scenes/web/blackjack.tscn"),
	"casino.oc/slots": preload("res://scenes/web/slots.tscn"),
	"casino.oc/cashier": preload("res://scenes/web/casino_cashier.tscn"),
	"bank.oc": preload("res://scenes/web/bank.tscn"),
	"bank.oc/payments": preload("res://scenes/web/bank_payments.tscn"),
	"stupidjob.oc": preload("res://scenes/web/work.tscn")
}
## Sites that serve every path under their host; the page gets the rest of the path via `open_path`.
const HOSTS := {
	"tinysoft.test.oc": preload("res://scenes/web/tinysoft.tscn")
}
const MISSING = preload("res://scenes/web/missing.tscn")
const SEARCH_RESULT = preload("res://scenes/web/search_result.tscn")

## Shortest and longest time a page takes to load, in seconds; every load picks a random time.
@export var load_time := Vector2(0.5, 2.0)

## Loads pages at once instead of simulating the network (used by tests).
static var instant_loading := false

var history: Array[String] = []
var index := -1
var page: VBoxContainer
var directory: Dictionary[String, String] = {}
## True while the current address is still loading; `page` is null until it finishes.
var loading := false
var _load_id := 0
var _bar_tween: Tween
var _rng := RandomNumberGenerator.new()

@onready var address: LineEdit = %Address
@onready var scroller: ScrollContainer = %Scroller
@onready var back: Button = %Back
@onready var forward: Button = %Forward
@onready var load_bar: ProgressBar = %LoadBar
@onready var status: Label = %Status

func _ready() -> void:
	_rng.randomize()
	var home: Node = PAGES[HOME].instantiate()
	for button: Button in home.find_children("*", "Button"):
		if button.has_meta("destination"):
			directory[button.get_meta("destination")] = button.text
	home.free()
	_go_home()

func open_url(url: String) -> void:
	_navigate(url)

## Loads the current address again from scratch.
func reload() -> void:
	if index >= 0:
		_render()

func _go_home() -> void:
	_navigate(HOME)

func _submit_address() -> void:
	_navigate(address.text)

func _navigate(raw: String) -> void:
	var parts := raw.strip_edges().split("?", true, 1)
	var path := parts[0].to_lower().trim_prefix("https://").trim_prefix("http://").trim_suffix("/")
	if path.is_empty():
		return
	var target := path if parts.size() == 1 else path + "?" + parts[1]
	if index < 0 or history[index] != target:
		history.resize(index + 1)
		history.append(target)
		index += 1
	_render()

func _step(delta: int) -> void:
	index = clampi(index + delta, 0, history.size() - 1)
	_render()

## Shows the current history entry: clears the old page, then loads the new one after a delay.
func _render() -> void:
	var current := history[index]
	address.text = current
	back.disabled = index == 0
	forward.disabled = index == history.size() - 1
	if page:
		scroller.remove_child(page)
		page.queue_free()
		page = null
	_load_id += 1
	if instant_loading:
		_show_page(_load_id)
		return
	loading = true
	status.text = "Waiting for %s…" % current.get_slice("/", 0).get_slice("?", 0)
	status.show()
	var duration := _rng.randf_range(load_time.x, load_time.y)
	_animate_bar(duration)
	get_tree().create_timer(duration).timeout.connect(_show_page.bind(_load_id))

## Progress creeps up while waiting and jumps to the end when the page arrives.
func _animate_bar(duration: float) -> void:
	if _bar_tween:
		_bar_tween.kill()
	load_bar.value = 0.05
	load_bar.modulate.a = 1.0
	_bar_tween = create_tween()
	_bar_tween.tween_property(load_bar, "value", 0.85, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _finish_bar() -> void:
	if _bar_tween:
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(load_bar, "value", 1.0, 0.12)
	_bar_tween.tween_property(load_bar, "modulate:a", 0.0, 0.2)

func _show_page(load_id: int) -> void:
	# A newer navigation started while this one was loading.
	if load_id != _load_id:
		return
	loading = false
	status.hide()
	if not instant_loading:
		_finish_bar()
	var parts := history[index].split("?", true, 1)
	var path := parts[0]
	var host := path.get_slice("/", 0)
	var scene: PackedScene = PAGES.get(path, HOSTS.get(host, MISSING))
	page = scene.instantiate()
	scroller.add_child(page)
	scroller.set_deferred("scroll_vertical", 0)
	for button: Button in page.find_children("*", "Button"):
		if button.has_meta("destination"):
			button.pressed.connect(_navigate.bind(button.get_meta("destination")))
		elif button.has_meta("app"):
			button.pressed.connect(launch_requested.emit.bind(button.get_meta("app")))
	if page.has_signal("launch_requested"):
		page.launch_requested.connect(launch_requested.emit)
	if HOSTS.get(host) == scene:
		page.open_path(path.trim_prefix(host).trim_prefix("/"))
	if scene == MISSING:
		page.get_node("Subtitle").text = "The OS web could not find " + path
	elif path == SEARCH:
		_setup_search(parts[1].uri_decode() if parts.size() > 1 else "")

func _setup_search(query: String) -> void:
	var field: LineEdit = page.get_node("SearchRow/Query")
	field.text = query
	field.text_submitted.connect(_search)
	page.get_node("SearchRow/Submit").pressed.connect(func(): _search(field.text))
	var results: VBoxContainer = page.get_node("Results")
	for destination: String in directory:
		var caption := directory[destination]
		if query.is_empty() or (caption + " " + destination).containsn(query):
			var result: Button = SEARCH_RESULT.instantiate()
			result.text = caption
			result.pressed.connect(_navigate.bind(destination))
			results.add_child(result)
	if results.get_child_count() == 0:
		var empty: Label = page.get_node("Empty")
		empty.text = "No results for “" + query + "”."
		empty.show()

func _search(query: String) -> void:
	_navigate(SEARCH + "?" + query.strip_edges().uri_encode())
