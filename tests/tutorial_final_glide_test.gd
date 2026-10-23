extends SceneTree

var tutorial: Node
var player: PlayerController
var room: Node2D
var failed := false
var checks := 0
var respawns := 0
var pad := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _new_world()
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _inverted_rest()
		_capture("rest")
		_release()
		await _reset_key()
		await _step(5)
		_capture("retry")
		respawns = 0
		await _course(Vector2.RIGHT)
	else:
		await _boundary_resources()
		await _safe_retries()
		await _gate_ablations()
		await _gate_choices()
		for input in [Vector2(1, 0), Vector2(0.85, 0), Vector2(0.85, -0.35), Vector2(0.85, 0.65), Vector2(0.7, 0)]:
			await _new_world()
			pad = input.x < 1
			await _course(input)
	# Let queued zero-axis events settle before switching to digital backtracking.
	await _step(2)
	await _backtrack()
	_release()
	print("TUTORIAL_FINAL_GLIDE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _boundary_resources() -> void:
	# Complete the preceding terrain lesson through real movement and both air jumps.
	var previous := tutorial.get_node("Rooms/Room15") as Node2D
	tutorial.call("_set_room", 14, false)
	player.respawn()
	await _step(6)
	respawns = 0
	_grab(true)
	_move(Vector2.RIGHT)
	for frame in 200:
		if player.position.x - previous.position.x >= 380:
			break
		await _step()
	_check(player.get_held_object() == previous.get_node("Creature"), "The real Room15 route carries its companion")
	await _pulse("jump")
	await _step(20)
	await _pulse("jump")
	await _step(20)
	_check(player.is_air_jump_ready(), "The preceding route physically acquires the airborne boots")
	await _pulse("jump")
	await _step(20)
	_move(Vector2.UP)
	await _pulse("dash")
	_move(Vector2.RIGHT)
	for frame in 360:
		await _step()
		if tutorial.room_index == 15:
			_release()
			break
	await _step(25)
	_check(tutorial.room_index == 15 and not tutorial.transitioning and tutorial.cleared.has(14), "The preceding lesson reaches Room16 through its real boundary")
	_check(player.get_held_object() == null and not player.is_air_jump_ready() and tutorial.seen.is_empty(), "Boundary respawn removes carried resources before the final lesson")
	_check(respawns == 1 and _local().distance_to(Vector2(72, 614)) < 4, "The boundary performs one safe entrance respawn")


func _safe_retries() -> void:
	await _enter()
	await _park_parachute()
	_move(Vector2.RIGHT)
	for frame in 300:
		if respawns > 0:
			break
		await _step()
	_release()
	_check(respawns == 1 and _local().x < 100 and player.gravity_direction == 1, "Walking into the gap retries once at the entrance")
	await _enter()
	await _inverted_rest()
	await _step(180)
	_check(player.gravity_direction < 0 and player.is_on_floor() and player.get_held_object() == room.get_node("Parachute") and respawns == 0, "The inverted ceiling allows an unhurried three-second rest")
	_capture("rest")
	_release()
	await _reset_key()
	await _step(5)
	_check(_local().distance_to(Vector2(72, 614)) < 4 and player.gravity_direction == 1 and player.is_dash_ready() and player.get_held_object() == null, "Actual R from the ceiling restores entrance, gravity, dash, and held state")
	_check(room.get_node("Parachute").position.distance_to(Vector2(170, 593.4)) < 4 and tutorial.seen.is_empty(), "Retry restores the parachute and clears lesson telemetry")
	_check(is_equal_approx(tutorial.camera.position.x, room.position.x + 640), "Retry immediately restores the entrance camera clamp")
	_capture("retry")
	await _enter()
	await _inverted_rest()
	await _step(180)
	_move(Vector2.RIGHT)
	for frame in 400:
		await _step()
		if tutorial.cleared.has(15) or respawns > 0:
			break
	_check(tutorial.cleared.has(15) and respawns == 0, "Resume from the three-second ceiling rest and land on the real arrival")
	# Reset while still overlapping the real UpGate: stale contact must not reapply Up remotely.
	await _enter()
	_grab(true)
	_move(Vector2.RIGHT)
	for frame in 400:
		await _step()
		if tutorial.seen.has("up"):
			break
	_check(tutorial.seen.has("up"), "The immediate-R fixture physically enters UpGate")
	_release()
	await _reset_key()
	await _step(12)
	_check(player.gravity_direction == 1 and tutorial.seen.is_empty() and _local().distance_to(Vector2(72, 614)) < 4, "Immediate real R does not apply a distant stale gate contact")


func _gate_ablations() -> void:
	for name in ["GateUp", "GateDown"]:
		tutorial.cleared.erase(15)
		await _enter()
		room.get_node(name).monitoring = false
		_grab(true)
		_move(Vector2.RIGHT)
		var reached := false
		for frame in 900:
			await _step()
			reached = reached or _at_exit()
			if respawns > 0 or tutorial.cleared.has(15):
				break
		_release()
		_check(not reached and not tutorial.cleared.has(15) and respawns == 1, "The continuous held route needs the real %s contact" % name)
		room.get_node(name).monitoring = true


func _gate_choices() -> void:
	for launch in [1040, 1080, 1100]:
		for direction in [Vector2.ZERO, Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(1, 1), Vector2.DOWN, Vector2.LEFT, Vector2(-1, -1), Vector2(-1, 1)]:
			tutorial.cleared.erase(15)
			await _enter()
			_grab(true)
			await _walk_to(launch)
			if not direction.is_zero_approx():
				_move(direction)
				await _pulse("dash")
			_move(Vector2.RIGHT)
			var reached := false
			for frame in 900:
				await _step()
				reached = reached or _at_exit()
				if reached or respawns > 0 or tutorial.cleared.has(15):
					break
			_check(not reached or (tutorial.seen.has("up") and tutorial.seen.has("down")), "Eight-way dash attempts near UpGate cannot land without both real gravity contacts")


func _course(input: Vector2) -> void:
	_capture("entrance")
	_grab(true)
	_move(input)
	await _step(3)
	_check(player.get_held_object() == room.get_node("Parachute"), "Holding Grab acquires the entrance parachute")
	if pad:
		_check(is_equal_approx(Input.get_axis("move_left", "move_right"), (input.x - 0.5) / 0.5), "Weak stick input passes through the configured deadzone")
	var highest := 720.0
	var resting := false
	var captured := false
	var elapsed := 3
	var crossed_old_edge := false
	for frame in 1200:
		await _step()
		elapsed += 1
		highest = minf(highest, _local().y)
		if player.gravity_direction < 0 and player.is_on_floor() and not resting:
			resting = true
			_capture("rest")
		if _local().x > 1280 and not crossed_old_edge:
			crossed_old_edge = true
			_check(tutorial.room_index == 15 and not tutorial.transitioning, "Crossing x1280 remains inside the widened lesson")
		if tutorial.seen.has("inverted_glide") and _local().x > 1280 and not captured:
			captured = true
			_capture("glide")
		if tutorial.cleared.has(15) or respawns > 0:
			break
	_move(Vector2.ZERO)
	_check(resting and highest >= 26 and respawns == 0, "The held route rests under the ceiling and stays in screen height")
	_check(tutorial.cleared.has(15) and room.get_node("Goal").is_pressed() and player.is_on_floor(), "Holding Grab and right presses the real arrival switch")
	_check(tutorial.seen.has("wind_lift") and tutorial.seen.has("up") and tutorial.seen.has("inverted_glide") and tutorial.seen.has("down"), "The route physically uses lift, both gates, and inverted glide")
	_check(not tutorial.seen.has("jump") and not tutorial.seen.has("dash") and elapsed <= 1800, "The normal route needs no jump/dash timing and finishes within thirty seconds")
	_check(is_equal_approx(tutorial.camera.position.x, room.position.x + 960), "The camera reaches its far clamp with the exit visible")
	_check(tutorial.completed and tutorial.get_node("HUD/Completion").visible, "Physical arrival completes the sixteen main lessons")
	print("FINAL_GLIDE_ROUTE input=%s seconds=%.2f" % [input, elapsed / 60.0])
	_capture("cleared")
	_move(Vector2(input.x, 0))
	for frame in 180:
		if tutorial.room_index == 16 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 16 and player.controls_enabled and player.is_on_floor(), "The expanded boundary leads into Room17")
	_check(tutorial.get_node("Rooms/Room17").position.x == room.position.x + 1600, "Room17 begins at the actual widened boundary")


