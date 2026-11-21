extends VBoxContainer

## bank.oc — OS Bank internet banking: shows the shared Wallet balance and recent operations.

const ROW = preload("res://scenes/web/bank_row.tscn")
const HISTORY_ROWS := 8
const INCOME := Color("#11884b")
const EXPENSE := Color("#c62f3c")

@onready var balance_label: Label = %Balance
@onready var updated_label: Label = %Updated
@onready var rows: VBoxContainer = %Rows
@onready var empty_label: Label = %Empty

func _ready() -> void:
	Wallet.changed.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	balance_label.text = Wallet.format_money(Wallet.balance)
	var time := Time.get_time_dict_from_system()
	updated_label.text = "Updated today at %02d:%02d" % [time.hour, time.minute]
	for row in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	for entry: Dictionary in Wallet.history.slice(0, HISTORY_ROWS):
		var amount: int = entry.get("amount", 0)
		var color := INCOME if amount > 0 else EXPENSE
		var row: Control = ROW.instantiate()
		rows.add_child(row)
		row.get_node("Row/Badge/Sign").text = "+" if amount > 0 else "−"
		row.get_node("Row/Badge/Sign").add_theme_color_override("font_color", color)
		row.get_node("Row/Text/Title").text = entry.get("title", "Transaction")
		row.get_node("Row/Text/Time").text = entry.get("time", "")
		var amount_label: Label = row.get_node("Row/Amount")
		amount_label.text = ("+ " if amount > 0 else "") + Wallet.format_money(amount)
		amount_label.add_theme_color_override("font_color", color)
	empty_label.visible = rows.get_child_count() == 0
