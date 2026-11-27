class_name MailMessage
extends Resource

## One letter in the Mail app.
##
## `body` is BBCode. Links open in the browser: write them as `[url=bank.oc]OS Bank[/url]`,
## or just type an address — `https://…`, `http://…` and `*.oc` addresses are linked automatically.

enum Folder { INBOX, SENT, DRAFTS, DELETED }

@export var folder := Folder.INBOX
@export var sender_name := ""
@export var sender_address := ""
@export var subject := ""
## Shown as-is in the message list and the reading pane, e.g. "09:00" or "01.09.2028".
@export var received := ""
@export_multiline var body := ""
@export var read := false
