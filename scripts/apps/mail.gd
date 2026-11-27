extends VBoxContainer

## Outlook-style mail client: folders, a message list and a reading pane.
## Links in a letter emit `site_requested`, which the desktop opens in the Browser.

signal site_requested(address: String)

const ROW = preload("res://scenes/mail/mail_row.tscn")
const LINK_COLOR := "#1c6bcc"
## An existing [url] tag, or a bare address to link: http(s)://… or something.oc[/path].
const LINK_PATTERN := "(?i)\\[url(=[^\\]]*)?\\].*?\\[/url\\]|https?://[^\\s\\[\\]<>]+|(?<![@\\w.-])(?:[a-z0-9-]+\\.)+oc\\b(?:/[^\\s\\[\\]<>]*)?"
const TRAILING_PUNCTUATION := ".,;:!?)"

@export var account := ""
@export var row_group: ButtonGroup

## Letters shown by the app, newest first; the same objects as `Mailbox.inbox`.
var messages: Array[MailMessage] = []
var folder := MailMessage.Folder.INBOX
var selected: MailMessage
var query := ""
var _links := RegEx.create_from_string(LINK_PATTERN)

@onready var rows: VBoxContainer = %Rows
@onready var body: RichTextLabel = %Body
@onready var toggle_read: Button = %ToggleRead

func _ready() -> void:
	# Shared with the Mailbox, so the read state survives closing the app.
	messages.assign(Mailbox.inbox)
	Mailbox.delivered.connect(receive)
	%Account.text = account
	_refresh_list()
	_show_letter()

## Adds a letter to the mailbox, e.g. from a game event.
func receive(message: MailMessage) -> void:
	messages.push_front(message)
	_refresh_list()

## Shows [param message] in the Inbox, e.g. when its desktop notification is clicked.
func open_message(message: MailMessage) -> void:
	if not messages.has(message):
		return
	if folder != message.folder:
		_open_folder(message.folder)
	_select(message)
	_refresh_list()

func unread_count() -> int:
	return messages.filter(func(m: MailMessage): return m.folder == MailMessage.Folder.INBOX and not m.read).size()

## Converts a BBCode body so every address in it is a clickable, coloured link.
func linkify(text: String) -> String:
	var result := ""
	var last := 0
	for found: RegExMatch in _links.search_all(text):
		result += text.substr(last, found.get_start() - last)
		var link := found.get_string()
		var trail := ""
		if not link.begins_with("["):
			while not link.is_empty() and TRAILING_PUNCTUATION.contains(link[-1]):
				trail = link[-1] + trail
				link = link.left(-1)
			link = "[url=%s]%s[/url]" % [link, link]
		result += "[color=%s]%s[/color]%s" % [LINK_COLOR, link, trail]
		last = found.get_end()
	return result + text.substr(last)

func _visible_messages() -> Array[MailMessage]:
	var shown: Array[MailMessage] = []
	for message in messages:
		if message.folder != folder:
			continue
		var haystack := " ".join([message.sender_name, message.sender_address, message.subject, message.body])
		if query.is_empty() or haystack.containsn(query):
			shown.append(message)
	return shown

func _refresh_list() -> void:
	for row in rows.get_children():
		if row != %Empty:
			rows.remove_child(row)
			row.queue_free()
	var shown := _visible_messages()
	for message in shown:
		var row: Button = ROW.instantiate()
		row.button_group = row_group
		rows.add_child(row)
		row.show_message(message)
		row.set_pressed_no_signal(message == selected)
		row.pressed.connect(_select.bind(message))
	%Empty.visible = shown.is_empty()
	%Empty.text = "Nothing in this folder." if query.is_empty() else "No letters match “%s”." % query
	_update_counts()

func _update_counts() -> void:
	var inbox: Button = $Panes/Folders/List/Inbox
	var unread := unread_count()
	inbox.text = inbox.get_meta("caption") + ("   %d" % unread if unread > 0 else "")

func _refresh_rows() -> void:
	for row in rows.get_children():
		if row != %Empty:
			row.refresh()
	_update_counts()

func _select(message: MailMessage) -> void:
	selected = message
	if not message.read:
		Mailbox.set_read(message, true)
	_refresh_rows()
	_show_letter()

func _show_letter() -> void:
	%Placeholder.visible = selected == null
	%Letter.visible = selected != null
	toggle_read.disabled = selected == null
	if selected == null:
		return
	toggle_read.text = "Mark as read" if not selected.read else "Mark as unread"
	%Subject.text = selected.subject
	%From.text = selected.sender_name
	%Address.text = selected.sender_address
	%Received.text = selected.received
	%Initials.text = _initials(selected.sender_name)
	body.text = linkify(selected.body)
	body.scroll_to_line(0)

func _initials(caption: String) -> String:
	var letters := ""
	for word in caption.split(" ", false):
		letters += word[0].to_upper()
		if letters.length() == 2:
			break
	return letters

func _open_folder(value: int) -> void:
	folder = value as MailMessage.Folder
	for button in $Panes/Folders/List.get_children():
		if button.get_meta("folder", -1) == value:
			%FolderName.text = button.get_meta("caption")
	if selected and selected.folder != folder:
		selected = null
		_show_letter()
	_refresh_list()

func _search_changed(text: String) -> void:
	query = text.strip_edges()
	_refresh_list()

func _toggle_read() -> void:
	if selected:
		Mailbox.set_read(selected, not selected.read)
		toggle_read.text = "Mark as read" if not selected.read else "Mark as unread"
		_refresh_rows()

func _link_clicked(meta: Variant) -> void:
	site_requested.emit(str(meta))

func _link_hovered(_meta: Variant, hovering: bool) -> void:
	body.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovering else Control.CURSOR_ARROW
