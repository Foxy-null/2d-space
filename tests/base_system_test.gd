extends SceneTree

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert_input_map()

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player := main.get_node("Player") as PlayerController
	_check(player != null, "Player scene is missing")

	await _wait_for_floor(player)
	_check(player.is_on_floor(), "Player did not land")

	var start_x := player.global_position.x
	Input.action_press("move_right")
	for _frame in 10:
		await physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x > start_x, "Move action did not move the player")

	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame
	_check(player.velocity.y < 0.0, "Jump action did not launch the player")

	main.get_node("GateUp").emit_signal("body_entered", player)
	_check(player.gravity_direction == -1 and player.up_direction == Vector2.DOWN, "Up gate did not invert gravity")
	main.get_node("GateDown").emit_signal("body_entered", player)
	_check(player.gravity_direction == 1 and player.up_direction == Vector2.UP, "Down gate did not restore gravity")

	await _assert_wall_actions(player)

	if _failed:
		quit(1)
		return
	print("BASE_SYSTEM_TEST_OK")
	quit()


func _assert_input_map() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"wall_grab", &"reset"]:
		_check(InputMap.has_action(action), "Missing input action: %s" % action)
	_check(_has_key(&"move_up", KEY_W) and _has_key(&"move_up", KEY_UP), "Keyboard climb/jump-up keys are not mapped")
	_check(_has_key(&"wall_grab", KEY_SHIFT), "Shift wall grab is not mapped")
	_check(_has_joy_button(&"jump", JOY_BUTTON_A), "Gamepad jump is not mapped")
	_check(_has_joy_button(&"reset", JOY_BUTTON_START), "Gamepad reset is not mapped")
	_check(_has_joy_button(&"move_left", JOY_BUTTON_DPAD_LEFT), "Gamepad D-pad movement is not mapped")
	_check(_has_joy_motion(&"move_left", JOY_AXIS_LEFT_X, -1.0), "Gamepad stick movement is not mapped")
	_check(_has_joy_motion(&"wall_grab", JOY_AXIS_TRIGGER_RIGHT, 1.0), "ZR wall grab is not mapped")


func _assert_wall_actions(player: PlayerController) -> void:
	player.respawn()
	player.global_position = Vector2(850.0, 540.0)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	for _frame in 20:
		await physics_frame
		if player.is_wall_grabbing():
			break
	Input.action_release("move_right")
	_check(player.is_wall_grabbing(), "Player could not grab the wall")

	var climb_start_y := player.global_position.y
	Input.action_press("move_up")
	for _frame in 25:
		await physics_frame
	_check(player.global_position.y < climb_start_y, "Wall climb did not move upward")

	player.set("_jump_buffer_left", player.jump_buffer_time)
	await physics_frame
	Input.action_release("move_up")
	Input.action_release("wall_grab")
	_check(absf(player.velocity.x) >= player.wall_jump_speed - 1.0, "Wall jump did not push away from the wall")

	player.respawn()
	player.global_position = Vector2(930.0, 500.0)
	player.velocity = Vector2.ZERO
	Input.action_press("move_left")
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	var mantled := false
	for _frame in 120:
		await physics_frame
		if player.global_position.x < 900.0:
			mantled = true
			break
	Input.action_release("move_left")
	Input.action_release("move_up")
	Input.action_release("wall_grab")
	_check(mantled, "Player did not mantle over the wall edge: pos=%s wall=%s grab=%s" % [player.global_position, player.is_on_wall(), player.is_wall_grabbing()])


func _wait_for_floor(player: PlayerController) -> void:
	for _frame in 120:
		if player.is_on_floor():
			return
		await physics_frame


func _has_joy_button(action: StringName, button_index: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button_index:
			return true
	return false


func _has_key(action: StringName, physical_keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == physical_keycode:
			return true
	return false


func _has_joy_motion(action: StringName, axis: int, axis_value: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, axis_value):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("BASE_SYSTEM_TEST_FAILED: %s" % message)
