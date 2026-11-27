class_name JobListing
extends Resource

## One vacancy on the stupidjob.oc job board (`data/jobs/*.tres`).
## `id` links the listing to its hiring flow in the `Jobs` autoload.

@export var id := ""
@export var title := ""
@export var company := ""
## Two letters shown in the company logo badge.
@export var initials := ""
@export var logo_color := Color("#1f6feb")
@export var location := "Remote"
@export var pay := ""
@export var tags: PackedStringArray = []
@export_multiline var summary := ""
@export var posted := ""
