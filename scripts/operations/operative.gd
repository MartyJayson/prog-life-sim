extends CharacterBody2D

const SPEED := 65.0

var callsign: String
var identity_color := Color.WHITE
var team: int
var health: int
var accuracy: float
var facing := Vector2.RIGHT
var action := "Moving"
var route: PackedVector2Array
var waypoint := 0
var partner: CharacterBody2D
var target: CharacterBody2D
var last_seen := Vector2.INF
var reaction_until := 0.0
var next_shot := 0.0
var next_path := 0.0
var next_sweep := 0.0
var sweep_offset := 0.0
var search_until := 0.0
var assistance_position := Vector2.INF
var assistance_until := 0.0
var assistance_source := ""
var hold_aim := Vector2.ZERO
var assignment := ""
var independent_bomber := false

func update_ai(mission, elapsed: float) -> void:
	$Agent.velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	if health <= 0:
		return
	var enemy: CharacterBody2D = mission.find_target(self)
	if enemy:
		if enemy != target:
			target = enemy
			reaction_until = elapsed + mission.reaction(team)
		last_seen = enemy.position
		mission.report_contact(self, enemy.position)
		search_until = elapsed + 4.0
		facing = position.direction_to(enemy.position)
		action = "Contact"
		if elapsed >= reaction_until and elapsed >= next_shot:
			next_shot = elapsed + mission.settings.shot_interval
			mission.fire(self, enemy)
		return
	target = null
	if elapsed >= search_until:
		last_seen = Vector2.INF
	var destination := route[waypoint]
	action = "Moving"
	if last_seen != Vector2.INF:
		destination = last_seen
		action = "Searching"
	if elapsed < assistance_until and not mission.objective_urgent(self):
		destination = assistance_position
		action = "Assisting " + assistance_source
	var bomb_destination: Vector2 = mission.bomb_task_position(self)
	if bomb_destination != Vector2.INF:
		destination = bomb_destination
	if position.distance_to(destination) < 6.0:
		if action == "Guarding the bomb":
			var point: Vector2 = mission.bomb_guards[get_instance_id()]
			facing = position.direction_to(point).rotated(sin(elapsed * 1.5) * 0.45)
			return
		if action.begins_with("Assisting"):
			assistance_until = 0.0
			facing = position.direction_to(assistance_position)
			return
		if last_seen != Vector2.INF:
			last_seen = Vector2.INF
		elif action == "Moving":
			waypoint = mini(waypoint + 1, route.size() - 1)
		facing = position.direction_to(hold_aim).rotated(sin(elapsed * 0.7) * 0.12)
		action = "Holding " + assignment
		return
	if elapsed >= next_path:
		$Agent.target_position = mission.to_global(destination)
		next_path = elapsed + 0.28
	if NavigationServer2D.map_get_iteration_id($Agent.get_navigation_map()) == 0:
		return
	if $Agent.is_navigation_finished():
		if action == "Searching":
			last_seen = Vector2.INF
		return
	var direction := global_position.direction_to($Agent.get_next_path_position())
	if direction != Vector2.ZERO:
		facing = direction
	$Agent.velocity = direction * SPEED

func _on_safe_velocity(safe_velocity: Vector2) -> void:
	if health <= 0 or not get_parent().running:
		return
	velocity = safe_velocity
	move_and_slide()

func take_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	if health == 0:
		action = "Eliminated"
		target = null
		$Agent.avoidance_enabled = false
		$Shape.set_deferred("disabled", true)
