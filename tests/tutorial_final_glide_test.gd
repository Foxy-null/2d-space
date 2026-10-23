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
	await _basic_shortcuts()
	await _advanced_alternative()
	await _safe_retries()
	for input in [Vector2(1, 0), Vector2(0.85, 0), Vector2(0.85, -0.35), Vector2(0.85, 0.65)]:
		await _new_world()
		pad = input.x < 1
		await _course(input)
	await _backtrack()
	_release()
	print("TUTORIAL_FINAL_GLIDE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _basic_shortcuts() -> void:
	for launch in [350, 440, 475]:
		for direction in [Vector2.ZERO, Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(1, 1), Vector2.DOWN, Vector2.LEFT, Vector2(-1, -1), Vector2(-1, 1)]:
			await _enter()
			await _park_parachute()
			await _walk_to(launch)
			await _pulse("jump")
			if not direction.is_zero_approx():
				_move(direction)
				await _pulse("dash")
				_move(Vector2.RIGHT)
			var reached := false
			for frame in 220:
				await _step()
				reached = reached or _at_exit()
				if respawns > 0 or tutorial.room_index != 15:
					break
			_check(not reached and not tutorial.cleared.has(15), "A normal jump/initial eight-way dash cannot land at the exit from x%d: %s" % [launch, direction])


func _advanced_alternative() -> void:
	await _enter()
	await _park_parachute()
	await _inverted_rest()
	await _walk_to(475)
	await _pulse("jump")
	await _step(36)
	_move(Vector2(1, 1))
	await _pulse("dash")
	_move(Vector2.RIGHT)
	var reached := false
	for frame in 240:
		await _step()
		reached = reached or _at_exit()
		if respawns > 0 or reached:
			break
	_check(reached and player.get_held_object() == null, "Inverted jump plus a delayed down-right dash remains a valid advanced alternative")
	_check(not tutorial.cleared.has(15) and not tutorial.seen.has("wind_lift") and not tutorial.seen.has("inverted_glide"), "The advanced alternative does not replace the three existing parachute lesson conditions")


func _safe_retries() -> void:
	await _enter()
	await _park_parachute()
	_move(Vector2.RIGHT)
	for frame in 300:
		if respawns > 0:
			break
		await _step()
	_release()
	_check(respawns > 0 and _local().x < 100 and player.gravity_direction == 1, "Walking into the gap retries safely at the entrance")
	await _enter()
	await _park_parachute()
	await _inverted_rest()
	_move(Vector2.RIGHT)
	for frame in 240:
		if respawns > 0:
			break
		await _step()
	_release()
	_check(respawns > 0 and _local().x < 100 and player.gravity_direction == 1, "Leaving the ceiling without a parachute retries after crossing the upper screen edge")
	await _enter()
	_grab(true)
	_move(Vector2.RIGHT)
	for frame in 120:
		if player.gravity_direction < 0 and player.is_on_floor():
			break
		await _step()
	_move(Vector2.ZERO)
	await _step(120)
	_check(player.gravity_direction < 0 and player.is_on_floor() and player.get_held_object() == room.get_node("Parachute") and respawns == 0, "The inverted ceiling allows an unhurried rest while holding the parachute")
	_grab(false)
	await _step()
	await _reset_key()
	await _step(5)
	_check(_local().distance_to(Vector2(72, 614)) < 2 and player.gravity_direction == 1 and player.is_dash_ready() and player.get_held_object() == null, "R from the ceiling restores the safe entrance, down gravity, dash, and held state")
	_check(room.get_node("Parachute").position.distance_to(Vector2(170, 593.4)) < 4 and tutorial.seen.is_empty(), "Retry restores the parachute and clears the unfinished lesson")


func _course(input: Vector2) -> void:
	_capture("entrance")
	_grab(true)
	_move(input)
	await _step(3)
	_check(player.get_held_object() == room.get_node("Parachute"), "Holding Grab acquires the entrance parachute")
	if pad:
		_check(is_equal_approx(Input.get_axis("move_left", "move_right"), 0.7), "Raw pad x0.85 passes through the configured deadzone as x0.7")
	var highest := 720.0
	var resting := false
	for frame in 700:
		await _step()
		highest = minf(highest, _local().y)
		if player.gravity_direction < 0 and player.is_on_floor() and not resting:
			resting = true
			_capture("rest")
		if tutorial.seen.has("inverted_glide") and _local().x > 700 and _local().x < 710:
			_capture("glide")
		if tutorial.cleared.has(15) or respawns > 0:
			break
	_move(Vector2.ZERO)
	_check(resting and highest >= 26 and respawns == 0, "The easy route rests under the ceiling and keeps the player within the screen")
	_check(tutorial.cleared.has(15) and room.get_node("Goal").is_pressed() and player.is_on_floor(), "Holding Grab and right presses the real arrival switch")
	_check(tutorial.seen.has("wind_lift") and tutorial.seen.has("inverted_glide") and tutorial.seen.has("down"), "The route physically performs lift, inverted glide, and down gravity")
	_check(not tutorial.seen.has("jump") and not tutorial.seen.has("dash"), "The normal route needs no jump or dash timing")
	_capture("cleared")
	_move(Vector2(input.x, 0))
	for frame in 180:
		if tutorial.room_index == 16 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 16 and player.controls_enabled and player.is_on_floor(), "The landing leads forward into Room17")


func _backtrack() -> void:
	_move(Vector2.LEFT)
	for frame in 180:
		if tutorial.room_index == 15 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 15 and player.is_on_floor() and _local().distance_to(Vector2(72, 614)) < 10, "Returning from Room17 uses the safe left entrance")
	await _reset_key()
	await _step(5)
	_check(_local().distance_to(Vector2(72, 614)) < 2 and tutorial.cleared.has(15), "R after backtracking preserves the safe checkpoint and cleared lesson")
	_move(Vector2.LEFT)
	for frame in 180:
		if tutorial.room_index == 14 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 14 and player.controls_enabled, "Left input after retry continues into Room15")
	_move(Vector2.RIGHT)
	for frame in 180:
		if tutorial.room_index == 15 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 15 and player.is_on_floor(), "Room15 can be left to re-enter the final glide lesson")


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
	await _walk_to(320)
	await _pulse("jump")
	for frame in 80:
		if player.gravity_direction < 0 and player.is_on_floor():
			break
		await _step()
	_check(player.gravity_direction < 0 and player.is_on_floor(), "The advanced attempt reaches the real inverted ceiling")


func _walk_to(x: float) -> void:
	_move(Vector2.RIGHT)
	for frame in 250:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to x%d timed out" % x)


func _at_exit() -> bool:
	return _local().x >= 1082 and _local().x <= 1260 and _local().y >= 400 and _local().y <= 640 and player.gravity_direction == 1 and player.is_on_floor()


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
