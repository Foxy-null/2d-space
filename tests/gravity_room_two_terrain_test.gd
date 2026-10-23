extends "res://tests/stage_3_test.gd"

var stick := 1.0
var negative_trials := 0
var superdash_trials := 0
var bumper_hits := 0


func _run() -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _fresh()
		await _capture("entrance")
		await _room_two_wall_course()
		await _capture("rest")
		await _finish()
		await _capture("cleared")
	else:
		await _positive_routes()
		if not failed:
			await _recoveries()
		if not failed and not OS.get_cmdline_user_args().has("--positive-only"):
			await _negative_routes()
	_release_inputs()
	print("GRAVITY_ROOM_TWO_TERRAIN_TEST_%s (%d checks, %d negative routes, %d actual Superdash)" % ["FAILED" if failed else "OK", checks, negative_trials, superdash_trials])
	quit(1 if failed else 0)


func _fresh() -> void:
	_release_inputs()
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	stage._set_room(1, false)
	player.respawn()
	await _step(4)
	actions.clear()
	flips.clear()
	respawns = 0
	bumper_hits = 0
	player.movement_action.connect(func(action): actions[action] = actions.get(action, 0) + 1)
	player.gravity_changed.connect(func(inverted): flips.append(-1 if inverted else 1))
	player.respawned.connect(func(): respawns += 1)
	stage.rooms.get_child(1).get_node("CeilingBumper").launched.connect(func(_body): bumper_hits += 1)


func _positive_routes() -> void:
	for first in [265, 280, 295]:
		for second in [540, 560, 580]:
			await _fresh()
			var started := Engine.get_physics_frames()
			await _room_two_wall_course(Vector2(first, second))
			await _finish()
			var seconds := float(Engine.get_physics_frames() - started) / 60.0
			_check(respawns == 0 and actions.get("wall_jump", 0) >= 3 and not actions.has("dash"), "The second room keeps a no-Dash wall-kick route without dying")
			_check(flips == [-1, 1] and bumper_hits > 0, "The ceiling gap, actual bumper and both gravity directions remain in the course")
			_check(seconds < 30.0, "The checkpoint interval stays below thirty seconds")
			print("ROOM_TWO_HEIGHTS_OK (%d/%d %.2fs)" % [first, second, seconds])
			if failed:
				return
	for strength in [0.65, 0.8]:
		stick = strength
		await _fresh()
		var started := Engine.get_physics_frames()
		await _room_two_wall_course()
		await _finish()
		_check(respawns == 0 and not actions.has("dash"), "Weaker horizontal stick input still crosses the room: %.2f" % strength)
		var seconds := float(Engine.get_physics_frames() - started) / 60.0
		_check(seconds < 30.0, "The weaker-input route also stays below thirty seconds")
		print("ROOM_TWO_WEAK_INPUT_OK (%.2f %.2fs)" % [strength, seconds])
		if failed:
			return
	stick = 1.0
	await _fresh()
	await _room_two_wall_course()
	var before := player.position
	await _step(180)
	_check(respawns == 0 and player.is_on_floor() and player.position.distance_to(before) < 2, "The inverted landing allows a three-second rest without input")
	_check(player.is_dash_ready() and player.get_wall_stamina() > 2.9, "The safe landing restores movement resources")
	await _finish()
	_check(respawns == 0, "A stopped player can resume through the bumper and the exit wall")
	_drive("move_right")
	await _until(func(): return stage.room_index == 2, 160, "The arrival opens the next room checkpoint")
	_release_inputs()
	await _step(25)
	await _retry()
	_check(stage.room_index == 2 and stage.cleared.has(1), "Retry keeps the next checkpoint and the cleared second room")


func _finish() -> void:
	_drive("move_right")
	if stick < 0.9:
		await _until(func(): return player.is_on_floor() and _x() > 940.0 - 360.0 * stick * 0.95, 120, "Jump from the safe underside when using weaker horizontal input")
		await _jump()
	await _until(func(): return bumper_hits > 0, 200, "The inverted course reaches the existing ceiling bumper")
	await _kick_gate(1060, 1, "", true)
	await _reach_goal()
	_check(stage.cleared.has(1) and stage.rooms.get_child(1).get_node("ReturnBridge").visible and not stage.rooms.get_child(1).get_node("ReturnBridge/Collision").disabled, "The arrival restores the return floor after the challenge")


