extends RefCounted

const DEFENSE := [[2,1,2], [1,1,3], [3,1,1], [0,1,4], [4,1,0], [3,0,2], [2,0,3], [0,0,5], [5,0,0], [0,5,0]]
const WEIGHTS := [30,18,14,10,8,7,5,4,3,1]
const ATTACK := ["Together", "Split", "Fake attack"]

static func assign(mission) -> void:
	var roll: int = mission.rng.randi_range(0, 99)
	var chosen := 0
	for index in range(WEIGHTS.size()):
		roll -= WEIGHTS[index]
		if roll < 0:
			chosen = index
			break
	var distribution: Array = DEFENSE[chosen]
	mission.defense_plan = "%d–%d–%d" % distribution
	var groups := ["B", "Mid", "A"]
	var defender := 0
	for group in range(3):
		var slots: Node = mission.layout.get_node("Tactics/" + groups[group])
		for index in range(distribution[group]):
			var unit = mission.units[defender]
			var slot: Marker2D = slots.get_child(index)
			unit.route = PackedVector2Array([slot.position])
			unit.hold_aim = slot.get_meta("aim")
			unit.assignment = groups[group]
			if chosen == 9:
				unit.route.append(Vector2(310, 400))
			defender += 1
	var strategy: int = mission.rng.randi_range(0, 2)
	var lane: int = mission.rng.randi_range(0, 2)
	mission.attack_plan = ATTACK[strategy]
	for index in range(5):
		var unit = mission.units[index + 5]
		unit.independent_bomber = false
		unit.waypoint = 0
		var assigned_lane := lane
		if strategy == 1:
			assigned_lane = (lane + index) % 3
		elif strategy == 2 and unit == mission.bomb_carrier:
			assigned_lane = 1 if lane == 0 else 0
			unit.independent_bomber = true
		unit.route = mission.layout.route_points(1, assigned_lane)
		unit.assignment = "B" if assigned_lane == 0 else "A"
		unit.hold_aim = Vector2(170, 160) if assigned_lane == 0 else Vector2(470, 120)
