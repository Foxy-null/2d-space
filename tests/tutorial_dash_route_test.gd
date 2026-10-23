extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var analog := false
var actions: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _new_world()
	await _bypasses()
	for use_pad in [false, true]:
		analog = use_pad
		await _new_world()
		for launch in [325, 345, 365]:
			for delay in [20, 24, 28, 32, 36]:
				await _enter()
				await _cross_gap(launch, delay)
		await _enter()
		await _cross_gap(305, 28)
		await _finish_course()
		await _backtrack()
	await _fall_and_reset()
	_release()
	print("TUTORIAL_DASH_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _bypasses() -> void:
	for launch in [72, 285, 325, 345, 365, 385, 405, 417, 423, 429]:
		for grab in [false, true]:
			await _enter()
			await _walk_to(launch)
			if grab:
				Input.action_press("wall_grab")
				Input.action_press("move_up")
			await _pulse("jump")
			var reached := false
			for frame in 160:
				if respawns > 0:
					break
				if player.is_wall_grabbing():
					await _pulse("jump")
				await _step()
				reached = reached or _landed()
			_check(not reached and not tutorial.cleared.has(2) and not actions.has("dash"), "Jump/coyote/climb cannot cross the first gap: launch=%d grab=%s" % [launch, grab])
	for wait in [0, 4, 8]:
		await _enter()
		_joy(0.6)
		for frame in 320:
			if _local().x >= 380:
				break
			await _step()
		_joy(-0.6)
		Input.action_press("wall_grab")
		for frame in 20:
			if player.is_wall_grabbing():
				break
			await _step()
		await _step(wait)
		_check(player.is_wall_grabbing(), "The wall-kick attempt starts on the actual entrance wall")
		_joy(0)
		Input.action_press("move_right")
		await _pulse("jump")
		Input.action_release("wall_grab")
		var reached := false
		for frame in 160:
			if respawns > 0:
				break
			await _step()
			reached = reached or _landed()
		_check(actions.has("wall_jump") and not reached and not actions.has("dash"), "A real entrance wall kick cannot replace the gap dash: wait=%d" % wait)
	await _enter()
	Input.action_press("move_right")
	await _step(160)
	_check(respawns > 0 and not tutorial.cleared.has(2) and not actions.has("dash"), "Walking off the edge safely retries without completing the lesson")
	# Superdash is an advanced alternative, rather than a capability to disable here.
	await _enter()
	await _walk_to(305)
	await _pulse("dash")
	await _step(4)
	await _pulse("jump")
	for frame in 160:
		if respawns > 0 or _landed():
			break
		await _step()
	_check(actions.has("superdash") and _landed() and respawns == 0, "The existing advanced superdash remains a valid alternative")


func _cross_gap(launch: float, delay: int) -> void:
	await _walk_to(launch)
	_check(absf(Input.get_axis("move_left", "move_right") - (0.7 if analog else 1.0)) < 0.001, "Keyboard/raw 0.85 motion reaches the launch through the existing input map")
	await _pulse("jump")
	await _step(delay)
	await _pulse("dash")
	for frame in 120:
		if respawns > 0 or _landed():
			break
		await _step()
	_check(_landed() and respawns == 0 and actions.has("jump") and actions.has("dash"), "Jump then dash lands safely: pad=%s launch=%d delay=%d" % [analog, launch, delay])
	_release()
	await _step(30)
	_check(player.is_on_floor() and player.is_dash_ready() and respawns == 0, "The broad landing permits a rest and restores dash")
	_capture("landing")


func _finish_course() -> void:
	tutorial.seen.clear()
	tutorial._update_lesson()
	_move(1)
	for frame in 300:
		if tutorial.cleared.has(2):
			break
		_button("jump", false)
		if _local().x >= 1180:
			_move(0)
		if player.is_on_floor() and player.is_on_wall():
			_button("jump", true)
		await _step()
	_check(tutorial.cleared.has(2) and respawns == 0, "The resting landing leads to the actual arrival switch")
	_check(not tutorial.seen.has("dash") and tutorial.cleared.has(2), "Physical arrival opens the exit without a dash history record")
	_capture("cleared")
	_move(1)
	for frame in 180:
		if tutorial.room_index == 3 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 3 and player.controls_enabled and player.is_dash_ready(), "The completed lesson leads into Room4 with controls and dash restored")


