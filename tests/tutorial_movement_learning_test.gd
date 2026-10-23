extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0
var actions: Array[String] = []
var respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for index in [3, 9]:
		for pause in ([0] if index == 3 else [0, 30, 105, 210]):
			await _new_world()
			await _gravity_route(index, pause)
		await _backtrack(index)
		await _missing_down_gate(index)
		await _inverted_retry(index)
		await _gravity_bypasses(index)
		await _advanced_bypasses(index)
	_release()
	tutorial.free()
	print("TUTORIAL_MOVEMENT_LEARNING_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _gravity_route(index: int, pause: int = 105) -> void:
	await _enter(index)
	var started := Engine.get_physics_frames()
	if index == 9:
		await _walk_to(110)
		Input.action_release("move_right")
		await _step(pause)
		_check(player.is_on_floor() and _local().x < 142, "The moving gate has a safe waiting ledge")
		_check(player.is_on_floor() and player.gravity_direction == 1, "Waiting for the gate does not require a jump or dash")
	Input.action_press("move_right")
	var used_ceiling := false
	var inverted := false
	var history_cleared := false
	for frame in 450:
		inverted = inverted or player.gravity_direction == -1
		used_ceiling = used_ceiling or (player.gravity_direction == -1 and player.is_on_floor() and _local().x > 500)
		if inverted and player.gravity_direction == 1 and not history_cleared:
			_check(not tutorial.cleared.has(index) and not _room().get_node("ExitBarrier/Collision").disabled, "The exit stays closed before physical arrival even after both gate contacts")
			tutorial.seen.clear()
			tutorial._update_lesson()
			history_cleared = true
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
	_check(respawns == 0, "The gravity route reaches arrival without a retry")
	_check(tutorial.cleared.has(index) and _room().get_node("Goal").is_pressed(), "Walking the gravity route presses the actual arrival switch")
	_check(player.gravity_direction == 1 and player.is_on_floor(), "The down gate returns the player to the exit floor")
	_check(player.is_dash_ready() and not actions.has("dash"), "The lesson does not require a dash")
	_check(history_cleared and not tutorial.seen.has("up") and not tutorial.seen.has("down"), "Actual arrival opens the exit after both gravity history records have been removed")
	var seconds := (Engine.get_physics_frames() - started) / 60.0
	_check(seconds <= 30, "The gravity room stays below thirty seconds including the observation pause")
	print("TUTORIAL_GRAVITY_SECONDS room=%d pause=%d seconds=%.2f" % [index + 1, pause, seconds])
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
	for jump_x in [280, 330, 380]:
		for delay in range(0, 49, 6):
			for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
				await _enter(index)
				await _walk_to(jump_x)
				await _pulse("jump")
				_check(not await _try_exit(delay, direction), "Jump/coyote/eight-way dash cannot touch the exit without gravity: jump=%d delay=%d direction=%s" % [jump_x, delay, direction])
	gate.collision_mask = 1
	_release()


func _new_world() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.movement_action.connect(func(action: String): actions.append(action))
	player.respawned.connect(func(): respawns += 1)
	await _step(5)


func _inverted_retry(index: int) -> void:
	await _enter(index)
	Input.action_press("move_right")
	for frame in 180:
		if player.gravity_direction == -1: break
		await _step()
	_check(player.gravity_direction == -1, "The retry begins after a real upward gate contact")
	await _pulse("reset")
	_release()
	await _step(6)
	_check(player.is_on_floor() and _local().distance_to(Vector2(72, 614)) < 2 and player.gravity_direction == 1 and player.is_dash_ready() and tutorial.seen.is_empty(), "R during inversion restores the entrance, resources and gravity without completing the room")
	if index == 9:
		var gate: Area2D = _room().get_node("MovingGate")
		_check(gate.position.distance_to(gate._initial_position) < 12, "Retry restarts the moving gate near its entrance endpoint")


func _advanced_bypasses(index: int) -> void:
	var gate: Area2D = _room().get_node("GateUp" if index == 3 else "MovingGate")
	gate.collision_mask = 0
	for launch in [72, 180, 240]:
		for wait in [0, 2, 4]:
			await _enter(index)
			await _walk_to(launch)
			await _pulse("dash")
			await _step(wait)
			await _pulse("jump")
			var reached := await _try_exit(-1, Vector2.RIGHT)
			_check(actions.has("superdash") and not reached, "A real ground superdash cannot replace gravity: launch=%d wait=%d" % [launch, wait])
	for height in [660, 700, 738]:
		for delay in [0, 12, 24, 36, 48]:
			for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP]:
				await _enter(index)
				Input.action_press("move_right", 0.2)
				for frame in 400:
					if _local().x >= 339.2: break
					await _step()
				_aim(Vector2.LEFT)
				Input.action_press("wall_grab")
				for frame in 60:
					await _step()
					if player.is_wall_grabbing() and not player.is_on_floor(): break
				Input.action_press("move_down")
				for frame in 80:
					if _local().y >= height: break
					await _step()
				_check(player.is_wall_grabbing() and respawns == 0 and tutorial.room_index == index, "The wall-kick bypass starts on the real entrance face")
				_aim(Vector2.RIGHT)
				Input.action_release("wall_grab")
				await _pulse("jump")
				var reached := await _try_exit(delay, direction)
				_check(actions.has("wall_jump") and not reached, "A real wall kick plus dash cannot replace gravity: height=%d delay=%d direction=%s" % [height, delay, direction])
	gate.collision_mask = 1
	_release()


func _try_exit(delay: int, direction: Vector2) -> bool:
	var reached := false
	var index: int = tutorial.room_index
	for frame in 160:
		if frame == delay:
			_aim(direction)
			await _pulse("dash")
			_aim(Vector2.RIGHT)
		Input.action_press("wall_grab")
		Input.action_press("move_up")
		await _step()
		reached = reached or _local().x >= 1082
		if respawns > 0 or tutorial.room_index != index: break
	return reached


func _aim(direction: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if direction.x != 0: Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0: Input.action_press("move_down" if direction.y > 0 else "move_up")


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _enter(index: int) -> void:
	_release()
	tutorial.cleared.erase(index)
	tutorial.call("_set_room", index, false)
	player.respawn()
	await _step(6)
	actions.clear()
	respawns = 0


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
