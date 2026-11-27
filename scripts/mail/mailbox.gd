extends Node

## Player's incoming mail, registered as the `Mailbox` autoload.
## Letters sent by game events live here, so they arrive even while the Mail app is closed.
## Saved per user by the `SaveGame` autoload, together with which story letters were already sent.

signal delivered(message: MailMessage)
## Any change worth saving: a new letter or a letter read or unread.
signal changed

const FIELDS: PackedStringArray = ["folder", "sender_name", "sender_address", "subject", "received", "body", "read"]

## Newest first.
var inbox: Array[MailMessage] = []
## Story letters already sent to this user (resource path -> true), so each arrives only once.
var sent_once: Dictionary[String, bool] = {}

func reset_state() -> void:
	inbox.clear()
	sent_once.clear()

func save_state() -> Dictionary:
	var letters: Array[Dictionary] = []
	for message in inbox:
		var entry := {}
		for field in FIELDS:
			entry[field] = message.get(field)
		letters.append(entry)
	return {"inbox": letters, "sent_once": sent_once.duplicate()}

func load_state(data: Dictionary) -> void:
	for entry in data.get("inbox", []):
		if entry is Dictionary:
			var message := MailMessage.new()
			for field in FIELDS:
				if entry.has(field):
					message.set(field, entry[field])
			inbox.append(message)
	var sent: Variant = data.get("sent_once", {})
	if sent is Dictionary:
		for key in sent:
			sent_once[str(key)] = true

func set_read(message: MailMessage, value: bool) -> void:
	message.read = value
	changed.emit()

func was_sent(letter: MailMessage) -> bool:
	return sent_once.has(letter.resource_path)

## Delivers a copy of a letter stored in `data/mail/`, unless this user already received it.
func deliver_once(letter: MailMessage) -> bool:
	if was_sent(letter):
		return false
	sent_once[letter.resource_path] = true
	var copy: MailMessage = letter.duplicate()
	copy.received = ""
	deliver(copy)
	return true

func deliver(message: MailMessage) -> void:
	if message.received.is_empty():
		message.received = GameClock.time_text()
	inbox.push_front(message)
	delivered.emit(message)
	changed.emit()
