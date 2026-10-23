extends "res://tests/tutorial_rooms_test.gd"

var respawns := 0
var activated_without_history := false


func _run() -> void:
	for axis in [1.0, 0.85]:
		await _new_intro()
		_joy(axis)
		Input.action_press("wall_grab")
		Input.action_press("dash")
		await _step(180)
		_check(_on_body("LowStep") and player.is_on_floor() and respawns == 0, "Walking and the still-locked abilities cannot pass the first visible step")
		_check(not player.wall_actions_enabled and not player.dash_enabled and not tutorial.cleared.has(0), "The initial lesson really has only movement and jump available")
	for axis in [1.0, 0.85]:
		for pause in [0, 4, 8]:
			await _new_intro()
			var started := Engine.get_physics_frames()
			_joy(axis)
			var waiting := 0
			for frame in 700:
				if tutorial.room_index == 1:
					break
				Input.action_release("jump")
				if player.is_on_floor() and (player.is_on_wall() or (player.position.x > 700 and player.position.x < 760)):
					if waiting >= pause:
						Input.action_press("jump")
						waiting = 0
					else:
						waiting += 1
				else:
					waiting = 0
				if player.position.x > 1000:
					tutorial.seen.clear()
					tutorial._update_lesson()
				await _step()
			_release()
			await _step(20)
			_check(tutorial.room_index == 1 and tutorial.cleared.has(0) and respawns == 1 and activated_without_history, "Real jumps and the arrival press reach Room2 without a death or an action-history condition")
			_check(player.wall_actions_enabled and not player.dash_enabled and player.controls_enabled, "The next room still unlocks only wall actions")
			print("INTRO_ROUTE raw=%.2f pause=%d seconds=%.2f" % [axis, pause, (Engine.get_physics_frames() - started) / 60.0])
	_joy(-1)
	for frame in 120:
		if tutorial.room_index == 0 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(30)
	_check(tutorial.room_index == 0 and player.is_on_floor() and tutorial.cleared.has(0), "Backtracking from Room2 returns to a safe floor and preserves the real arrival")
	await _new_intro()
	_joy(1)
	for frame in 500:
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			if player.position.x > 800:
				break
			Input.action_press("jump")
		await _step()
	_check(_on_body("RecoveryFloor") and respawns == 0 and not tutorial.cleared.has(0), "Missing the gap lands safely on the lower recovery floor")
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")
	for frame in 100:
		if player.position.x > 930 and player.is_on_floor():
			break
		await _step()
	_release()
	_check(_on_body("ExitFloor") and respawns == 0, "An ordinary jump leaves the recovery floor and rejoins the exit platform")
	await _new_intro()
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")
	await _step(6)
	_check(not player.is_on_floor(), "The retry begins during an actual jump")
	Input.action_press("reset")
	await _step()
	_release()
	await _step(6)
	_check(player.position.distance_to(Vector2(72, 614)) < 3 and tutorial.seen.is_empty() and not tutorial.cleared.has(0), "R restores the unfinished entrance and clears temporary history")
	_check(not tutorial.get_node("Rooms/Room1/Goal").locked and not player.wall_actions_enabled and not player.dash_enabled, "Retry keeps the terrain-led arrival ready and the initial ability unlocks intact")
	_release()
	print("TUTORIAL_FIRST_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _new_intro() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	await _step(6)
	respawns = 0
	activated_without_history = false
	player.respawned.connect(func(): respawns += 1)
	var goal: ArrivalSwitch = tutorial.get_node("Rooms/Room1/Goal")
	goal.activated.connect(func(): activated_without_history = tutorial.seen.is_empty())
	_check(tutorial.STEPS[0].is_empty() and not goal.locked, "The first lesson relies on terrain rather than jump history")
	_check(tutorial.get_node("Rooms/Room1/MoveHint").visible and tutorial.get_node("Rooms/Room1/JumpHint").visible and not tutorial.get_node("Rooms/Room1").has_node("RecoveryHint"), "The first movement and jump buttons remain while a redundant arrow is removed")


func _joy(axis: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = axis
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release() -> void:
	_release_inputs()
	Input.action_release("reset")
	_joy(0)


func _on_body(body_name: String) -> bool:
	for index in player.get_slide_collision_count():
		if player.get_slide_collision(index).get_collider() == tutorial.get_node("Rooms/Room1/" + body_name):
			return true
	return false
