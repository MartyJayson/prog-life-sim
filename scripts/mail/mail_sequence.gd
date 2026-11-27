extends Node

## Story letters that arrive one after another once the desktop opens. Each delivery shows a
## desktop notification (see desktop.gd). Every letter reaches a user only once, so after a
## reload the sequence continues from the first letter that has not been sent yet.

@export var letters: Array[MailMessage] = []
## Seconds before the first letter is sent.
@export var first_delay := 3.0
## Seconds between the following letters.
@export var interval := 8.0

func _ready() -> void:
	_schedule(first_delay)

func _schedule(delay: float) -> void:
	if _next_letter() == null:
		return
	get_tree().create_timer(delay).timeout.connect(_send_next)

func _send_next() -> void:
	var letter := _next_letter()
	if letter == null:
		return
	Mailbox.deliver_once(letter)
	_schedule(interval)

func _next_letter() -> MailMessage:
	for letter in letters:
		if not Mailbox.was_sent(letter):
			return letter
	return null