func _recoveries() -> void:
	await _fresh()
	await _room_two_wall_course()
	await _retry()
	_check(stage.room_index == 1 and player.position.distance_to(Vector2(1352, 614)) < 4, "R from the safe landing restores the current entrance")
	await _fresh()
	_drive("move_right")
	await _until(func(): return respawns > 0, 240, "Walking into the actual ceiling gap causes a fall retry")
	_release_inputs()
	await _step(3)
	_check(stage.room_index == 1 and player.gravity_direction == 1 and player.is_dash_ready(), "A ceiling fall restores the second checkpoint and resources")
	await _fresh()
	await _room_two_wall_course()
	_drive("move_right")
	await _until(func(): return bumper_hits > 0, 200, "Reach the return gate before testing the open floor")
	await _kick_gate(1060, 1, "", true)
	_drive("move_left")
	await _until(func(): return respawns > 0, 220, "Walking from the exit floor into the central pit triggers a real fall")
	_release_inputs()
	await _step(3)
	_check(stage.room_index == 1 and not stage.cleared.has(1) and player.position.distance_to(Vector2(1352, 614)) < 4 and player.gravity_direction == 1 and player.is_dash_ready(), "The new floor pit restores the entrance without clearing the room")
	await _fresh()
	await _room_two_wall_course()
	_drive("move_left", true, true)
	await _until(func(): return respawns > 0, 180, "Climbing around the spiked wall tip retries the room")
	_release_inputs()
	await _step(3)
	_check(stage.room_index == 1 and player.position.distance_to(Vector2(1352, 614)) < 4 and player.gravity_direction == 1 and player.is_dash_ready(), "The visible tip hazard restores the entrance and gravity")


func _negative_routes() -> void:
	var directions := [Vector2.UP, Vector2(1, -1), Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1)]
	for jump_first in [false, true]:
		for delay in [0, 10, 20]:
			for direction in directions:
				await _fresh()
				if jump_first:
					await _jump()
				await _step(delay)
				await _dash(direction)
				_drive("move_right", true)
				await _observe(180)
				_check(_x() <= 250 or flips.has(-1) or stage.room_index != 1, "The entry corridor intercepts attempts to dash over or under Up gravity")
				_check(not stage.cleared.has(1), "The original normal-gravity climb does not reach the arrival")
				negative_trials += 1
	for setup in [0, 1, 2]:
		for delay in [0, 8, 16]:
			for direction in directions:
				await _fresh()
				await _cross_ceiling_pit(460, 560)
				if setup > 0:
					_drive("move_right", true, true)
					await _wait(func(): return player.is_wall_grabbing() and player.position.y > 315, 120)
				if setup == 2:
					_drive("move_left")
					await _step(18)
				await _step(delay)
				await _dash(direction)
				_drive("move_left", true, true)
				await _observe(130)
				_drive("move_right", true, true)
				await _observe(240)
				_check(actions.get("wall_jump", 0) == 0, "Negative traversal keeps wall actions enabled without pressing a wall kick")
				_check(not stage.cleared.has(1), "A single Dash and climbing cannot replace the inverted wall transfers (setup%d delay%d %s)" % [setup, delay, direction])
				negative_trials += 1
	for delay in [0, 3, 6]:
		await _fresh()
		Input.action_press("move_right")
		await _dash(Vector2.RIGHT)
		await _step(delay)
		await _jump()
		_drive("move_right", true, true)
		await _observe(400)
		if actions.has("superdash"):
			superdash_trials += 1
		_check(actions.get("wall_jump", 0) == 0 and not stage.cleared.has(1), "An actual ground Superdash does not replace the inverted course")
		negative_trials += 1
	_check(superdash_trials > 0, "The bypass fixtures include real Superdash actions")


func _observe(frames: int) -> void:
	for frame in frames:
		if respawns > 0 or stage.room_index != 1 or stage.cleared.has(1):
			return
		await _step()


func _wait(condition: Callable, frames: int) -> void:
	for frame in frames:
		if condition.call() or respawns > 0:
			return
		await _step()


func _dash(direction: Vector2) -> void:
	_release_inputs()
	if direction.x != 0:
		Input.action_press("move_left" if direction.x < 0 else "move_right")
	if direction.y != 0:
		Input.action_press("move_up" if direction.y < 0 else "move_down")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")


func _drive(direction: String, grab := false, inverted := false) -> void:
	_release_inputs()
	Input.action_press(direction, stick)
	if grab:
		Input.action_press("wall_grab")
		Input.action_press("move_down" if inverted else "move_up")


func _capture(label: String) -> void:
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/gravity-room-two")
	root.get_texture().get_image().save_png("res://docs/screenshots/gravity-room-two/%s.png" % label)
