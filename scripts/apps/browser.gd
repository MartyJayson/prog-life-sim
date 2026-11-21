extends VBoxContainer

signal launch_requested(id: String)

const HOME := "home.oc"
const SEARCH := "search.oc"
const PAGES := {
	HOME: preload("res://scenes/web/home.tscn"),
	SEARCH: preload("res://scenes/web/search.tscn"),
	"news.oc": preload("res://scenes/web/news.tscn"),
	"news.oc/desk": preload("res://scenes/web/desk.tscn"),
	"news.oc/arcade": preload("res://scenes/web/arcade.tscn"),
	"games.oc": preload("res://scenes/web/games.tscn"),
	"about.oc": preload("res://scenes/web/about.tscn"),
	"casino.oc": preload("res://scenes/web/casino.tscn"),
	"casino.oc/blackjack": preload("res://scenes/web/blackjack.tscn"),
	"casino.oc/slots": preload("res://scenes/web/slots.tscn"),
	"bank.oc": preload("res://scenes/web/bank.tscn"),
	"bank.oc/payments": preload("res://scenes/web/bank_payments.tscn")
}
const MISSING = preload("res://scenes/web/missing.tscn")
const SEARCH_RESULT = preload("res://scenes/web/search_result.tscn")

var history: Array[String] = []
var index := -1
var page: VBoxContainer
var directory: Dictionary[String, String] = {}

@onready var address: LineEdit = %Address
@onready var scroller: ScrollContainer = %Scroller
@onready var back: Button = %Back
@onready var forward: Button = %Forward

func _ready() -> void:
	_go_home()
	for button: Button in page.find_children("*", "Button"):
		if button.has_meta("destination"):
			directory[button.get_meta("destination")] = button.text

func open_url(url: String) -> void:
	_navigate(url)

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

func _render() -> void:
	var current := history[index]
	address.text = current
	back.disabled = index == 0
	forward.disabled = index == history.size() - 1
	var parts := current.split("?", true, 1)
	var path := parts[0]
	var scene: PackedScene = PAGES.get(path, MISSING)
	if page:
		scroller.remove_child(page)
		page.queue_free()
	page = scene.instantiate()
	scroller.add_child(page)
	scroller.set_deferred("scroll_vertical", 0)
	for button: Button in page.find_children("*", "Button"):
		if button.has_meta("destination"):
			button.pressed.connect(_navigate.bind(button.get_meta("destination")))
		elif button.has_meta("app"):
			button.pressed.connect(launch_requested.emit.bind(button.get_meta("app")))
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
