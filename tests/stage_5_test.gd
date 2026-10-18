extends SceneTree

var stage: Node2D
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var collected := 0
var actions: Dictionary = {}
var flips: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage5").pressed.emit()
	await _step(5)
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	player.gravity_changed.connect(func(up: bool): flips.append(-1 if up else 1))
	player.movement_action.connect(func(action: String): actions[action] = actions.get(action, 0) + 1)
	for room in stage.rooms.get_children():
		for item in room.find_children("*", "Area2D", true, false):
			if item.has_signal("collected"):
				item.collected.connect(func(_body): collected += 1)
	stage.rooms.get_child(6).get_node("ExitSpring").launched.connect(func(_body): actions["exit_spring"] = 1)
	stage.rooms.get_child(7).get_node("CeilingSpring").launched.connect(func(_body): actions["spring"] = 1)
	_check(stage.rooms.get_child_count() == 8 and stage.checkpoint_index == 0, "Eight rooms begin at checkpoint 1")
	_check(player.is_on_floor() and player.wall_actions_enabled and player.dash_enabled, "Safe start with existing abilities")
	_check(not stage.help_visible and not stage.hints_visible, "Help and hints start hidden")
	# Traverse the entire course using only real inputs, without teleporting or refilling abilities.
	for index in 8:
		var before := respawns
		actions.clear()
		flips.clear()
		_check(stage.room_index == index and stage.checkpoint_index == index - index % 2, "Checkpoints update only at rooms 1, 3, 5, 7")
		if OS.get_cmdline_user_args().has("--screenshots"):
			DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-5")
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-5/room_%d.png" % (index + 1))
		if index < 3:
			await _cross_pattern_room(index)
		elif index == 3:
			await _cross_air_room(index)
		else:
			await _cross_wall_room(index)
		_check(respawns == before, "Room %d crosses without a fall" % (index + 1))
		if index >= 2:
			_check(flips.has(-1) and flips.has(1), "Gravity route uses both directions")
		else:
			_check(flips.is_empty(), "Jump and Spring routes use normal gravity")
		if index >= 4:
			_check(actions.get("wall_jump", 0) >= [1, 4, 3, 5][index - 4], "Later rooms retain their wall-kick combinations")
		print("STAGE_5_ROOM_%d_OK (actions=%s, flips=%s)" % [index + 1, actions, flips])
		if index < 7:
			_drive("move_right")
			await _until(func(): return stage.room_index == index + 1, 160, "Move through the exit")
			_release_inputs()
			await _step(25)
			_check(not stage.transitioning and player.controls_enabled, "Controls resume after sliding")
			_check(stage.camera.position == Vector2((index + 1) * 1280 + 640, 360), "Camera settles on the correct room")
	_check(stage.completed and stage.get_node("HUD/Completion").visible, "Final arrival completes stage 5")
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-5/clear.png")
	_check(collected >= 7, "The course uses its dash and jump crystals")
	# R after completion must replay the last pair, including its physically pressed switches.
	await _key(KEY_R)
	_check(stage.room_index == 6 and stage.checkpoint_index == 6 and not stage.completed, "R returns to room 7 and resets final completion")
	_check(not stage.cleared.has(6) and not stage.cleared.has(7) and stage.cleared.has(5), "Retry resets both faces, keeping earlier pairs")
	for index in [6, 7]:
		var room: Node2D = stage.rooms.get_child(index)
		_check(not room.get_node("Goal").is_pressed() and room.get_node("Goal/Cap").position.y == 0, "Pressed arrival switches reset in both rooms")
		_check(not room.get_node("ExitBarrier/Collision").disabled and not room.get_node("ReturnBridge").visible, "Retry closes exits and keeps pits open")
	# Replay the pair through real inputs to verify the reset physical caps can be pressed again.
	for index in [6, 7]:
		var before := respawns
		actions.clear()
		await _cross_wall_room(index)
		_check(stage.cleared.has(index) and respawns == before, "A retried face is playable and its arrival can be pressed again")
		if index == 6:
			_drive("move_right")
			await _until(func(): return stage.room_index == 7, 160, "Replay the pair's second face")
			_release_inputs()
			await _step(25)
	_check(stage.completed, "The replayed final pair completes again")
	# Boundary/reset isolation: place the player in each even face and verify all retry paths.
	for checkpoint in [0, 2, 4, 6]:
		stage.checkpoint_index = checkpoint
		player.set_respawn_position(stage._spawn_position(checkpoint))
		player.respawn()
		stage._transition_to_next()
		await _step(25)
		_check(stage.room_index == checkpoint + 1 and stage.checkpoint_index == checkpoint, "Entering the second face does not save it")
		for y in [-100, 850]:
			player.position.y = y
			await _step(3)
			_check(stage.room_index == checkpoint and player.position.distance_to(stage._spawn_position(checkpoint)) < 20, "Both out-of-screen directions return to the pair's first face")
			_check(stage.camera.position == Vector2(checkpoint * 1280 + 640, 360), "Retry camera follows the saved checkpoint")
			_check(player.gravity_direction == 1 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "Retry restores gravity, dash and stamina")
			for room_index in [checkpoint, checkpoint + 1]:
				for item in stage.rooms.get_child(room_index).find_children("*", "Area2D", true, false):
					if item.has_signal("collected"):
						_check(item.visible, "Retry restores crystals in both faces")
			stage._transition_to_next()
			await _step(25)
		await _key(KEY_R)
		_check(stage.room_index == checkpoint, "R from the second face returns to the first")
		stage._transition_to_next()
		await _step(25)
		await _joy(JOY_BUTTON_START)
		_check(stage.room_index == checkpoint, "Start follows the same pair checkpoint")
	# Moving gates and the player pause together, and hints survive retries.
	stage._transition_to_next()
	await _step(25)
	await _key(KEY_H)
	var position_before := player.position
	var gate: Area2D = stage.rooms.get_child(7).get_node("MovingUpGate")
	var gate_before := gate.position
	await _step(30)
	_check(stage.help_visible and not player.controls_enabled and player.position == position_before and gate.position == gate_before, "Help pauses both player and moving gates")
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://.godot/stage5_help.png")
	stage.get_node("HUD/Help/Rows/Hints").button_pressed = true
	_check(stage.hints_visible and stage.get_node("HUD/Hint").visible, "Hints can be enabled")
	stage.get_node("HUD/Help/Rows/Retry").pressed.emit()
	await _step(3)
	_check(stage.room_index == 6 and player.controls_enabled and stage.hints_visible, "Menu retry returns to checkpoint and preserves hints")
	await _key(KEY_H)
	await _key(KEY_ESCAPE)
	_check(not stage.help_visible and current_scene == stage, "Escape closes help before leaving")
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Escape returns to stage selection")
	current_scene.get_node("Margin/Content/Stages/Stage5").pressed.emit()
	await _step(3)
	_check(current_scene.room_index == 0 and current_scene.checkpoint_index == 0 and current_scene.cleared.is_empty() and not current_scene.hints_visible, "Re-entry resets stage 5 progress and hints")
	current_scene._transition_to_next()
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Stage selection remains reachable during the camera slide")
	_release_inputs()
	current_scene.queue_free()
	await _step(3)
	OS.delay_msec(100)
	print("STAGE_5_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _cross_air_room(index: int) -> void:
	var crystal_index := 1
	var reached := false
	var room: Node2D = stage.rooms.get_child(index)
	for frame in 800:
		_release_inputs()
		if _x() > 1160 and player.is_on_floor():
			reached = true
			break
		var target := Vector2(index * 1280 + 1170, 470)
		if crystal_index > 6 and _x() < 1120:
			target = Vector2(index * 1280 + 1130, 450)
		if crystal_index <= 6:
			var crystal: Area2D = room.get_node("Items/Crystal%d" % crystal_index)
			if not crystal.visible or player.position.x > crystal.global_position.x + 38:
				crystal_index += 1
				continue
			target = crystal.global_position
		var difference: Vector2 = target - player.position
		if absf(difference.x) > 12:
			Input.action_press("move_right" if difference.x > 0 else "move_left")
		if player.is_on_floor() and crystal_index <= 6 and target.y < 550:
			Input.action_press("jump")
		if not player.is_on_floor() and not player.is_dashing() and player.is_dash_ready() and _x() < 1120 and absf(difference.x) < 165:
			if absf(difference.y) > absf(difference.x) * 0.42:
				Input.action_press("move_down" if difference.y > 0 else "move_up")
			Input.action_press("dash")
		await _step()
		if stage.room_index != index:
			break
	_release_inputs()
	_check(reached, "Air room %d must be traversable" % (index + 1))


func _land_at(x: float, limit := 160) -> void:
	for frame in limit:
		_release_inputs()
		if absf(_x() - x) > 8:
			Input.action_press("move_right" if _x() < x else "move_left")
		if player.is_on_floor() and absf(_x() - x) < 24:
			return
		await _step()
	_check(false, "Land on the next distinct platform at %s" % x)


func _cross_pattern_room(index: int) -> void:
	match index:
		0:
			for x in [290, 460, 630, 800, 970, 1170]:
				await _jump()
				await _land_at(x)
		1:
			_drive("move_right")
			await _until(func(): return player.velocity.y < -700, 60, "Launch from the entrance Spring")
			await _land_at(480)
			await _jump()
			_drive("move_right")
			await _until(func(): return player.is_air_jump_ready(), 90, "Collect the midair jump crystal")
			await _jump()
			await _land_at(860)
			await _jump()
			await _land_at(1170)
		2:
			_drive("move_right")
			await _step(8)
			await _jump()
			await _until(func(): return player.gravity_direction == -1, 70, "Enter the ceiling route")
			await _until(func(): return player.is_on_floor(), 90, "Land upside down on the long ceiling")
			_check(player.position.y < 250, "Ceiling route travels across the top of the room")
			await _until(func(): return player.gravity_direction == 1, 220, "Leave through the far Down gate")
			await _land_at(1170)
	_release_inputs()


func _cross_wall_room(index: int) -> void:
	match index:
		4:
			await _kick_gate(240, -1)
			await _cross_ceiling_pit(330, 470)
			_check(stage.get_node("HUD/Info").position.y == 616 and stage.get_node("HUD/HelpButton").position.y == 636, "Inverted HUD moves to the bottom of the screen")
			_check(not stage.rooms.get_child(4).get_node("CheckpointLabel").visible, "The inverted HUD does not overlap the entrance label")
			if OS.get_cmdline_user_args().has("--screenshots"):
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("res://.godot/stage5_inverted.png")
			_drive("move_right")
			await _until(func(): return player.is_on_floor() and _x() > 664 and _x() < 700, 200, "Reach the wide ceiling gap")
			await _jump()
			await _until(func(): return player.is_air_jump_ready() and _x() >= 870, 80, "Collect the shifted jump crystal")
			await _jump()
			await _until(func(): return player.gravity_direction == 1 and _x() > 1020, 120, "Air jump through the smaller return gate")
		5:
			await _kick_gate(280, -1)
			await _cross_ceiling_pit(320, 450)
			await _kick_gate(580, 1)
			_drive("move_right")
			await _until(func(): return player.is_on_floor() and _x() > 580, 120, "Reach the floor gap")
			await _jump()
			await _kick_gate(840, -1)
			await _cross_ceiling_pit(850, 1020)
			await _kick_gate(1100, 1, "DownGate")
		6:
			await _kick_gate(360, -1, "UpGate")
			await _cross_ceiling_pit(330, 470)
			await _kick_pair(true, 130)
			_drive("move_right")
			await _until(func(): return actions.has("exit_spring"), 150, "Reach the exit Spring")
			await _until(func(): return player.gravity_direction == 1, 120, "Spring reaches the smaller Down gate")
		7:
			await _kick_gate(260, -1)
			await _kick_pair(true, -10, true)
			await _kick_gate(960, -1, "MovingUpGate")
			await _cross_ceiling_pit(950, 1070)
			await _kick_gate(1110, 1, "DownGate")
	await _reach_goal()


func _cross_ceiling_pit(edge_x: int, end_x: int) -> void:
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() > edge_x - 36 and _x() < edge_x, 200, "Reach ceiling edge")
	_check(player.gravity_direction == -1, "Cross the ceiling gap while inverted")
	await _jump()
	await _until(func(): return player.is_on_floor() and _x() > end_x, 130, "Jump across the ceiling gap")


