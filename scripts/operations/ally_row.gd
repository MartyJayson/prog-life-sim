extends VBoxContainer

var unit: CharacterBody2D
var displayed_health := -1

func bind(operative: CharacterBody2D, settings: Resource) -> void:
	unit = operative
	displayed_health = -1
	$Heading/Marker.color = unit.identity_color
	$Heading/Callsign.text = unit.callsign
	$Health.max_value = settings.health
	$Health.modulate = unit.identity_color
	var reaction: Vector2 = settings.ally_reaction if unit.team == 0 else settings.enemy_reaction
	$Stats.text = ("Accuracy %d%% · Damage %d\nReaction %.2f–%.2f s\nShot interval %.2f s" % [roundi(unit.accuracy * 100.0), settings.damage, reaction.x, reaction.y, settings.shot_interval])
	refresh()

func refresh() -> void:
	if not is_instance_valid(unit):
		return
	if displayed_health == unit.health:
		return
	displayed_health = unit.health
	$Heading/HP.text = "%d HP" % unit.health
	$Health.value = unit.health
	$State.visible = unit.health <= 0
	modulate.a = 0.45 if unit.health <= 0 else 1.0
