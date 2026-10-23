extends SceneTree

var tutorial: Node
var player: PlayerController
var room: Node2D
var pad := false
var failed := false
var checks := 0
var respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _new_world()
	_check(tutorial.STEPS[4].is_empty() and not room.get_node("Goal").locked, "The arrival switch has no action-history lock")
	_check(not room.has_node("JumpHint") and not room.has_node("RefillHint") and not room.has_node("RecoveryHint"), "The gap, crystal and landing replace the old explanatory labels")
	_check(not room.get_node("ReturnBridge").visible and room.get_node("ReturnBridge/Collision").disabled, "The return bridge cannot refill dash before actual arrival")
	for speed in [1.0, 0.85]:
		for launch in ([210, 230] if speed == 1.0 else [230, 240]):
			for first in ([12, 16, 20, 24, 28, 32, 36] if speed == 1.0 else [28, 32, 36]):
				for second in ([0, 4, 8] if speed == 1.0 else [8, 12, 16]):
					await _prepare(speed, launch)
					await _sequence(first, second)
					_check(await _lands_on_exit(), "The refill flight first lands on the exit: speed=%s launch=%d waits=%d/%d" % [speed, launch, first, second])
					_check(player.is_dash_ready() and not tutorial.cleared.has(4), "The broad landing restores dash before arrival opens the exit")
	await _single_dash_attempts()
	await _without_crystal_attempts()
	await _unfinished_retry()
	await _previous_room()
	for speed in [1.0, 0.85]:
		await _new_world()
		await _clear_course(speed)
	await _backtrack()
	_release()
	print("TUTORIAL_REFILL_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _first_dash(first: int) -> bool:
	await _pulse("jump")
	await _step(first)
	_move(Vector2(0.85 if pad else 1.0, -0.85 if pad else -1.0))
	await _pulse("dash")
	_move(Vector2(0.85 if pad else 1.0, 0))
	var before := respawns
	for frame in 100:
		if tutorial.seen.has("dash_refill"):
			return true
		if respawns != before or player.is_on_floor():
			return false
		await _step()
	return false


func _sequence(first: int, second: int) -> void:
	_check(await _first_dash(first), "The real crystal restores a spent dash in flight")
	await _step(second)
	_check(player.is_dash_ready() and not player.is_on_floor() and not player.is_dashing(), "The refill leaves time to choose the next dash")
	_move(Vector2(0.85 if pad else 1.0, -0.85 if pad else -1.0))
	await _pulse("dash")
	_move(Vector2(0.85 if pad else 1.0, 0))
	_check(tutorial.seen.has("refilled_dash") and not player.is_dash_ready() and player.is_dashing(), "The second real airborne dash spends the crystal's refill")


func _lands_on_exit() -> bool:
	var before := respawns
	for frame in 180:
		if respawns != before:
			return false
		if player.is_on_floor():
			for index in player.get_slide_collision_count():
				var contact: KinematicCollision2D = player.get_slide_collision(index)
				if contact.get_collider() == room.get_node("Landing") and contact.get_normal().dot(Vector2.UP) > 0.8:
					return true
			return false
		await _step()
	return false


func _single_dash_attempts() -> void:
	var collected := 0
	for coyote in [0, 5, 7, 9]:
		for first in [0, 12, 24, 36, 39, 40, 48]:
			for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
				await _prepare(1.0, 250)
				await _step(coyote)
				await _pulse("jump")
				await _step(first)
				_move(direction)
				await _pulse("dash")
				_move(Vector2.RIGHT)
				var reached := false
				var before := respawns
				for frame in 160:
					if tutorial.seen.has("dash_refill"):
						collected += 1
					if _on_exit() or tutorial.cleared.has(4):
						reached = true
						break
					if respawns != before:
						break
					await _step()
				_check(not reached, "Jump/coyote plus one of eight dash directions cannot cross, even after collecting without reusing: coyote=%d wait=%d direction=%s" % [coyote, first, direction])
	_check(collected > 0, "The one-dash cases include actual crystal collection without a second dash")


func _without_crystal_attempts() -> void:
	room.get_node("DashCrystal").collision_mask = 0
	for launch in [140, 180, 220]:
		for jump_wait in [0, 4, 8, 12]:
			for second in [0, 16, 32]:
				await _prepare(1.0, launch)
				await _pulse("dash")
				await _step(jump_wait)
				await _pulse("jump")
				await _step(second)
				_move(Vector2(1, -1))
				await _pulse("dash")
				_move(Vector2.RIGHT)
				_check(not await _reaches_exit() and not tutorial.cleared.has(4) and not tutorial.seen.has("dash_refill"), "Ground dash/refill, late jump and another dash cannot replace the crystal: launch=%d waits=%d/%d" % [launch, jump_wait, second])
	await _enter()
	_move(Vector2.RIGHT)
	Input.action_press("wall_grab")
	var reached := false
	for frame in 300:
		Input.action_release("jump")
		Input.action_release("dash")
		if frame % 16 == 0:
			Input.action_press("jump")
		if frame % 23 == 0:
			_move(Vector2(1, -1))
			Input.action_press("dash")
		else:
			_move(Vector2.RIGHT)
		reached = reached or _on_exit() or tutorial.cleared.has(4)
		await _step()
	_check(not reached, "Walking, repeated jumps, wall grabs and dash retries cannot use hidden recovery floors")
	_release()
	room.get_node("DashCrystal").collision_mask = 1
	await _step(2)


func _reaches_exit() -> bool:
	var before := respawns
	for frame in 180:
		if _on_exit() or tutorial.cleared.has(4):
			return true
		if respawns != before:
			return false
		await _step()
	return false


func _on_exit() -> bool:
	if player.is_on_floor():
		for index in player.get_slide_collision_count():
			if player.get_slide_collision(index).get_collider() == room.get_node("Landing"):
				return true
	return false


func _unfinished_retry() -> void:
	await _prepare(1.0, 230)
	_check(await _first_dash(24), "The unfinished attempt collects the real crystal")
	_capture("refilled")
	_release()
	await _reset_key()
	await _step(5)
	_check(_local().distance_to(Vector2(72, 614)) < 2 and player.is_dash_ready() and tutorial.seen.is_empty(), "Actual R restores the safe entrance and resources without incomplete history")
	_check(room.get_node("DashCrystal").visible and room.get_node("DashCrystal").position == Vector2(590, 400), "R restores the crystal")
	_check(not room.get_node("Goal").locked and not tutorial.cleared.has(4) and room.get_node("ReturnBridge/Collision").disabled, "Retry leaves an unpressed arrival and no recovery bridge")
	await _prepare(1.0, 230)
	_check(await _first_dash(24), "The crystal can be reacquired immediately after retry")
	_move(Vector2.ZERO)
	var before := respawns
	for frame in 120:
		if respawns != before:
			break
		await _step()
	await _step(5)
	_check(respawns == before + 1 and _local().distance_to(Vector2(72, 614)) < 2 and player.is_dash_ready(), "Not spending the refill falls back to the entrance within two seconds")
	_check(room.get_node("DashCrystal").visible and tutorial.seen.is_empty() and not tutorial.cleared.has(4), "A failed flight resets the collectible without opening the exit")


func _previous_room() -> void:
	await _enter()
	_move(Vector2.LEFT)
	for frame in 180:
		if tutorial.room_index == 3 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 3 and player.is_on_floor() and player.is_dash_ready() and not player.is_air_jump_ready(), "Leaving left resets resources in the previous room rather than carrying a bypass across the boundary")
	await _enter()
	_check(not tutorial.cleared.has(4) and not room.get_node("ExitBarrier/Collision").disabled and room.get_node("ReturnBridge/Collision").disabled, "Reentering an unfinished room keeps both the exit and bridge closed")


