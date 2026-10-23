extends SceneTree

var tutorial: Node
var player: PlayerController
var room: Node2D
var pad := false
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _new_world()
	for speed in [1.0, 0.85]:
		for launch in [280, 300, 320]:
			for first in [12, 16, 20, 24]:
				for second in [10, 14, 18, 22]:
					await _prepare(speed, launch)
					await _sequence(first, second)
					_check(await _first_landing_is_exit(), "The refill/dash flight first lands on the exit floor: speed=%s launch=%d waits=%d/%d" % [speed, launch, first, second])
	await _unfinished_retry()
	await _walk_ahead()
	for speed in [1.0, 0.85]:
		await _new_world()
		await _clear_course(speed)
	await _backtrack()
	_release()
	print("TUTORIAL_REFILL_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _sequence(first: int, second: int) -> void:
	await _pulse("jump")
	await _step(first)
	await _pulse("dash")
	await _step(second)
	_check(tutorial.seen.has("air_dash") and not player.is_on_floor(), "The first dash stays airborne until the refill/second input")
	_capture("refilled")
	await _pulse("dash")
	_check(tutorial.seen.has("dash_refill") and tutorial.seen.has("refilled_dash") and player.is_dashing() and not player.is_on_floor(), "The real crystal refills a spent dash before the second dash in the same flight")
	_capture("second-dash")


func _first_landing_is_exit() -> bool:
	for frame in 140:
		await _step()
		if player.is_on_floor():
			for index in player.get_slide_collision_count():
				var contact: KinematicCollision2D = player.get_slide_collision(index)
				if contact.get_collider() == room.get_node("Landing") and contact.get_normal().dot(Vector2.UP) > 0.8:
					_check(player.is_dash_ready(), "The physical exit landing restores dash")
					return true
			return false
	_check(false, "The flight did not land on a safe floor")
	return false


func _unfinished_retry() -> void:
	await _prepare(0.85, 280)
	await _pulse("jump")
	await _step(16)
	await _pulse("dash")
	await _step(10)
	_check(tutorial.seen.has("dash_refill") and not player.is_on_floor(), "The unfinished attempt collects the actual crystal in flight")
	_move(Vector2.ZERO)
	await _step(100)
	_check(player.is_on_floor() and not tutorial.seen.has("dash_refill") and not tutorial.seen.has("air_dash") and room.get_node("Goal").locked, "Stopping before the second dash lands safely and invalidates the unfinished chain")
	await _reset_key()
	await _step(5)
	_check(_local().distance_to(Vector2(72, 614)) < 2 and player.is_dash_ready() and tutorial.seen.is_empty(), "R restores the safe entrance and dash without retaining incomplete history")
	_check(room.get_node("DashCrystal").visible and room.get_node("DashCrystal").position == Vector2(510, 510), "R restores the crystal at the new position")


func _walk_ahead() -> void:
	await _enter()
	_move(Vector2.RIGHT)
	for frame in 450:
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release()
	_check(_local().x > 1100 and not tutorial.cleared.has(4) and room.get_node("Goal").locked, "Walking and ordinary jumps may explore near the goal; the existing refill lesson still locks it")
	_check(not tutorial.seen.has("air_dash") and not tutorial.seen.has("dash_refill"), "The alternate walk/jump approach does not fake a refill experience")


func _clear_course(speed: float) -> void:
	_capture("entrance")
	await _prepare(speed, 280)
	await _sequence(16, 10)
	_check(await _first_landing_is_exit(), "The standard keyboard/raw0.85 sequence reaches the exit on its first landing")
	_capture("landing")
	for frame in 240:
		if tutorial.cleared.has(4):
			break
		_move(Vector2.ZERO if _local().x >= room.get_node("Goal").position.x - 55 else Vector2(speed, 0))
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release()
	_check(tutorial.cleared.has(4) and room.get_node("Goal").is_pressed() and player.is_on_floor(), "The real arrival switch opens after the airborne refill and second dash")
	_capture("cleared")
	_move(Vector2(speed, 0))
	for frame in 180:
		if tutorial.room_index == 5 and not tutorial.transitioning:
			break
		_move(Vector2(speed, 0))
		await _step()
	_release()
	_check(tutorial.room_index == 5 and player.controls_enabled, "Right input enters Room6 after the real goal")


func _backtrack() -> void:
	_move(Vector2.LEFT)
	for frame in 180:
		if tutorial.room_index == 4 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(12)
	_check(tutorial.room_index == 4 and player.is_on_floor() and _local().distance_to(room.get_node("Return").position) < 6, "Returning from Room6 lands on the existing safe checkpoint")
	await _reset_key()
	await _step(6)
	_check(tutorial.cleared.has(4) and _local().distance_to(room.get_node("Return").position) < 6, "R after backtracking preserves the cleared lesson and return checkpoint")
	_move(Vector2.LEFT)
	for frame in 420:
		if tutorial.room_index == 3:
			_release()
			if not tutorial.transitioning and player.is_on_floor():
				break
			await _step()
			continue
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release()
	await _step(10)
	_check(tutorial.room_index == 3 and player.controls_enabled and player.is_on_floor(), "The recovery floor and a normal jump lead left back into Room4")


func _new_world() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	room = tutorial.get_node("Rooms/Room5")
	# A normal Room5 visit has already opened the preceding room's exit.
	tutorial.cleared[3] = true
	tutorial.call("_set_room", 3, false)
	player.respawn()
	await _step()
	await _enter()


func _enter() -> void:
	_release()
	pad = false
	tutorial.call("_set_room", 4, false)
	player.respawn()
	await _step(6)


func _prepare(speed: float, launch: int) -> void:
	await _enter()
	pad = speed < 1
	_move(Vector2(speed, 0))
	for frame in 240:
		if _local().x >= launch:
			break
		await _step()
	_check(player.is_on_floor() and player.is_dash_ready() and _local().x >= launch, "The launch begins with a ready dash on the entrance floor")
	if pad:
		_check(is_equal_approx(Input.get_axis("move_left", "move_right"), 0.7), "Raw joystick x0.85 passes through the configured deadzone as x0.7")


func _local() -> Vector2:
	return player.position - room.position


func _move(direction: Vector2) -> void:
	if pad:
		_joy(JOY_AXIS_LEFT_X, direction.x)
		_joy(JOY_AXIS_LEFT_Y, direction.y)
		return
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")


func _joy(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _reset_key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	event.pressed = true
	Input.parse_input_event(event)
	await _step()
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "wall_grab", "jump", "dash", "reset"]:
		Input.action_release(action)
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_TRIGGER_LEFT]:
		_joy(axis, 0)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/tutorial-refill-%s.png" % name)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_REFILL_ROUTE: %s (position=%s velocity=%s seen=%s)" % [message, _local(), player.velocity, tutorial.seen.keys()])
