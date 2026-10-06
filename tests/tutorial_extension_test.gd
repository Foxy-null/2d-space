extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	await _step(5)
	_check(tutorial.rooms.get_child_count() == 17, "16 main rooms plus one optional room")
	await _test_airborne_sequence()
	for index in range(4, 17):
		await _enter(index)
		var goal: Area2D = _room().get_node("Goal")
		player.global_position = goal.global_position + Vector2(0, -10)
		player.velocity = Vector2.ZERO
		await _step(8)
		_check(not tutorial.cleared.has(index), "Arriving without using the gimmick must not clear the room")
		_check(not _room().get_node("ExitBarrier/Collision").disabled, "Unlearned room must have a physical exit barrier")
		await _enter(index)
		match index:
			4: await _refill_course()
			5: await _air_jump_course()
			6: await _spring_course()
			7: await _pinball_course()
			8: await _wind_course()
			9: await _walk_goal()
			10: await _carry_course()
			11: await _throw_course()
			12: await _creature_course()
			13: await _parachute_course()
			14: await _combo_course()
			15: await _glider_combo_course()
			16: await _superdash_course()
		_check(tutorial.cleared.has(index), "Natural input must complete every lesson and land on its target")
		_check(_room().get_node("ExitBarrier/Collision").disabled, "Successful lesson must open the exit")
		if index == 12:
			await _test_creature_exit()
			await _enter(index)
		if index == 15:
			_check(tutorial.completed and not tutorial.cleared.has(16), "Main completion must not require optional Superdash")
		if tutorial.cleared.has(index):
			player.respawn()
			await _step(4)
			_check(tutorial.cleared.has(index) and _room().get_node("ExitBarrier/Collision").disabled, "Completed lessons stay open after retry")
		_release()
	_check(tutorial.completed and tutorial.cleared.has(15), "The main course completes independently of optional Superdash")
	await _test_retry()
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _screenshots()
	print("TUTORIAL_EXTENSION_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _refill_course() -> void:
	await _walk_to(280)
	await _pulse("jump")
	await _step(16)
	await _pulse("dash")
	await _step(10)
	_check(tutorial.seen.has("dash_refill"), "Crystal must refill a genuinely spent air dash")
	await _pulse("dash")
	await _walk_goal()


func _test_airborne_sequence() -> void:
	await _enter(4)
	await _walk_to(280)
	await _pulse("jump")
	await _step(16)
	await _pulse("dash")
	await _step(10)
	_check(tutorial.seen.has("dash_refill"), "A spent dash can be refilled in flight")
	_release()
	await _step(80)
	_check(player.is_on_floor() and not tutorial.seen.has("dash_refill"), "Landing before the second dash invalidates the airborne sequence")
	_check(not tutorial.cleared.has(4), "Incomplete airborne sequence leaves the exit locked")


func _air_jump_course() -> void:
	await _walk_to(400)
	await _pulse("jump")
	await _step(16)
	await _pulse("jump")
	await _walk_goal()


func _spring_course() -> void:
	await _walk_to(700)
	Input.action_release("move_right")
	Input.action_press("move_left")
	for frame in 300:
		if tutorial.seen.has("wall_spring"):
			break
		await _step()
	_check(tutorial.seen.has("floor_spring") and tutorial.seen.has("wall_spring"), "Both mounted spring directions must launch the player")
	Input.action_release("move_left")
	Input.action_press("move_right")
	await _pulse("dash")
	await _walk_goal()


func _pinball_course() -> void:
	await _walk_to(455)
	await _pulse("jump")
	await _step(9)
	await _pulse("dash")
	await _walk_goal()


func _wind_course() -> void:
	Input.action_press("move_right")
	for frame in 200:
		if player.is_on_wall():
			break
		if tutorial.seen.has("wind_walk") and player.is_on_floor() and player.is_dash_ready() and not player.is_dashing():
			await _pulse("dash")
		await _step()
	while player.is_dashing():
		await _step()
	_check(player.is_on_wall(), "Dash must reach the wall against the strong headwind")
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await _step(40)
	Input.action_release("move_up")
	Input.action_release("wall_grab")
	await _pulse("dash")
	await _walk_goal()


func _carry_course() -> void:
	await _grab("SmallBox")
	Input.action_release("move_right")
	await _step(12)
	Input.action_release("wall_grab")
	await _step(20)
	await _grab("Heavy")
	await _walk_to(745)
	Input.action_release("move_right")
	await _step(12)
	Input.action_release("wall_grab")
	Input.action_press("move_left")
	await _step(18)
	Input.action_release("move_left")
	await _step(45)
	_check(_room().get_node("Button").is_pressed(), "Dropped Heavy must physically press the button")
	await _grab("Heavy")
	await _step(5)
	_check(tutorial.seen.has("button_off"), "Picking up the box turns the real button off")
	await _walk_goal()


func _throw_course() -> void:
	await _grab("Heavy")
	await _walk_to(500)
	await _pulse("jump")
	await _step(12)
	Input.action_release("wall_grab")
	await _step(70)
	_check(tutorial.seen.has("throw_button"), "A real thrown body must land on the target button")
	await _walk_goal()


func _creature_course() -> void:
	await _grab("Creature")
	await _walk_to(320)
	await _pulse("jump")
	await _step(16)
	await _pulse("jump")
	for frame in 90:
		if tutorial.seen.has("creature_landed"):
			break
		await _step()
	_check(tutorial.seen.has("creature_landed"), "Real landing restores held Creature")
	await _walk_to(650)
	await _pulse("jump")
	await _step(16)
	await _pulse("jump")
	await _walk_goal()


func _test_creature_exit() -> void:
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index != 12:
			break
		await _step()
	Input.action_release("move_right")
	_check(tutorial.room_index == 13, "Walking right after clearing Jump Creature must enter the Parachute room")
	await _step(20)
	_check(not tutorial.transitioning and player.controls_enabled, "Room entry must restore controls after the camera transition")
	_check(player.gravity_direction == 1 and player.is_on_floor(), "Room entry must land safely on the raised entrance floor")


func _parachute_course() -> void:
	await _grab("Parachute")
	Input.action_press("move_right")
	for frame in 130:
		if tutorial.seen.has("glide"):
			break
		await _step()
	_check(tutorial.seen.has("glide"), "Held parachute must actually slow a fall")
	Input.action_release("wall_grab")
	await _walk_goal()


func _combo_course() -> void:
	await _grab("Creature")
	await _walk_to(380)
	_check(player.get_available_extra_jump_count() == 2, "Crystal and held Creature show two extra jumps")
	await _pulse("jump")
	await _step(16)
	await _pulse("jump")
	_check(player.get_available_extra_jump_count() == 1, "First air jump consumes the personal right")
	await _step(16)
	await _pulse("jump")
	_check(player.get_available_extra_jump_count() == 0, "Second air jump consumes the Creature right")
	await _walk_goal()


func _glider_combo_course() -> void:
	await _grab("Parachute")
	await _walk_goal()
	_check(tutorial.seen.has("wind_lift") and tutorial.seen.has("inverted_glide"), "Real updraft and gravity reversal work with the held parachute")


func _superdash_course() -> void:
	await _walk_to(570)
	await _pulse("dash")
	await _step(4)
	await _pulse("jump")
	await _walk_goal()


func _walk_to(x: float, limit: int = 350) -> void:
	Input.action_press("move_right")
	for frame in limit:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to %s timed out" % x)


func _walk_goal() -> void:
	Input.action_press("move_right")
	for frame in 450:
		if tutorial.cleared.has(tutorial.room_index):
			_release()
			await _step(2)
			return
		Input.action_release("jump")
		var goal: Area2D = _room().get_node("Goal")
		if tutorial.call("_steps_done") and player.global_position.x >= goal.global_position.x - 55:
			Input.action_release("move_right")
		else:
			Input.action_press("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		if OS.get_cmdline_user_args().has("--trace") and tutorial.room_index in [6,7] and frame < 100 and frame % 10 == 0:
			print("ROOM %d frame=%d pos=%s vel=%s" % [tutorial.room_index+1, frame, _local(), player.velocity])
		await _step()
	_release()
	_check(false, "Goal could not be reached; seen=%s" % [tutorial.seen.keys()])


func _grab(name: String) -> void:
	var object: Grabbable = _room().get_node(name)
	Input.action_press("move_right")
	for frame in 200:
		if player.global_position.distance_to(object.global_position) < player.grab_range + (object.collider.shape as RectangleShape2D).size.x * 0.5:
			break
		await _step()
	Input.action_release("move_right")
	Input.action_press("wall_grab")
	await _step(3)
	_check(player.get_held_object() == object, "Natural Grab acquires " + name)
	Input.action_press("move_right")


func _enter(index: int) -> void:
	_release()
	tutorial.call("_set_room", index, false)
	player.respawn()
	await _step(6)


func _test_retry() -> void:
	await _enter(9)
	var gate := _room().get_node("MovingGate")
	await _step(35)
	_check(gate.position.x > 340, "Moving gate advances")
	Input.action_press("reset")
	await _step()
	Input.action_release("reset")
	_check(absf(gate.position.x - 340) < 4, "Retry restores moving gate phase")
	await _enter(12)
	await _grab("Creature")
	_release()
	player.global_position.y = 800
	await _step(4)
	_check(player.get_held_object() == null and _local().x < 100, "Falling restores the current entrance and drops held state")
	var creature: Grabbable = _room().get_node("Creature")
	var rest_y := 640.0 - (creature.collider.shape as RectangleShape2D).size.y * 0.5
	_check(creature.position.distance_to(Vector2(170, rest_y)) < 5, "Falling restores full-size creature above the floor")


func _screenshots() -> void:
	tutorial.cleared.clear()
	tutorial.completed = false
	for index in range(4, 17):
		await _enter(index)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/tutorial/room_%d.png" % (index+1))


func _room() -> Node:
	return tutorial.rooms.get_child(tutorial.room_index)


func _local() -> Vector2:
	return player.global_position - Vector2(tutorial.room_index * 1280, 0)


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_EXTENSION: %s (room=%d pos=%s velocity=%s seen=%s)" % [message, tutorial.room_index+1, _local(), player.velocity, tutorial.seen.keys()])
