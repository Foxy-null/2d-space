extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var spring_launches := 0
var highest := INF


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _new_world()
	_check(tutorial.STEPS[6].is_empty() and not _room().get_node("Goal").locked, "The spring room is unlocked without action-history requirements")
	_check(not _room().has_node("FloorHint") and not _room().has_node("WallHint"), "The angled plate and gap replace the old explanatory hints")
	await _bypasses()
	await _fall_retry()
	await _flight_retry()
	for amount in [0.7, 0.725, 0.75, 0.775, 0.8, 0.825, 0.85, 0.875, 0.9, 0.925, 0.95, 0.975, 1.0]:
		for pause in [0, 20, 60]:
			await _analog_landing(amount, pause)
	await _rest()
	for amount in [0.7, 0.85, 1.0]:
		await _new_world()
		await _course(amount)
	await _backtrack()
	_release()
	tutorial.free()
	print("TUTORIAL_SPRING_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _bypasses() -> void:
	_room().get_node("FloorSpring").collision_mask = 0
	for lower in [false, true]:
		for coyote in [0, 9]:
			for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
				for delay in [0, 12, 24, 39, 40, 48]:
					await _prepare(lower, 350 if lower else 250)
					await _step(coyote)
					await _pulse("jump")
					await _step(delay)
					_drive(direction)
					await _pulse("dash")
					_drive(Vector2.RIGHT)
					_check(not await _reaches_exit() and spring_launches == 0, "Jump/coyote and eight-way dash cannot replace the spring: lower=%s coyote=%d wait=%d direction=%s" % [lower, coyote, delay, direction])
		for launch in ([230, 250, 280] if lower else [72, 150, 210]):
			for jump_wait in [0, 4, 8, 12]:
				for air_wait in [0, 16, 32]:
					await _prepare(lower, launch)
					await _pulse("dash")
					await _step(jump_wait)
					await _pulse("jump")
					await _step(air_wait)
					_drive(Vector2(1, -1))
					await _pulse("dash")
					_drive(Vector2.RIGHT)
					_check(not await _reaches_exit() and spring_launches == 0, "Ground refill, Superdash and an airborne dash cannot cross: lower=%s launch=%d waits=%d/%d" % [lower, launch, jump_wait, air_wait])
		await _prepare(lower, 330 if lower else 230)
		Input.action_press("wall_grab")
		var reached := false
		for frame in 240:
			Input.action_release("jump")
			if frame % 12 == 0:
				Input.action_press("jump")
			_drive(Vector2(1, -1))
			reached = reached or _on_exit() or tutorial.cleared.has(6)
			await _step()
		_check(not reached and spring_launches == 0, "Repeated jumps and wall climbing/kicks cannot cross the one-way gap")
	_room().get_node("FloorSpring").collision_mask = 1


func _prepare(lower: bool, launch: float) -> void:
	await _enter()
	if lower:
		_stick(0.7)
		for frame in 300:
			if _floor_is("Floor"):
				break
			await _step()
		_stick(0)
		await _step(3)
		_check(_floor_is("Floor"), "The lower bypass reaches the actual small spring pedestal without launch")
		_drive(Vector2.LEFT if _local().x > launch else Vector2.RIGHT)
		for frame in 90:
			if absf(_local().x - launch) < 4:
				break
			await _step()
		_drive(Vector2.RIGHT)
	else:
		await _walk_to(launch)
	_check(player.is_on_floor() and player.is_dash_ready(), "The bypass begins on a real floor with a ready dash")


func _reaches_exit() -> bool:
	for frame in 180:
		if _on_exit() or tutorial.cleared.has(6):
			return true
		if respawns > 0 or tutorial.room_index != 6:
			return false
		await _step()
	return false


func _floor_is(name: String) -> bool:
	if player.is_on_floor():
		for index in player.get_slide_collision_count():
			if player.get_slide_collision(index).get_collider() == _room().get_node(name):
				return true
	return false


func _on_exit() -> bool:
	return _floor_is("SpringLanding") or (player.is_on_floor() and _local().x > 1100 and _local().y < 574)


func _fall_retry() -> void:
	await _enter()
	await _walk_to(230)
	await _pulse("jump")
	for frame in 180:
		if respawns > 0:
			break
		await _step()
	_release()
	await _step(4)
	_check(respawns == 1 and _local().distance_to(_room().get_node("Spawn").position) < 10, "Jumping over the spring and falling restores the safe entrance")
	_check(spring_launches == 0 and tutorial.seen.is_empty() and not tutorial.cleared.has(6), "Missing the launch never opens the exit")


func _flight_retry() -> void:
	await _enter()
	_drive(Vector2.RIGHT)
	for frame in 180:
		if spring_launches > 0:
			break
		await _step()
	_check(spring_launches == 1 and not player.is_on_floor(), "The real angled spring starts the retry flight")
	_release()
	await _reset_key()
	await _step(4)
	_check(_local().distance_to(_room().get_node("Spawn").position) < 2 and player.is_dash_ready() and tutorial.seen.is_empty(), "Actual R during launch restores the entrance and resources")
	_check(not tutorial.cleared.has(6) and not _room().get_node("ExitBarrier/Collision").disabled, "Retry cancels unfinished arrival and keeps the exit closed")


func _analog_landing(amount: float, pause: int) -> void:
	await _enter()
	if pause > 0:
		await _walk_to(150)
		_release()
		await _step(pause)
	_stick(amount)
	await _step(2)
	_check(is_equal_approx(Input.get_axis("move_left", "move_right"), (amount - 0.5) / 0.5), "The real stick retains its partial strength after the configured deadzone")
	for frame in 450:
		if _on_exit() or respawns > 0:
			break
		await _step()
	_check(spring_launches == 1 and respawns == 0 and _on_exit(), "Stick %.3f after a %df pause reaches a safe exit surface" % [amount, pause])
	_check(highest >= 26 and not tutorial.seen.has("jump") and not tutorial.seen.has("dash") and not tutorial.seen.has("wall_jump"), "The visible flight needs only right input, without jump, dash or wall actions")
	_check(not tutorial.cleared.has(6), "The first landing does not invent action history or skip the real arrival press")
	_release()


func _rest() -> void:
	await _analog_landing(0.7, 0)
	await _step(90)
	_check(_floor_is("SpringLanding") and not tutorial.cleared.has(6), "Releasing a partial stick leaves the player at rest on the broad landing")


func _course(amount: float) -> void:
	await _enter()
	_capture("entrance")
	var start := Engine.get_physics_frames()
	if amount == 1.0:
		_drive(Vector2.RIGHT)
	else:
		_stick(amount)
	for frame in 450:
		if spring_launches > 0:
			break
		await _step()
	await _step(6)
	_capture("launched")
	for frame in 240:
		if _on_exit() or respawns > 0:
			break
		await _step()
	_check(spring_launches == 1 and respawns == 0 and _on_exit(), "The real route uses the single required angled spring")
	_capture("landing")
	_release()
	for frame in 240:
		if tutorial.cleared.has(6):
			break
		_drive(Vector2.ZERO if _local().x >= _room().get_node("Goal").position.x - 55 else Vector2.RIGHT)
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release()
	_check(tutorial.cleared.has(6) and _room().get_node("Goal").is_pressed() and respawns == 0, "Actual arrival opens the exit after the spring crossing")
	print("ROOM7_ROUTE_SECONDS input=%.2f %.2f" % [amount, (Engine.get_physics_frames() - start) / 60.0])
	_capture("cleared")
	_drive(Vector2.RIGHT)
	for frame in 180:
		if tutorial.room_index == 7 and not tutorial.transitioning:
			break
		_drive(Vector2.RIGHT)
		await _step()
	_release()
	_check(tutorial.room_index == 7 and player.controls_enabled and player.is_dash_ready(), "The cleared exit leads to Room8 with resources reset")


func _backtrack() -> void:
	_drive(Vector2.LEFT)
	for frame in 180:
		if tutorial.room_index == 6 and not tutorial.transitioning:
			break
		_drive(Vector2.LEFT)
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 6 and player.is_on_floor() and _local().distance_to(_room().get_node("Return").position) < 2, "Returning from Room8 preserves the safe left-entry checkpoint")
	await _reset_key()
	await _step(4)
	_check(tutorial.cleared.has(6) and _local().distance_to(_room().get_node("Return").position) < 2, "R after backtracking preserves the entrance and completed arrival")
	_drive(Vector2.LEFT)
	for frame in 180:
		if tutorial.room_index == 5 and not tutorial.transitioning:
			break
		_drive(Vector2.LEFT)
		await _step()
	_release()
	_check(tutorial.room_index == 5 and player.controls_enabled and player.is_on_floor(), "Left input continues safely into Room6")
	for frame in 240:
		if player.is_air_jump_ready():
			break
		_drive(Vector2.LEFT)
		await _step()
	_check(player.is_air_jump_ready(), "The adjacent room's real boot is acquired before testing reentry")
	_drive(Vector2.RIGHT)
	for frame in 300:
		if tutorial.room_index == 6 and not tutorial.transitioning:
			break
		_drive(Vector2.RIGHT)
		await _step()
	_release()
	_check(tutorial.room_index == 6 and player.controls_enabled and player.is_on_floor() and not player.is_air_jump_ready(), "Returning from Room6 resets the real boot rather than carrying a spring bypass")


