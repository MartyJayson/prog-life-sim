extends Resource

@export var seed_value: int = 0
@export var round_seconds: float = 75.0
@export var ally_accuracy := Vector2(0.65, 0.80)
@export var enemy_accuracy := Vector2(0.35, 0.55)
@export var ally_reaction := Vector2(0.1, 0.7)
@export var enemy_reaction := Vector2(0.2, 0.8)
@export var health: int = 100
@export var damage: int = 24
@export var shot_interval: float = 0.55
@export var vision_range: float = 205.0
@export var vision_half_angle: float = 52.0
@export var terminal_duration: float = 25.0
@export var scan_interval := Vector2(2.0, 3.0)
@export var turret_duration: float = 20.0
@export var hack_seconds: float = 10.0
@export var memory_seconds: float = 5.0
