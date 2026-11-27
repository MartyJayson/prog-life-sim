extends VBoxContainer

@onready var balance_label: Label = %Balance
@onready var pending: HBoxContainer = %Pending
@onready var empty_label: Label = %Empty
@onready var payment_error: Label = %PaymentError

func _ready() -> void:
	%Date.text = GameClock.date_text()
	%RentAmount.text = Wallet.format_money(Wallet.RENT_AMOUNT)
	Wallet.changed.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	balance_label.text = Wallet.format_money(Wallet.balance)
	pending.visible = not Wallet.rent_paid
	empty_label.visible = Wallet.rent_paid
	if Wallet.rent_paid or Wallet.can_afford(Wallet.RENT_AMOUNT):
		payment_error.hide()

func _pay_rent() -> void:
	if not Wallet.pay_rent() and not Wallet.rent_paid:
		payment_error.show()
