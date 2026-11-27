extends VBoxContainer

## tinysoft.test.oc/{uuid} — TinySoft's staging store, opened from a QA task letter.
##
## Every checklist control behaves correctly unless the session's `QaAssignment` lists a bug
## for it; then it misbehaves in a visible way (does nothing, does the wrong thing, or crashes).
## Opening a valid session also opens the DEBUG report window.

signal launch_requested(id: String)

const DEBUG_APP := "qa_debug"
const SECTIONS: Array[String] = ["home", "catalog", "cart", "contacts"]
const CRASHES := {
	"tab": "Uncaught RouteError: no handler registered for “/%s” (router.js:214)",
	"add": "TypeError: Cannot read properties of undefined (reading 'price') at addToCart (cart.js:58)",
	"clear": "StorageError: cart session is locked by another request (cart.js:131)",
	"checkout": "HTTP 500 Internal Server Error — POST /api/orders failed (orders.js:77)",
}

@export var cart_line_scene: PackedScene

var assignment: QaAssignment
var section := "home"
## product id -> quantity, in the order items were added.
var cart: Dictionary[String, int] = {}
var _orders := 0

@onready var tabs: HBoxContainer = %Tabs
@onready var grid: GridContainer = %Grid

func _ready() -> void:
	for id in SECTIONS:
		tabs.get_node(id).pressed.connect(_tab_pressed.bind(id))
	for card in grid.get_children():
		card.add_requested.connect(_add_pressed.bind(String(card.name)))
	_show_denied("Access denied", "This test environment needs a valid session link from your QA task letter.")

## Called by the browser with the part of the address after the host, i.e. the session UUID.
func open_path(rest: String) -> void:
	var uuid := rest.get_slice("/", 0)
	var known: QaAssignment = Jobs.find(uuid) if not uuid.is_empty() else null
	assignment = Jobs.open_assignment(uuid) if known else null
	if assignment:
		%Denied.hide()
		%Store.show()
		%Build.text = "Build 0.9.%d  ·  Session %s" % [assignment.number % 1000, assignment.uuid]
		_show_section("home")
		_refresh_cart()
		launch_requested.emit(DEBUG_APP)
	elif known:
		_show_denied("Session closed", "The report for this build has already been submitted. The test environment has been shut down.")
	elif not uuid.is_empty():
		_show_denied("Session not found", "Session “%s” does not exist or has expired. Check the link in your task letter." % uuid)

func _show_denied(title: String, text: String) -> void:
	%Store.hide()
	%Denied.show()
	%DeniedTitle.text = title
	%DeniedText.text = text
	%Build.text = "Build 0.9  ·  no active session"

func _bug(check: String) -> String:
	return assignment.bug(check) if assignment else ""

func _product_name(id: String) -> String:
	return grid.get_node(id).product_name

func _price(id: String) -> int:
	return grid.get_node(id).price

func _show_section(id: String) -> void:
	section = id
	for key in SECTIONS:
		%Sections.get_node(key).visible = key == id
		tabs.get_node(key).theme_type_variation = &"ShopTabActive" if key == id else &"ShopTab"

func _tab_pressed(id: String) -> void:
	match _bug("tab_" + id):
		"dead":
			return
		"wrong":
			_clear_error()
			_show_section(SECTIONS[(SECTIONS.find(id) + 1) % SECTIONS.size()])
		"crash":
			_crash("tab", id)
		_:
			_clear_error()
			_show_section(id)

func _add_pressed(id: String) -> void:
	match _bug("add_" + id):
		"dead":
			return
		"wrong":
			var products := grid.get_children()
			var other: Node = products[(products.find(grid.get_node(id)) + 1) % products.size()]
			_add(String(other.name), 1)
		"double":
			_add(id, 2)
		"crash":
			_crash("add")
		_:
			_add(id, 1)

func _add(id: String, count: int) -> void:
	cart[id] = cart.get(id, 0) + count
	_clear_error()
	_notice("Added %s to your cart." % _product_name(id))
	_refresh_cart()

func _clear_pressed() -> void:
	match _bug("clear_cart"):
		"dead":
			return
		"partial":
			if not cart.is_empty():
				var last: String = cart.keys()[-1]
				cart.clear()
				cart[last] = 1
			_clear_error()
			_notice("Your cart has been cleared.")
		"crash":
			_crash("clear")
			return
		_:
			_clear_error()
			_notice("Your cart has been cleared." if not cart.is_empty() else "Your cart is already empty.")
			cart.clear()
	_refresh_cart()

func _checkout_pressed() -> void:
	var bug := _bug("checkout")
	match bug:
		"dead":
			return
		"crash":
			_crash("checkout")
			return
	_clear_error()
	var total := _total()
	if bug == "wrong":
		total += assignment.overcharge
	elif cart.is_empty():
		_notice("Your cart is empty. Add something from the Catalog first.")
		return
	_orders += 1
	_notice("Thank you! Order TS-%04d has been placed. Amount charged: $%d." % [4800 + _orders, total])
	cart.clear()
	_refresh_cart()

func _total() -> int:
	var total := 0
	for id in cart:
		total += _price(id) * cart[id]
	return total

func _refresh_cart() -> void:
	var lines: VBoxContainer = %Lines
	for line in lines.get_children():
		lines.remove_child(line)
		line.queue_free()
	var items := 0
	for id in cart:
		var line: Control = cart_line_scene.instantiate()
		lines.add_child(line)
		line.get_node("Name").text = _product_name(id)
		line.get_node("Quantity").text = "× %d" % cart[id]
		line.get_node("Sum").text = "$%d" % (_price(id) * cart[id])
		items += cart[id]
	%CartEmpty.visible = cart.is_empty()
	%Total.text = "$%d" % _total()
	tabs.get_node("cart").text = "Cart (%d)" % items

func _notice(text: String) -> void:
	%Notice.text = text
	%Notice.show()

func _crash(kind: String, detail := "") -> void:
	var text: String = CRASHES[kind]
	%ErrorText.text = text % detail if text.contains("%s") else text
	%Error.show()
	%Notice.hide()

func _clear_error() -> void:
	%Error.hide()
