extends PanelContainer

## Shared Casino OC top bar: logo, section navigation and the live token balance with a deposit button.

@export_enum("lobby", "slots", "blackjack", "cashier") var section := "lobby"

var _shown := -1

func _ready() -> void:
	for button: Button in [%Lobby, %Slots, %Blackjack, %Cashier]:
		if button.get_meta("section", "") == section:
			button.theme_type_variation = &"CasinoNavActive"
	Wallet.tokens_changed.connect(_show_balance)
	_show_balance(Wallet.tokens)
	if Wallet.claim_welcome_bonus():
		_show_bonus()

func _show_balance(value: int) -> void:
	var label: Label = %Balance
	label.text = Wallet.group_digits(value)
	if _shown >= 0 and value != _shown:
		label.pivot_offset = label.size * 0.5
		var bump := create_tween()
		bump.tween_property(label, "scale", Vector2.ONE * 1.15, 0.08)
		bump.tween_property(label, "scale", Vector2.ONE, 0.18)
	_shown = value

## Pops the "welcome bonus" badge next to the balance, then fades it out.
func _show_bonus() -> void:
	var badge: Control = %Bonus
	badge.get_node("Text").text = "+%d welcome bonus!" % Wallet.WELCOME_BONUS
	badge.show()
	badge.modulate.a = 0.0
	var pop := create_tween()
	pop.tween_property(badge, "modulate:a", 1.0, 0.3)
	pop.tween_interval(4.0)
	pop.tween_property(badge, "modulate:a", 0.0, 0.6)
	pop.tween_callback(badge.hide)