func _clear_course(speed: float) -> void:
	var started := Engine.get_physics_frames()
	_capture("entrance")
	await _prepare(speed, 230)
	await _sequence(24 if speed == 1.0 else 28, 4 if speed == 1.0 else 12)
	_check(await _lands_on_exit(), "The standard keyboard/raw0.85 route reaches the broad landing")
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
	_check(tutorial.cleared.has(4) and room.get_node("Goal").is_pressed() and player.is_on_floor(), "Actual arrival opens the exit after the refill flight")
	_check(room.get_node("ReturnBridge").visible and not room.get_node("ReturnBridge/Collision").disabled, "Only actual completion opens the return bridge")
	print("REFILL_CLEAR_SECONDS speed=%s %.2f" % [speed, (Engine.get_physics_frames() - started) / 60.0])
	_capture("cleared")
	_move(Vector2(speed, 0))
	for frame in 180:
		if tutorial.room_index == 5 and not tutorial.transitioning:
			break
		_move(Vector2(speed, 0))
		await _step()
	_release()
	_check(tutorial.room_index == 5 and player.controls_enabled and not player.is_air_jump_ready(), "Right input enters Room6 with reset resources after actual arrival")


func _backtrack() -> void:
	_move(Vector2.LEFT)
	for frame in 180:
		if tutorial.room_index == 4 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(12)
	_check(tutorial.room_index == 4 and player.is_on_floor() and _local().distance_to(room.get_node("Return").position) < 6, "Returning from Room6 lands on the safe checkpoint")
	await _reset_key()
	await _step(6)
	_check(tutorial.cleared.has(4) and _local().distance_to(room.get_node("Return").position) < 6 and not room.get_node("ReturnBridge/Collision").disabled, "R after backtracking preserves completion, checkpoint and return bridge")
	_move(Vector2.LEFT)
	for frame in 420:
		if tutorial.room_index == 3:
			_release()
			if not tutorial.transitioning and player.is_on_floor():
				break
		await _step()
	_release()
	await _step(10)
	_check(tutorial.room_index == 3 and player.controls_enabled and player.is_on_floor(), "The completed return bridge leads back to Room4 with ordinary left input")


func _new_world() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
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
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial-refill")
		root.get_texture().get_image().save_png("res://docs/screenshots/tutorial-refill/%s.png" % name)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_REFILL_ROUTE: %s (position=%s velocity=%s seen=%s)" % [message, _local(), player.velocity, tutorial.seen.keys()])