func _backtrack() -> void:
	_move(-1)
	for frame in 180:
		if tutorial.room_index == 2 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(5)
	_check(tutorial.room_index == 2 and player.is_on_floor() and _local().distance_to(Vector2(72, 614)) < 10, "Returning from Room4 uses the safe left entrance")
	await _pulse("reset")
	await _step(5)
	_check(_local().distance_to(Vector2(72, 614)) < 2 and tutorial.cleared.has(2), "Retry after returning keeps the safe entrance and completed lesson")
	_move(-1)
	for frame in 180:
		if tutorial.room_index == 1 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 1 and player.controls_enabled, "Left input after retry safely returns to Room2")
	_move(1)
	for frame in 180:
		if tutorial.room_index == 2 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 2 and player.controls_enabled, "Room2 can be left again through its right exit into Room3")


func _fall_and_reset() -> void:
	await _new_world()
	analog = true
	await _walk_to(325)
	await _pulse("jump")
	await _step(8)
	await _pulse("dash")
	for frame in 160:
		if respawns > 0:
			break
		await _step()
	_release()
	await _step(5)
	_check(respawns == 1 and _local().distance_to(Vector2(72, 614)) < 10 and not tutorial.cleared.has(2), "An early dash that misses the landing restores the entrance")
	await _walk_to(325)
	await _pulse("jump")
	await _step(20)
	await _pulse("dash")
	await _pulse("reset")
	_release()
	await _step(5)
	_check(_local().distance_to(Vector2(72, 614)) < 2 and player.is_on_floor() and player.is_dash_ready() and tutorial.seen.is_empty(), "Real pad retry during dash restores the entrance and resources")


func _new_world() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action: String): actions.append(action))
	tutorial.cleared[1] = true
	tutorial.call("_set_room", 1, false)
	player.respawn()
	await _step(3)
	await _enter()


func _enter() -> void:
	_release()
	tutorial.call("_set_room", 2, false)
	player.respawn()
	await _step(5)
	respawns = 0
	actions.clear()
	_capture("entrance")


func _walk_to(x: float) -> void:
	_move(1)
	for frame in 200:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to the launch timed out")


func _landed() -> bool:
	return player.is_on_floor() and _local().x >= 672 and absf(_local().y - 594) < 2


func _local() -> Vector2:
	return player.global_position - Vector2(2560, 0)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _pulse(action: String) -> void:
	_button(action, true)
	await _step()
	_button(action, false)


func _button(action: String, pressed: bool) -> void:
	var event: InputEvent
	if analog:
		var button := InputEventJoypadButton.new()
		button.button_index = {"jump": JOY_BUTTON_A, "dash": JOY_BUTTON_B, "reset": JOY_BUTTON_START}[action]
		event = button
	else:
		var key := InputEventKey.new()
		key.device = 16
		key.physical_keycode = {"jump": KEY_SPACE, "dash": KEY_X, "reset": KEY_R}[action]
		event = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _move(direction: int) -> void:
	if analog:
		_joy(direction * 0.85)
	else:
		for side in [-1, 1]:
			var key := InputEventKey.new()
			key.physical_keycode = KEY_D if side == 1 else KEY_A
			key.pressed = direction == side
			Input.parse_input_event(key)


func _joy(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)


func _release() -> void:
	_joy(0)
	for use_pad in [false, true]:
		var previous := analog
		analog = use_pad
		_move(0)
		for action in ["jump", "dash", "reset"]:
			_button(action, false)
		analog = previous
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_DASH_ROUTE: %s (room=%d position=%s velocity=%s actions=%s)" % [message, tutorial.room_index + 1, _local(), player.velocity, actions])


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/tutorial-dash-%s.png" % name)
