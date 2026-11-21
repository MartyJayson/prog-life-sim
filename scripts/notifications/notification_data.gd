class_name NotificationData
extends Resource

## Describes one desktop notification and what happens when the player clicks it.
## Add new kinds of reactions by extending `Action` and handling them in desktop.gd.

enum Action { NONE, APP, SITE }

@export var title := "Notification"
@export_multiline var message := ""
@export var icon: Texture2D
## Accent used for the stripe beside the message.
@export var accent := Color("#ff9d2e")
## What clicking the notification opens.
@export var action := Action.NONE
## App id for `APP` (e.g. "calculator"), address for `SITE` (e.g. "bank.oc/payments").
@export var target := ""
## Seconds after start-up, used when the notification is scheduled by NotificationCenter.
@export var delay := 0.0
