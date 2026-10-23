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
		for launch in [300, 340, 380]:
			for first in [12, 16, 20, 24]:
				for second in [12, 16, 20, 24]:
					await _prepare(speed, launch)
					await _combo(first, second)
					_check(await _land(), "Both extra jumps land on the upper platform: speed=%s launch=%d gaps=%d/%d" % [speed, launch, first, second])
		for gap in range(4, 37, 4):
			await _prepare(speed, 380)
			await _jump()
			await _step(gap)
			await _jump()
			_check(not await _land(), "One extra jump does not reach the upper platform at gap %d" % gap)
	await _advanced_dash()
	await _retry_without_reset()
	for speed in [1.0, 0.85]:
		await _new_world()
		await _clear_course(speed)
	await _backtrack()
	_release()
	print("TUTORIAL_COMBO_JUMP_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _combo(first: int, second: int) -> void:
	await _jump()
	_check(player.get_available_extra_jump_count() == 2, "The floor jump preserves both extra jumps")
	await _step(first)
	await _jump()
	_check(player.get_available_extra_jump_count() == 1 and room.get_node("Creature").extra_jump_count() == 1 and tutorial.seen.has("combo_air"), "The first extra jump spends the boot and preserves the creature")
	_capture("first")
	await _step(second)
	await _jump()
	_check(player.get_available_extra_jump_count() == 0 and room.get_node("Creature").extra_jump_count() == 0 and tutorial.seen.has("combo_creature"), "The second extra jump spends the creature in the same flight")
	_capture("second")


func _advanced_dash() -> void:
	await _prepare(1.0, 380)
	await _jump()
	await _step(20)
	_move(Vector2.UP)
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	_move(Vector2.RIGHT)
	_check(await _land(), "Jump followed by an upward dash remains an advanced way onto the platform")
	_check(not tutorial.seen.has("combo_air") and not tutorial.seen.has("combo_creature") and room.get_node("Goal").locked, "The dash alternative keeps the existing two-kind lesson and arrival lock")


func _retry_without_reset() -> void:
	await _prepare(0.85, 340)
	await _combo(8, 8)
	_check(not await _land() and absf(_local().y - 614) < 2, "Very early extra jumps return to the continuous safe floor")
	_check(player.get_available_extra_jump_count() == 1 and room.get_node("Creature").extra_jump_count() == 1, "Landing refills the creature but does not recreate the spent boot")
	_move(Vector2.LEFT)
	for frame in 240:
		if _local().x <= 275:
			break
		await _step()
	_move(Vector2.ZERO)
	for frame in 180:
		if player.get_available_extra_jump_count() == 2:
			break
		await _step()
	_check(player.is_on_floor() and player.get_available_extra_jump_count() == 2 and player.get_held_object() == room.get_node("Creature"), "Walking back to the respawned boot restores both resources without R")
	await _walk_to(340, 0.85)
	await _combo(16, 16)
	_check(await _land(), "A failed attempt can be retried immediately after collecting the boot")
	_move(Vector2.ZERO)
	_grab(false)
	await _reset_key()
	await _step(5)
	_check(_local().distance_to(Vector2(72, 614)) < 2 and player.is_dash_ready() and player.get_held_object() == null and tutorial.seen.is_empty(), "R from the upper platform restores the entrance and unfinished lesson")
	_check(room.get_node("Creature").position.distance_to(Vector2(170, 607.1)) < 4 and room.get_node("JumpCrystal").visible, "R restores both creature and boot")


func _clear_course(speed: float) -> void:
	_capture("entrance")
	await _prepare(speed, 340)
	await _combo(16, 16)
	_check(await _land(), "The ordinary route reaches the upper platform without dash or wall timing")
	_check(player.get_available_extra_jump_count() == 1 and player.is_dash_ready(), "The upper landing refills the held creature and keeps dash ready")
	_capture("landing")
	for frame in 300:
		if tutorial.cleared.has(14):
			break
		_move(Vector2(speed, 0))
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_move(Vector2.ZERO)
	Input.action_release("jump")
	_check(tutorial.cleared.has(14) and room.get_node("Goal").is_pressed(), "The completed two-kind jumps lead to pressing the actual arrival switch")
	_check(tutorial.seen.has("two_jumps") and tutorial.seen.has("combo_air") and tutorial.seen.has("combo_creature") and not tutorial.seen.has("dash"), "The natural route performs all three original lesson conditions without dash")
	_capture("cleared")
	_move(Vector2(speed, 0))
	for frame in 240:
		if tutorial.room_index == 15 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 15 and player.controls_enabled, "Right input enters Room16 after pressing the arrival switch")


func _backtrack() -> void:
	_move(Vector2.LEFT)
	for frame in 320:
		if tutorial.room_index == 14 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(12)
	_check(tutorial.room_index == 14 and player.is_on_floor() and _local().distance_to(room.get_node("Return").position) < 5, "Returning from Room16 lands safely on the right floor")
	await _reset_key()
	await _step(5)
	_check(tutorial.cleared.has(14) and _local().distance_to(room.get_node("Return").position) < 2, "R after returning preserves the cleared room and right entrance")
	_move(Vector2.LEFT)
	for frame in 400:
		if tutorial.room_index == 13 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 13 and player.controls_enabled, "The continuous lower floor leads left into Room14")
	_grab(true)
	_move(Vector2.RIGHT)
	for frame in 80:
		if tutorial.room_index != 13 or player.position.x - tutorial.rooms.get_child(13).position.x >= 220:
			break
		await _step()
	await _jump()
	for frame in 320:
		if tutorial.room_index == 14 and not tutorial.transitioning:
			break
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		if tutorial.room_index == 13 and player.position.x - tutorial.rooms.get_child(13).position.x >= 1000:
			_grab(false)
		await _step()
	_release()
	_check(tutorial.room_index == 14 and player.is_on_floor(), "Room14 leads forward to the original Room15 entrance")


func _new_world() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	room = tutorial.get_node("Rooms/Room15")
	# A normal Room15 visit has already opened the preceding room's exit.
	tutorial.cleared[13] = true
	tutorial.call("_set_room", 13, false)
	player.respawn()
	await _step()
	await _enter()


func _enter() -> void:
	_release()
	pad = false
	tutorial.call("_set_room", 14, false)
	player.respawn()
	await _step(6)


func _prepare(speed: float, launch: int) -> void:
	await _enter()
	pad = speed < 1
	_grab(true)
	await _step(3)
	await _walk_to(launch, speed)
	_check(player.get_available_extra_jump_count() == 2 and player.get_held_object() == room.get_node("Creature") and player.is_on_floor(), "The entrance provides creature plus boot before launch")
	if pad:
		_check(is_equal_approx(Input.get_axis("move_left", "move_right"), 0.7), "Raw joystick x0.85 uses the real deadzone-adjusted x0.7")


func _walk_to(x: float, speed: float) -> void:
	_move(Vector2(speed, 0))
	for frame in 240:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to the launch position timed out")


func _land() -> bool:
	for frame in 180:
		await _step()
		if player.is_on_floor():
			return _local().x >= 442 and _local().y <= 330
	_check(false, "The jump did not return to a safe floor")
	return false


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


func _jump() -> void:
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")


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
		root.get_texture().get_image().save_png("/tmp/tutorial-combo-jump-%s.png" % name)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_COMBO_JUMP: %s (position=%s velocity=%s seen=%s)" % [message, _local(), player.velocity, tutorial.seen.keys()])
