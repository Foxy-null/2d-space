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
	for index in [3, 9]:
		await _gravity_route(index)
		await _backtrack(index)
		await _missing_down_gate(index)
		await _gravity_bypasses(index)
	_release()
	tutorial.free()
	print("TUTORIAL_MOVEMENT_LEARNING_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _gravity_route(index: int) -> void:
	await _enter(index)
	if index == 9:
		await _walk_to(280)
		Input.action_release("move_right")
		await _step(15)
		_check(player.is_on_floor() and _local().x < 338, "The moving gate has a safe waiting ledge")
		await _step(90)
		_check(player.is_on_floor() and player.gravity_direction == 1, "Waiting for the gate does not require a jump or dash")
	Input.action_press("move_right")
	var used_ceiling := false
	var inverted := false
	for frame in 450:
		inverted = inverted or player.gravity_direction == -1
		used_ceiling = used_ceiling or (player.gravity_direction == -1 and player.is_on_floor() and _local().x > 500)
		if tutorial.cleared.has(index):
			break
		Input.action_release("jump")
		if player.gravity_direction == -1 and player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		if tutorial.call("_steps_done") and _local().x >= 1150:
			Input.action_release("move_right")
		await _step()
	_release()
	_check(inverted and used_ceiling, "Real gate contact makes the ceiling the route across the gap")
	_check(tutorial.cleared.has(index) and _room().get_node("Goal").is_pressed(), "Walking the gravity route presses the actual arrival switch")
	_check(player.gravity_direction == 1 and player.is_on_floor(), "The down gate returns the player to the exit floor")
	_check(player.is_dash_ready(), "The lesson does not require a dash")
	await _step(2)
	_check(_room().get_node("ExitBarrier/Collision").disabled, "The arrival switch opens the exit")


func _backtrack(index: int) -> void:
	_release()
	# A real playthrough has already opened the preceding room's exit.
	tutorial.cleared[index - 1] = true
	tutorial.call("_set_room", index - 1, false)
	player.respawn()
	await _step(3)
	tutorial.call("_set_room", index + 1, false)
	player.respawn()
	await _step(6)
	Input.action_press("move_left")
	for frame in 120:
		if tutorial.room_index == index and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(3)
	_check(tutorial.room_index == index and _local().x < 200 and player.is_on_floor(), "Entering from the next room lands at the safe left entrance")
	Input.action_press("reset")
	await _step()
	Input.action_release("reset")
	await _step(3)
	_check(_local().x < 200 and player.is_on_floor(), "Retry after backtracking keeps the safe checkpoint")
	Input.action_press("move_left")
	for frame in 120:
		if tutorial.room_index == index - 1 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == index - 1 and player.controls_enabled, "Walking left continues back to the preceding room")


func _missing_down_gate(index: int) -> void:
	await _enter(index)
	var gate: Area2D = _room().get_node("GateDown")
	gate.collision_mask = 0
	Input.action_press("move_right")
	var inverted := false
	var reached_exit_floor := false
	var retried := false
	for frame in 450:
		inverted = inverted or player.gravity_direction == -1
		reached_exit_floor = reached_exit_floor or (player.gravity_direction == 1 and player.is_on_floor() and _local().x > 1100)
		if inverted and _local().x < 100:
			retried = true
			break
		Input.action_release("jump")
		if player.gravity_direction == -1 and player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release()
	gate.collision_mask = 1
	_check(inverted and not reached_exit_floor, "The down gate is physically needed to land at the goal")
	_check(retried and player.gravity_direction == 1 and player.is_dash_ready(), "An inverted fall safely retries with restored gravity and dash")


func _gravity_bypasses(index: int) -> void:
	var gate: Area2D = tutorial.rooms.get_child(index).get_node("GateUp" if index == 3 else "MovingGate")
	gate.collision_mask = 0
	# Probe early/edge/coyote jumps, late dashes, and both upward dash directions.
	for jump_x in [280, 330, 380]:
		for delay in range(0, 49, 6):
			for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP]:
				await _enter(index)
				await _walk_to(jump_x)
				Input.action_press("jump")
				await _step()
				Input.action_release("jump")
				await _step(delay)
				if direction.y < 0:
					Input.action_press("move_up")
				if direction.x == 0:
					Input.action_release("move_right")
				Input.action_press("dash")
				await _step()
				Input.action_release("dash")
				Input.action_press("move_right")
				Input.action_press("wall_grab")
				Input.action_press("move_up")
				var reached_exit := false
				for frame in 100:
					reached_exit = reached_exit or _local().x >= 1082
					if _local().x < 100:
						break
					await _step()
				_check(not reached_exit, "Jump/dash/climb cannot touch the exit floor without gravity (jump=%d delay=%d direction=%s)" % [jump_x, delay, direction])
	gate.collision_mask = 1
	_release()


func _enter(index: int) -> void:
	_release()
	tutorial.cleared.erase(index)
	tutorial.call("_set_room", index, false)
	player.respawn()
	await _step(6)


func _walk_to(x: float) -> void:
	Input.action_press("move_right")
	for frame in 100:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Approach to the jump point timed out")


func _room() -> Node:
	return tutorial.rooms.get_child(tutorial.room_index)


func _local() -> Vector2:
	return player.global_position - Vector2(tutorial.room_index * 1280, 0)


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
		push_error("TUTORIAL_MOVEMENT_LEARNING: %s (room=%d pos=%s)" % [message, tutorial.room_index + 1, _local()])
