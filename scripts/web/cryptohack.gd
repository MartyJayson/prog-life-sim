extends VBoxContainer

## cryptohack.oc — "cracks" a SkamCoin wallet hash found on a used flash drive. After a short
## hacking show the wallet's dollars move into the SkamCoin account (see Drives.redeem).

const ALERT := "#ff4d4d"
const GOOD := "#39ff7a"
const DIM := "#1f8c45"

## Real seconds the hacking show takes; tests set it to 0.
static var crack_time := 3.2

var cracking := false
var _rng := RandomNumberGenerator.new()

@onready var hash_field: LineEdit = %Hash
@onready var log_text: RichTextLabel = %Text
@onready var result: Label = %Result
@onready var progress: ProgressBar = %Progress

func _ready() -> void:
	_rng.randomize()

func paste() -> void:
	hash_field.text = DisplayServer.clipboard_get().strip_edges()

func crack() -> void:
	if cracking:
		return
	var hash := hash_field.text.strip_edges().to_lower()
	result.text = ""
	log_text.clear()
	_line("$ cryptohack --wallet %s" % (hash.left(16) + "…" if hash.length() > 16 else hash), DIM)
	if not Drives.is_hash_format(hash):
		_line("error: a wallet hash is 64 characters of 0-9 and a-f", ALERT)
		_show_result("INVALID HASH", ALERT)
		return
	cracking = true
	%Crack.disabled = true
	var steps := [
		"connecting to SKAM node %d.%d.%d.%d ..." % [_rng.randi_range(10, 220), _rng.randi_range(0, 255), _rng.randi_range(0, 255), _rng.randi_range(1, 254)],
		"handshake ok, tunnelling through 3 proxies",
		"deriving private key from recovery hash",
		"bruteforcing checksum  [%s]" % "#".repeat(_rng.randi_range(18, 26)),
		"locating wallet on the chain ...",
	]
	progress.value = 0.0
	progress.show()
	for i in steps.size():
		_line(steps[i])
		if crack_time > 0.0:
			var tween := create_tween()
			tween.tween_property(progress, "value", float(i + 1) / steps.size(), crack_time / steps.size())
			await tween.finished
	_finish(hash)

func _finish(hash: String) -> void:
	cracking = false
	%Crack.disabled = false
	progress.hide()
	var status: int = Drives.check(hash)
	if status == Drives.Redeem.UNKNOWN:
		_line("no wallet with this hash on the network", ALERT)
		_show_result("WALLET NOT FOUND", ALERT)
	elif status == Drives.Redeem.EMPTY:
		_line("wallet found: balance 0.0000 SKAM. someone got here first.", ALERT)
		_show_result("WALLET IS EMPTY", ALERT)
	elif status == Drives.Redeem.USED:
		_line("wallet found: already drained by you", ALERT)
		_show_result("ALREADY DRAINED", ALERT)
	else:
		var usd := Drives.redeem(hash)
		var coins := usd / SkamMarket.price
		_line("wallet unlocked. balance %s" % Wallet.format_money(usd), GOOD)
		_line("moving %s SKAM to your skamcoin.oc account ... done" % SkamMarket.format_coins(coins), GOOD)
		_show_result("+%s SKAM  (%s) sent to your SkamCoin account" % [SkamMarket.format_coins(coins), Wallet.format_money(usd)], GOOD)

func _line(text: String, color := "") -> void:
	if color.is_empty():
		log_text.append_text(text.replace("[", "[lb]") + "\n")
	else:
		log_text.append_text("[color=%s]%s[/color]\n" % [color, text.replace("[", "[lb]")])

func _show_result(text: String, color: String) -> void:
	result.text = text
	result.add_theme_color_override("font_color", Color(color))
