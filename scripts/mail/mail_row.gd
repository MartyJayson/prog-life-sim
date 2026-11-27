extends Button

## One entry in the Mail message list.

var message: MailMessage

func show_message(value: MailMessage) -> void:
	message = value
	%Sender.text = message.sender_name
	%Date.text = message.received
	%Subject.text = message.subject
	%Preview.text = preview_text(message.body)
	refresh()

## Redraws the read/unread state.
func refresh() -> void:
	%Unread.self_modulate.a = 0.0 if message.read else 1.0
	%Sender.theme_type_variation = &"" if message.read else &"MailStrong"
	%Subject.theme_type_variation = &"" if message.read else &"MailAccent"

## Flattens a BBCode body into a single line for the list.
static func preview_text(body: String) -> String:
	var plain := RegEx.create_from_string("\\[[^\\]]*\\]").sub(body, "", true)
	return RegEx.create_from_string("\\s+").sub(plain, " ", true).strip_edges()
