extends "res://tests/stage_5_test.gd"

var bounces := 0
var jump_trials := 0


func _run() -> void:
	change_scene_to_file("res://scenes/stage_5.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	for room in stage.rooms.get_children():
		_check(not room.has_node("ExitLock"), "Reflection history never blocks a real exit")
		for bumper in room.get_node("Bumpers").get_children():
			bumper.launched.connect(func(_body): bounces += 1)
			bumper.monitoring = false
	await _step(2)
	var first := 18 if OS.get_cmdline_user_args().has("--wide-only") else (15 if OS.get_cmdline_user_args().has("--left-only") else 0)
	for index in range(first, stage.rooms.get_child_count()):
		stage.room_index = index
		stage._set_checkpoint()
		for launch_x in [90, 135, 170]:
			for delay in [0, 12, 24, 36, 48, 60]:
				for direction in [Vector2.ZERO, Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
					await _try_without_bumper(index, launch_x, delay, direction)
					jump_trials += 1
					if failed:
						return
		print("CANYON_NO_BUMPER_ROOM_%02d_OK" % (index + 1))
	stage.room_index = 8
	stage._set_checkpoint()
	for departure_delay in [0, 4, 8]:
		for delay in [36, 40, 44, 48, 52]:
			for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP]:
				await _try_wall_exit(departure_delay, delay, direction)
				if failed:
					return
	_check(bounces == 0, "No negative traversal received a bumper launch")
	_release_inputs()
	print("CANYON_REQUIRED_BUMPER_TEST_%s (%d checks, %d jump/Dash routes and 45 wall routes)" % ["FAILED" if failed else "OK", checks, jump_trials])
	quit(1 if failed else 0)


func _try_without_bumper(index: int, launch_x: int, delay: int, direction: Vector2) -> void:
	_release_inputs()
	player.respawn()
	await _step(3)
	var before := respawns
	var left: bool = stage.rooms.get_child(index).get_meta("exit_left", false)
	var forward := "move_left" if left else "move_right"
	Input.action_press(forward)
	while (float(stage.rooms.get_child(index).get_meta("room_width", 1280.0)) - _x() if left else _x()) < launch_x:
		await _step()
	Input.action_press("jump")
	for frame in 300:
		Input.action_release("dash")
		Input.action_release("move_up")
		Input.action_release("move_down")
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_press(forward)
		if frame == delay and direction != Vector2.ZERO:
			Input.action_release(forward)
			if direction.x != 0:
				Input.action_press("move_right" if direction.x > 0 else "move_left")
			if direction.y != 0:
				Input.action_press("move_down" if direction.y > 0 else "move_up")
			Input.action_press("dash")
		await _step()
		if respawns > before or stage.room_index != index or stage.completed:
			break
	_check(stage.room_index == index and not stage.transitioning and not stage.completed,
		"A jump/Dash cannot clear room %d without reflection (x%d delay%d %s)" % [index + 1, launch_x, delay, direction])


func _try_wall_exit(departure_delay: int, delay: int, direction: Vector2) -> void:
	_release_inputs()
	player.respawn()
	await _step(5)
	var before := respawns
	Input.action_press("move_right")
	for frame in 60:
		if _x() >= 135:
			break
		await _step()
	await _pulse("jump")
	await _step(12)
	Input.action_press("move_up")
	await _pulse("dash")
	Input.action_press("wall_grab")
	for frame in 240:
		if respawns > before or (player.is_on_floor() and _x() > 500):
			break
		await _step()
	_check(respawns == before and player.is_on_floor() and _x() > 500, "The bypass really reaches the intermediate wall without reflection")
	_release_inputs()
	await _step(5)
	Input.action_press("move_right")
	await _step(departure_delay)
	await _pulse("jump")
	for frame in 210:
		if frame == delay:
			_release_inputs()
			if direction.x > 0:
				Input.action_press("move_right")
			if direction.y < 0:
				Input.action_press("move_up")
			await _pulse("dash")
			Input.action_release("move_up")
			Input.action_press("move_right")
		Input.action_press("wall_grab")
		Input.action_press("move_up")
		await _step()
		if respawns > before or stage.room_index != 8:
			break
	_check(stage.room_index == 8 and not stage.transitioning,
		"The wall-top jump/Dash cannot climb the exit without reflection (departure%d delay%d %s)" % [departure_delay, delay, direction])


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)