func _reach_goal() -> void:
	_drive("move_right")
	for frame in 320:
		if stage.cleared.has(stage.room_index):
			break
		Input.action_release("jump")
		if _x() >= 1140:
			Input.action_release("move_right")
		elif player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release_inputs()
	_check(stage.cleared.has(stage.room_index), "Physically press the arrival switch")


func _drive(direction: String, grab := false, inverted := false) -> void:
	_release_inputs()
	Input.action_press(direction)
	if grab:
		Input.action_press("wall_grab")
		Input.action_press("move_down" if inverted else "move_up")


func _jump() -> void:
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")


func _until(condition: Callable, limit: int, message: String) -> void:
	for frame in limit:
		if condition.call():
			return
		await _step()
	_check(false, message)


func _x() -> float:
	return player.position.x - stage.room_index * 1280


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _step(3)


func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _step(3)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _release_inputs() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("STAGE_5: %s (room=%d pos=%s gravity=%d)" % [message, stage.room_index + 1, player.position, player.gravity_direction])
		quit(1)


func _kick_pair(inverted: bool, shift: int, spring_launch := false) -> void:
	_drive("move_right")
	await _until(func(): return player.is_on_wall() and (spring_launch or player.is_on_floor()) and _x() > 500 + shift, 260, "Reach the inner wall")
	if not spring_launch:
		await _jump()
		await _step(10)
	_drive("move_left", true, inverted)
	var kick_height := 375 if spring_launch else 300
	var normal_kick_height := 350 if spring_launch else 420
	await _until(func(): return player.is_wall_grabbing() and (player.position.y > kick_height if inverted else player.position.y < normal_kick_height), 80, "Climb just below the higher overhang")
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _x() < 500 + shift and (player.position.y > 480 if inverted else player.position.y < 240), 130, "Kick onto the opposing wall")
	_drive("move_right", true, inverted)
	await _jump()
	Input.action_release("wall_grab")
	Input.action_release("move_up")
	Input.action_release("move_down")