func _backtrack() -> void:
	var before := respawns
	_move(Vector2.LEFT)
	for frame in 180:
		if tutorial.room_index == 15 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 15 and player.is_on_floor() and _local().distance_to(Vector2(72, 614)) < 10, "Returning from Room17 uses the safe left entrance")
	_check(respawns == before + 1 and is_equal_approx(tutorial.camera.position.x, room.position.x + 640), "Backtracking performs one transition and restores the entrance camera")
	_release()
	await _reset_key()
	await _step(5)
	_check(_local().distance_to(Vector2(72, 614)) < 4 and tutorial.cleared.has(15), "R after backtracking preserves the checkpoint and completed lesson")
	_move(Vector2.LEFT)
	for frame in 180:
		if tutorial.room_index == 14 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(2)
	_check(tutorial.room_index == 14 and player.controls_enabled and player.is_on_floor(), "Left input reaches Room15's high return landing")
	before = respawns
	_move(Vector2.RIGHT)
	for frame in 180:
		if tutorial.room_index == 15 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 15 and player.is_on_floor() and respawns == before + 1, "Room15 re-enters the expanded lesson without an extra fall")


func _new_world() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	room = tutorial.get_node("Rooms/Room16")
	player.respawned.connect(func(): respawns += 1)
	# The preceding exit is already open during a normal visit to Room16.
	tutorial.cleared[14] = true
	tutorial.call("_set_room", 14, false)
	player.respawn()
	await _step()
	await _enter()


