extends PanelContainer

## Shared Casino OC top bar: logo, section navigation and the live wallet balance.

@export_enum("lobby", "slots", "blackjack") var section := "lobby"

func _ready() -> void:
	for button: Button in [%Lobby, %Slots, %Blackjack]:
		if button.get_meta("section", "") == section:
			button.theme_type_variation = &"CasinoNavActive"
	Wallet.changed.connect(_show_balance)
	_show_balance(Wallet.balance)

func _show_balance(value: int) -> void:
	%Balance.text = "Balance: " + Wallet.format_money(value)
