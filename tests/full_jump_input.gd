class_name FullJumpInput
extends RefCounted
## Replay the old full-height routes with held input after variable jump was added.

static var _generation := 0
static var _hold_until := -1


static func press(player: PlayerController) -> void:
	_generation += 1
	_hold_until = Engine.get_physics_frames() + ceili((player.dash_duration + player.jump_speed / player.gravity_acceleration + 0.05) * Engine.physics_ticks_per_second)
	Input.action_release("jump")
	Input.action_press("jump")


static func is_holding() -> bool:
	return Input.is_action_pressed("jump") and Engine.get_physics_frames() < _hold_until


static func release_after_apex(player: PlayerController) -> void:
	var generation := _generation
	var duration := player.dash_duration + maxf(player.jump_speed, player.wall_jump_up_speed) / player.gravity_acceleration + 0.05
	player.get_tree().create_timer(duration, false, true).timeout.connect(func():
		if generation == _generation:
			Input.action_release("jump")
	)


static func press_action(action: String, player: PlayerController) -> void:
	if action == "jump":
		press(player)
	else:
		Input.action_press(action)


static func release_action(action: String, player: PlayerController) -> void:
	if action == "jump":
		release_after_apex(player)
	else:
		Input.action_release(action)