func _enter() -> void:
	_release()
	pad = false
	tutorial.call("_set_room", 15, false)
	player.respawn()
	await _step(6)
	respawns = 0


func _park_parachute() -> void:
	# Park it behind the player through actual Grab/release input before bare attempts.
	_grab(true)
	await _step(3)
	_move(Vector2.LEFT)
	await _step(6)
	_grab(false)
	await _step()
	_move(Vector2.ZERO)
	await _step(12)
	_check(player.get_held_object() == null, "The bare attempt releases the actual parachute")


func _inverted_rest() -> void:
	_grab(true)
	_move(Vector2.RIGHT)
	for frame in 400:
		await _step()
		if player.gravity_direction < 0 and player.is_on_floor():
			_move(Vector2.ZERO)
			return
	_check(false, "Holding the actual parachute reaches the inverted ceiling through wind and UpGate")


func _walk_to(x: float) -> void:
	_move(Vector2.RIGHT)
	for frame in 250:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to x%d timed out" % x)


func _at_exit() -> bool:
	return _local().x >= 1402 and _local().x <= 1580 and _local().y >= 400 and _local().y <= 640 and player.gravity_direction == 1 and player.is_on_floor()


func _local() -> Vector2:
	return player.position - room.position


func _move(direction: Vector2) -> void:
	if pad:
		for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			_joy(axis, direction.x if axis == JOY_AXIS_LEFT_X else direction.y)
		return
	for key in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(key)
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")


func _grab(value: bool) -> void:
	if pad:
		_joy(JOY_AXIS_TRIGGER_LEFT, 1 if value else 0)
	elif value:
		Input.action_press("wall_grab")
	else:
		Input.action_release("wall_grab")


func _joy(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


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


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


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
		root.get_texture().get_image().save_png("/tmp/tutorial-final-glide-%s.png" % name)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_FINAL_GLIDE: %s (position=%s velocity=%s seen=%s)" % [message, _local(), player.velocity, tutorial.seen.keys()])
