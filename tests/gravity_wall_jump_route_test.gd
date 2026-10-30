extends "res://tests/stage_3_test.gd"

var negative_trials := 0
var superdash_trials := 0


func _run() -> void:
	await _fresh_room()
	if OS.get_cmdline_user_args().has("--visual-only"):
		await _screenshot("entry")
		await _room_one_wall_course(true)
		await _screenshot("cap")
		await _reach_goal()
		await _screenshot("arrival")
	else:
		if not OS.get_cmdline_user_args().has("--negative-only"):
			await _positive_routes()
			if not failed:
				await _recovery()
		if not failed:
			await _fresh_room()
			await _negative_routes()
	print("GRAVITY_WALL_JUMP_ROUTE_TEST_%s (%d checks, %d negative routes)" % ["FAILED" if failed else "OK", checks, negative_trials])
	quit(1 if failed else 0)


func _fresh_room() -> void:
	_release_inputs()
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	actions.clear()
	flips.clear()
	respawns = 0
	player.movement_action.connect(func(action: String): actions[action] = actions.get(action, 0) + 1)
	player.gravity_changed.connect(func(inverted: bool): flips.append(-1 if inverted else 1))
	player.respawned.connect(func(): respawns += 1)
	for spring_name in ["LaunchSpring", "ReturnSpring"]:
		stage.rooms.get_child(0).get_node(spring_name).launched.connect(func(_body): actions[spring_name] = actions.get(spring_name, 0) + 1)


func _positive_routes() -> void:
	for first in [540, 552, 564]:
		for third in [316, 332, 348]:
			await _fresh_room()
			var started := Engine.get_physics_frames()
			await _room_one_wall_course(false, Vector4(first, 440, third, 78))
			await _reach_goal()
			var seconds := float(Engine.get_physics_frames() - started) / 60.0
			_check(stage.cleared.has(0) and respawns == 0, "Varied kick heights reach the real arrival without a retry")
			_check(actions.get("wall_jump", 0) >= 1 and not actions.has("dash"), "The regular route uses wall kicks without Dash")
			_check(actions.has("LaunchSpring") and actions.has("ReturnSpring") and flips.has(-1) and flips.has(1), "Both Springs and both gravity directions remain in the route")
			_check(seconds < 30.0, "The room remains a short retry")
			print("GRAVITY_KICK_ROUTE_OK (first=%d, third=%d, %.2fs)" % [first, third, seconds])
			if failed:
				return
	for second in [432, 440, 448]:
		for final in [68, 78, 88]:
			await _fresh_room()
			await _room_one_wall_course(false, Vector4(548, second, 332, final))
			await _reach_goal()
			_check(stage.cleared.has(0) and respawns == 0 and not actions.has("dash"), "Middle and final kicks also allow different takeoff heights")
			if failed:
				return


func _recovery() -> void:
	await _fresh_room()
	_drive("move_right", true)
	await _until(func(): return player.is_wall_grabbing() and player.position.y < 481, 240, "Observe the first overhang while safely gripping below it")
	_release_inputs()
	await _until(func(): return player.is_on_floor(), 160, "A missed first transfer falls onto the continuous safe floor")
	_check(respawns == 0, "The observation grip can be abandoned safely")
	await _retry()
	await _room_one_wall_course(true)
	var before := respawns
	_drive("move_left")
	await _until(func(): return respawns > before, 150, "Falling onto a spiked cap retries the current room")
	_check(stage.room_index == 0 and player.position.distance_to(Vector2(72, 614)) < 20, "Spikes return to the entrance, not inside a wall")
	_check(player.gravity_direction == 1 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "Spike recovery restores gravity and movement resources")
	await _retry()
	await _room_one_wall_course(true)
	var before_departure := respawns
	_release_inputs()
	await _step(60)
	await _reach_goal()
	_check(respawns == before_departure, "Stopping on the final wall and walking onward does not cause another fall")
	_drive("move_right")
	await _until(func(): return stage.room_index == 1, 160, "The cleared room still opens its next-room checkpoint")
	_release_inputs()
	await _step(25)
	await _retry()
	_check(stage.room_index == 1 and player.global_position.x > 1280 and stage.cleared.has(0), "Retry preserves the next room and the opened first exit")


