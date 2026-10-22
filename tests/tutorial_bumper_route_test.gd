extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var highest := INF
var bounces := 0
var reflected := Vector2.ZERO
var impact_position := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _new_world(false)
	await _bypasses()
	await _new_world()
	await _fall_retry()
	for pause in [0, 20, 60]:
		await _new_world()
		await _course(pause)
	for axis in [0.7, 0.85, 1.0]:
		await _new_world()
		await _course(0, axis)
	await _backtrack()
	_release()
	print("TUTORIAL_BUMPER_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _bypasses() -> void:
	# Remove only the bumper in the initial fixture; all player abilities remain available.
	for lower in [false, true]:
		for launch in ([400, 430, 460, 490] if lower else [72, 200, 260, 300]):
			for direction in ["right", "up_right", "up"]:
				for dash_frame in [-1, 0, 12, 24, 36, 48, 60]:
					await _attempt(lower, launch, direction, dash_frame)
	for launch in [72, 400, 430]:
		await _attempt(launch > 72, launch, "superdash", -1)
	await _enter()
	Input.action_press("move_right")
	await _step(180)
	_check(not tutorial.cleared.has(7) and not tutorial.seen.has("pinball"), "Walking without a bumper cannot complete the lesson")
	_release()


func _attempt(lower: bool, launch: float, direction: String, dash_frame: int) -> void:
	await _enter()
	if lower:
		await _pulse("jump")
		await _walk_to(350)
		_release()
		await _step(12)
		_check(player.is_on_floor() and absf(_local().y - 674) < 2, "The lower-floor attempt starts from a real safe landing")
	await _walk_to(launch)
	if direction == "superdash":
		await _pulse("dash")
		await _step(4)
	await _pulse("jump")
	var reached := false
	for frame in 240:
		if respawns > 0:
			break
		if frame == dash_frame:
			Input.action_release("move_up")
			if direction != "right":
				Input.action_press("move_up")
			if direction == "up":
				Input.action_release("move_right")
			await _pulse("dash")
			Input.action_press("move_right")
			Input.action_release("move_up")
		if _local().x > 680:
			Input.action_press("wall_grab")
			Input.action_press("move_up")
		# Include climbing the exit wall and jumping back toward the landing.
		if player.is_wall_grabbing() and _local().x > 1200 and _local().y < 380:
			Input.action_release("move_right")
			Input.action_press("move_left")
			await _pulse("jump")
		await _step()
		reached = reached or (_local().x >= 722 and _local().y <= 304)
	_check(not reached, "Without the bumper, jump/coyote/dash/wall actions cannot reach the landing: lower=%s launch=%d direction=%s frame=%d" % [lower, launch, direction, dash_frame])
	_release()


func _fall_retry() -> void:
	await _walk_to(180)
	await _pulse("jump")
	Input.action_press("move_right")
	for frame in 240:
		if respawns > 0:
			break
		await _step()
	_release()
	await _step(4)
	_check(respawns == 1 and _local().distance_to(Vector2(72, 504)) < 10, "Jumping past the bumper and falling restores the safe entrance")
	_check(bounces == 0 and not tutorial.cleared.has(7), "A missed bumper cannot satisfy the lesson")


func _course(pause: int, joy_value: float = 0.0) -> void:
	_capture("entrance")
	if pause > 0:
		await _walk_to(180)
		_release()
		await _step(pause)
	if joy_value > 0.0:
		_joy(joy_value)
		_check(absf(Input.get_axis("move_left", "move_right") - (joy_value - 0.5) * 2.0) < 0.001, "Real joystick motion applies the existing 0.5 deadzone")
	else:
		Input.action_press("move_right")
	for frame in 200:
		if bounces > 0 and player.is_on_floor() and _local().y < 400:
			break
		await _step()
	_check(bounces == 1 and tutorial.seen.has("pinball") and player.is_on_floor() and absf(_local().y - 304) < 2, "Holding right after a pause of %d frames, joy=%f, reflects onto the wide landing" % [pause, joy_value])
	_check(reflected.y < -800 and reflected.x > 0 and impact_position.y < 624, "The actual upper-surface collision reflects the player upward and right")
	_check(respawns == 0 and highest >= 26, "The whole player stays in the screen without an upward retry")
	_check(not tutorial.seen.has("jump") and not tutorial.seen.has("dash") and not tutorial.seen.has("wall_jump"), "Reaching the landing requires only right input")
	_capture("landing")
	if joy_value > 0.0:
		print("BUMPER_JOYPAD axis=%f effective=%f contact=%s reflection=%s landing=%s highest=%f respawns=%d" % [joy_value, Input.get_axis("move_left", "move_right"), impact_position, reflected, _local(), highest, respawns])
		_joy(0.0)
	Input.action_release("move_right")
	await _step(60)
	_check(player.is_on_floor() and absf(_local().y - 304) < 2, "The landing provides a safe place to rest")
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.cleared.has(7):
			break
		Input.action_release("jump")
		if _local().x >= 900:
			Input.action_release("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_check(tutorial.cleared.has(7) and respawns == 0, "Pressing the real arrival switch completes the single-reflection lesson")
	_capture("cleared")
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 8 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 8 and player.controls_enabled, "The landing leads into Room9")


func _backtrack() -> void:
	Input.action_press("move_left")
	for frame in 180:
		if tutorial.room_index == 7 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 7 and player.is_on_floor() and _local().distance_to(Vector2(72, 504)) < 10, "Room9 can be left through the one-way landing and returns to the safe entrance")
	await _pulse("reset")
	await _step(4)
	_check(_local().distance_to(Vector2(72, 504)) < 2 and tutorial.cleared.has(7), "Retry after backtracking preserves the safe entrance and completed lesson")
	Input.action_press("move_left")
	for frame in 180:
		if tutorial.room_index == 6 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(20)
	_check(tutorial.room_index == 6 and player.controls_enabled and player.is_on_floor(), "Left input after retry safely continues into Room7")
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 7 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 7 and player.controls_enabled, "Room7 can be left through its right exit to re-enter Room8")


func _new_world(with_bumper: bool = true) -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	var bumper := tutorial.get_node("Rooms/Room8/Pinball")
	if with_bumper:
		bumper.launched.connect(func(body: PlayerController):
			bounces += 1
			reflected = body.get_environment_velocity()
			impact_position = _local()
			_capture("reflection")
		)
	else:
		bumper.free()
	# Entering the lesson normally means the previous room's exit is already open.
	tutorial.cleared[6] = true
	tutorial.call("_set_room", 6, false)
	player.respawn()
	await _step(3)
	await _enter()


func _enter() -> void:
	_release()
	tutorial.call("_set_room", 7, false)
	player.respawn()
	await _step(6)
	respawns = 0
	bounces = 0
	reflected = Vector2.ZERO
	impact_position = Vector2.ZERO
	highest = _local().y


func _walk_to(x: float) -> void:
	Input.action_press("move_right")
	for frame in 180:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to %d timed out" % x)


func _local() -> Vector2:
	return player.global_position - Vector2(8960, 0)


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		if is_instance_valid(player) and tutorial.room_index == 7:
			highest = minf(highest, _local().y)


func _release() -> void:
	_joy(0.0)
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _joy(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_BUMPER_ROUTE: %s (room=%d position=%s velocity=%s seen=%s)" % [message, tutorial.room_index + 1, _local(), player.velocity, tutorial.seen.keys()])


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/tutorial-bumper-%s.png" % name)