func _room() -> Node:
	return tutorial.get_node("Rooms/Room7")


func _drive(direction: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")


func _reset_key() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.physical_keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	await _step()
	key.pressed = false
	Input.parse_input_event(key)
	await _step(2)


func _new_world() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	tutorial.get_node("Rooms/Room7/FloorSpring").launched.connect(func(_body: PlayerController): spring_launches += 1)
	# Earlier rooms are already open when the player reaches this lesson.
	tutorial.cleared[5] = true
	tutorial.call("_set_room", 5, false)
	player.respawn()
	await _step(3)
	await _enter()


func _enter() -> void:
	_release()
	tutorial.call("_set_room", 6, false)
	player.respawn()
	await _step(6)
	respawns = 0
	spring_launches = 0
	highest = _local().y


func _walk_to(x: float) -> void:
	Input.action_press("move_right")
	for frame in 180:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to %d timed out" % x)


func _local() -> Vector2:
	return player.global_position - Vector2(7680, 0)


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _stick(amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = amount
	Input.parse_input_event(event)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		if is_instance_valid(player) and tutorial.room_index == 6:
			highest = minf(highest, _local().y)


func _release() -> void:
	_stick(0)
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_SPRING_ROUTE: %s (room=%d position=%s velocity=%s seen=%s)" % [message, tutorial.room_index + 1, _local(), player.velocity, tutorial.seen.keys()])


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial-spring")
		root.get_texture().get_image().save_png("res://docs/screenshots/tutorial-spring/%s.png" % name)