func _negative_routes() -> void:
	var directions := [Vector2.UP, Vector2(1, -1), Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1)]
	var first_setup := 0
	var last_setup := 8
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="):
			first_setup = int(arg.trim_prefix("--from="))
		elif arg.begins_with("--to="):
			last_setup = int(arg.trim_prefix("--to="))
	if first_setup == 0:
		await _retry()
		actions.clear()
		_drive("move_right", true)
		await _step(400)
		_check(actions.get("wall_jump", 0) == 0 and not actions.has("dash"), "Recheck the original climb-only bypass with real input")
		_check(_x() < 640 and not stage.cleared.has(0), "The original climb-only route now stops below the first overhang")
	for setup in range(first_setup, last_setup):
		for delay in [0, 6, 12, 18]:
			for direction in directions:
				for continuation in 2:
					await _try_bypass(setup, delay, direction, continuation)
					if failed:
						return
		print("GRAVITY_NO_KICK_SETUP_%d_OK (%d negative routes, %d Superdash)" % [setup, negative_trials, superdash_trials])
	if first_setup <= 7 and last_setup > 7:
		_check(superdash_trials > 0, "The ground Dash fixtures include real Superdash actions")


func _try_bypass(setup: int, delay: int, direction: Vector2, continuation: int) -> void:
	await _retry()
	actions.clear()
	flips.clear()
	_drive("move_right")
	match setup:
		0:
			await _until(func(): return player.is_on_wall() and _x() > 600, 240, "Dash during the first wall approach")
		1:
			_drive("move_right", true)
			await _until(func(): return player.is_wall_grabbing() and player.position.y < 481, 240, "Climb as high as the first overhang permits")
		2:
			await _until(func(): return _x() > 475, 150, "Dash just after the Spring launch")
		3:
			await _until(func(): return _x() > 530, 160, "Dash in the open center of the chimney")
		4:
			await _until(func(): return _x() > 365, 140, "Try an ordinary ground jump before the hanging wall")
			await _jump()
		5:
			await _until(func(): return _x() > 450, 150, "Approach the left wall from the Spring")
			_release_inputs()
			await _until(func(): return player.position.y < 495, 60, "Let the Spring reach the underside of the left grip")
			_drive("move_left", true)
			await _until(func(): return player.is_wall_grabbing() and _x() > 440 and _x() < 470, 100, "Grab the left wall without kicking")
			await _until(func(): return player.position.y < 375, 120, "Climb below the left overhang before spending Dash")
		6, 7:
			await _until(func(): return _x() > 540, 160, "Set up an ordinary jump or ground Dash inside the chimney")
			_release_inputs()
			await _until(func(): return player.is_on_floor(), 180, "Land away from the Spring before jumping")
			if setup == 6:
				await _jump()
	await _step(delay)
	_release_inputs()
	_press_direction(direction)
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	if setup == 7 and player.is_on_floor():
		await _jump()
	var before := respawns
	_drive("move_right" if continuation == 0 else "move_left", true)
	for frame in 190:
		await _step()
		if respawns > before:
			break
		if continuation == 1 and (player.position.y < -35 or frame == 100):
			_drive("move_right")
		if _x() > 920 or stage.cleared.has(0):
			break
	_check(actions.get("wall_jump", 0) == 0, "The bypass keeps wall climbing and Dash enabled but performs no wall kick")
	_check(_x() <= 920 and not stage.cleared.has(0), "No sampled wall-kick-free route crosses the chimney (setup=%d delay=%d direction=%s continuation=%d)" % [setup, delay, direction, continuation])
	if actions.has("superdash"):
		superdash_trials += 1
	negative_trials += 1


func _press_direction(direction: Vector2) -> void:
	if direction.x != 0:
		Input.action_press("move_left" if direction.x < 0 else "move_right")
	if direction.y != 0:
		Input.action_press("move_up" if direction.y < 0 else "move_down")


func _screenshot(label: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/gravity-wall-jump-%s.png" % label)
