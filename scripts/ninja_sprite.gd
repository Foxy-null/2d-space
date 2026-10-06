extends AnimatedSprite2D

const BASE_SCALE := 52.0 / 661.0
var _was_grounded := false
var _was_ceiling := false
var _landing_left := 0.0
var _bonk_left := 0.0
var _release_left := 0.0
var _was_thrown := false
@onready var player: PlayerController = owner


func _ready() -> void:
	player.object_released.connect(_on_release)
	player.respawned.connect(_reset_pose)
	play("idle")


func _process(delta: float) -> void:
	_landing_left = maxf(0.0, _landing_left - delta)
	_bonk_left = maxf(0.0, _bonk_left - delta)
	_release_left = maxf(0.0, _release_left - delta)
	var grounded := player.is_on_floor()
	var ceiling := player.is_on_ceiling()
	if grounded and not _was_grounded:
		_landing_left = 0.12
	if ceiling and not _was_ceiling and not grounded:
		_bonk_left = 0.16
	_was_grounded = grounded
	_was_ceiling = ceiling
	var facing := player.facing_direction
	if absf(player.velocity.x) > player.move_speed:
		facing = int(signf(player.velocity.x))
	if player.is_wall_grabbing() and absf(player.get_wall_normal().x) > 0.5:
		facing = -int(signf(player.get_wall_normal().x))
	var local_facing := facing * player.gravity_direction
	flip_h = local_facing < 0
	rotation = 0.0
	speed_scale = 1.0
	var held := player.get_held_object() != null
	var moving := absf(Input.get_axis("move_left", "move_right")) > 0.1 and absf(player.velocity.x) > 15.0
	var next: StringName = &"idle"
	if not player.controls_enabled:
		next = &"carry_idle" if held else &"idle"
	elif player.is_dashing():
		next = &"carry_idle" if held else &"jump"
		rotation = local_facing * 0.3 if absf(player.velocity.x) > 1.0 else 0.0
	elif held:
		next = &"carry_walk" if grounded and moving else &"carry_idle"
	elif player.is_wall_grabbing():
		next = &"wall_climb" if absf(player.velocity.y) > 10.0 else &"wall_grab"
		speed_scale = clampf(absf(player.velocity.y) / player.wall_climb_speed, 0.4, 1.0)
	elif _bonk_left > 0.0:
		next = &"bonk"
	elif _release_left > 0.0:
		next = &"jump" if _was_thrown else &"idle"
	elif not grounded:
		var falling := player.velocity.y * player.gravity_direction > 45.0
		var sliding := player.wall_actions_enabled and player.is_on_wall() and Input.get_axis("move_left", "move_right") * player.get_wall_normal().x < -0.1
		next = &"jump" if not falling or sliding else &"fall"
	elif moving:
		next = &"walk"
	if next in [&"walk", &"carry_walk"]:
		speed_scale = clampf(absf(player.velocity.x) / player.move_speed, 0.25, 1.5)
	if animation != next:
		play(next)
	var squash := sin((1.0 - _landing_left / 0.12) * PI) * 0.1 if grounded and _landing_left > 0.0 else 0.0
	scale = Vector2(1.0 + squash, 1.0 - squash) * BASE_SCALE
	position.y = 26.0 * squash
	if next in [&"walk", &"carry_walk"]:
		position.y -= sin(frame_progress * PI) * 0.7
	position.x = local_facing * 4.0 if next in [&"wall_grab", &"wall_climb"] else 0.0


func _on_release(_object: Grabbable, was_thrown: bool) -> void:
	_release_left = 0.12 if was_thrown else 0.06
	_was_thrown = was_thrown


func _reset_pose() -> void:
	_was_grounded = false
	_was_ceiling = false
	_landing_left = 0.0
	_bonk_left = 0.0
	_release_left = 0.0
	rotation = 0.0
	scale = Vector2.ONE * BASE_SCALE
	position = Vector2.ZERO
	play("idle")