func _kick_gate(wall_x: int, target: int, moving_gate: String = "", from_air := false) -> void:
	_drive("move_right")
	await _until(func(): return (from_air or player.is_on_floor()) and player.is_on_wall() and absf(_x() - (wall_x - 18)) < 4, 260, "Reach launch wall at x=%d" % wall_x)
	_check(player.gravity_direction != target, "The gate must be reached by the upcoming wall kick")
	var inverted := player.gravity_direction < 0
	_drive("move_left", true, inverted)
	var kick_y := 440 if wall_x >= 1000 else 280
	var climb_y := 480
	if stage.room_index == 5 and target < 0:
		climb_y = 540 if wall_x == 280 else 500
	await _until(func(): return player.is_wall_grabbing() and (player.position.y > kick_y if inverted else player.position.y < climb_y), 110, "Climb to the gate's height at x=%d" % wall_x)
	if not moving_gate.is_empty():
		Input.action_release("move_up")
		Input.action_release("move_down")
		var gate: Area2D = stage.rooms.get_child(stage.room_index).get_node(moving_gate)
		if gate.get("move_offset").x != 0:
			await _until(func(): return gate.position.x >= 1000 and gate.position.x <= 1030, 150, "Wait for the horizontal return gate")
		else:
			var low := 450 if target > 0 else 400
			await _until(func(): return gate.position.y >= low and gate.position.y <= low + 20 and gate.get("_toward_b"), 200, "Hold the wall until the small moving gate reaches the kick path")
	await _jump()
	Input.action_release("wall_grab")
	Input.action_release("move_up")
	Input.action_release("move_down")
	await _until(func(): return player.gravity_direction == target, 70, "A wall kick must enter the gravity gate")
	_drive("move_right")
