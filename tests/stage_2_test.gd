extends SceneTree

var checks := 0
var stage: Node2D
var player: PlayerController
var actions: Dictionary = {}
var refills := 0
var launches := 0
var inverted := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(3)
	stage = current_scene
	player = stage.player
	_check(stage.rooms.get_child_count() == 5, "Stage 2 has five rooms")
	_check(player.wall_actions_enabled and player.dash_enabled, "Wall actions and dash start available")
	_check(not stage.get_node("HUD/Margin/Panel/Rows/Objective").visible, "No tutorial mission checklist")
	_check(stage.get_node("HUD/ReturnToStageSelect").focus_mode == Control.FOCUS_NONE, "Jump cannot activate the mouse return button")
	player.movement_action.connect(func(action: String): actions[action] = actions.get(action, 0) + 1)
	player.gravity_changed.connect(func(up: bool): inverted = inverted or up)
	for area in stage.rooms.find_children("*", "Area2D", true, false):
		if area.has_signal("collected"):
			area.collected.connect(func(_body: PlayerController): refills += 1)
		if area.has_signal("launched"):
			area.launched.connect(func(_body: PlayerController): launches += 1)
	for index in 5:
		var goal: ArrivalSwitch = stage.rooms.get_child(index).get_node("Goal")
		_check(not goal.locked and goal.get_node("Bubble/Progress").text == "到着台", "Arrival switches begin ready without a 0/0 mission count")
		_check(not goal.get_node("Bubble").visible, "Mission bubbles do not cover the course's platforms")
		await _play_room(index)
		if index < 4:
			await _advance(index)
	_check(stage.completed and stage.get_node("HUD/Completion").visible, "The last physical switch completes the stage")
	_check(current_scene == stage and player.controls_enabled, "Completion keeps the stage playable")
	await _retry_and_backtrack()
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _screenshots()
	_release_inputs()
	print("STAGE_2_TEST_OK (%d checks)" % checks)
	quit()


func _play_room(index: int) -> void:
	var camera_position: Vector2 = stage.camera.position
	var refills_before := refills
	var launches_before := launches
	var dashes_before: int = actions.get("dash", 0)
	inverted = false
	var jumped := false
	var spring_dashed := false
	var goal: ArrivalSwitch = stage.rooms.get_child(index).get_node("Goal")
	Input.action_press("move_right")
	for frame in 600:
		Input.action_release("jump")
		Input.action_release("dash")
		var x := _local_x()
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		if index == 1:
			if not jumped and x >= 300 and player.is_on_floor():
				Input.action_press("jump")
				jumped = true
			if x >= 410 and x < 820 and player.is_dash_ready() and not player.is_dashing():
				Input.action_press("dash")
		elif index == 2:
			if not spring_dashed and x >= 380 and player.position.y < 440:
				Input.action_press("dash")
				spring_dashed = true
		elif index == 3:
			if x >= 190 and x < 570 and player.is_dash_ready() and not player.is_dashing():
				Input.action_press("dash")
		elif index == 4:
			if not spring_dashed and x >= 880 and player.position.y < 330:
				Input.action_press("dash")
				spring_dashed = true
		if player.position.x >= goal.global_position.x - 3:
			Input.action_release("move_right")
		if stage.cleared.has(index):
			break
		await _step()
	_release_inputs()
	_check(stage.cleared.has(index), "Actual movement reaches and presses room %d's arrival switch" % (index + 1))
	_check(stage.camera.position == camera_position, "Camera stays fixed while solving a room")
	_check(player.gravity_direction == 1, "Each goal is reachable with down gravity")
	_check(stage.rooms.get_child(index).get_node("ExitBarrier/Collision").disabled, "Pressing the arrival switch opens the physical exit")
	if index in [0, 3, 4]:
		_check(inverted, "The course uses an actual up gravity gate")
	if index in [1, 4]:
		_check(refills > refills_before, "The course collects an actual dash crystal")
	if index in [2, 4]:
		_check(launches > launches_before, "The course launches from an actual Spring")
	if index in [1, 2, 3, 4]:
		_check(actions.get("dash", 0) > dashes_before, "The course uses real dash input")
	if index == 1:
		_check(actions.get("dash", 0) - dashes_before >= 2, "Refill permits consecutive airborne dashes")


func _advance(index: int) -> void:
	Input.action_press("move_right")
	for frame in 70:
		if stage.transitioning:
			break
		await _step()
	_check(stage.transitioning and not player.controls_enabled, "Exit freezes controls during the camera slide")
	_release_inputs()
	await _step(40)
	_check(stage.room_index == index + 1 and player.controls_enabled, "Next room resumes controls")
	_check(player.gravity_direction == 1 and player.is_dash_ready() and not player.is_air_jump_ready(), "Room entry resets gravity and jump/dash resources")
	_check(stage.camera.position == Vector2((index + 1) * 1280 + 640, 360), "Camera settles on the next room")


func _retry_and_backtrack() -> void:
	var saved_cleared: Dictionary = stage.cleared.duplicate()
	var room: Node2D = stage.rooms.get_child(4)
	var crystal: Area2D = room.get_node("DashCrystal")
	crystal.emit_signal("body_entered", player)
	player.set_gravity_direction(-1)
	player.grant_air_jump()
	Input.action_press("reset")
	await _step()
	_release_inputs()
	await _step(3)
	_check(stage.room_index == 4 and _local_x() < 100, "R retries the current room's entrance")
	_check(player.gravity_direction == 1 and player.is_dash_ready() and not player.is_air_jump_ready(), "Retry restores down gravity and starting resources")
	_check(is_equal_approx(player.get_wall_stamina(), player.wall_stamina_max) and crystal.visible, "Retry restores stamina and crystals immediately")
	_check(stage.cleared == saved_cleared and room.get_node("Goal").is_pressed(), "Retry keeps pressed arrival switches and cleared rooms")
	player.position.y = 800
	await _step(3)
	_check(stage.room_index == 4 and player.position.y < 720 and _local_x() < 100, "Falling below the screen retries the same room")
	player.set_gravity_direction(-1)
	player.position.y = -60
	await _step(3)
	_check(player.gravity_direction == 1 and _local_x() < 100, "Falling above the screen also retries with down gravity")
	Input.action_press("move_left")
	for frame in 50:
		if stage.transitioning:
			break
		await _step()
	_release_inputs()
	await _step(40)
	_check(stage.room_index == 3 and _local_x() > 1200, "Walking left returns to the previous room's right entrance")
	_check(stage.completed and not stage.get_node("Rooms/Room4/ExitBarrier/Visual").visible, "Completion and open exits persist when backtracking")
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Esc returns to stage selection")
	current_scene.call("_start_stage_2")
	await _step(3)
	stage = current_scene
	player = stage.player
	_check(stage.room_index == 0 and stage.cleared.is_empty() and not stage.completed, "Re-selecting stage 2 starts a fresh run")
	# Returning to the entrance during a partial press must not finish it remotely.
	var goal: ArrivalSwitch = stage.rooms.get_child(0).get_node("Goal")
	player.position = goal.global_position + Vector2(0, -120)
	player.velocity = Vector2.ZERO
	for frame in 60:
		if goal.pressing:
			break
		await _step()
	_check(goal.pressing and not goal.is_pressed(), "A partial physical press is observable before completion")
	Input.action_press("reset")
	await _step()
	_release_inputs()
	await _step(20)
	_check(not goal.pressing and not goal.is_pressed() and stage.cleared.is_empty(), "Retry cancels a partial press and keeps the exit closed")
	_check(is_zero_approx(goal.cap.position.y), "An unpressed arrival switch returns to its starting height")
	stage.call("_transition_to", 1)
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_BACK
	back.pressed = true
	Input.parse_input_event(back)
	await _step(3)
	back.pressed = false
	Input.parse_input_event(back)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Back returns even during a camera transition")


func _screenshots() -> void:
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(3)
	stage = current_scene
	player = stage.player
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-2")
	for index in 5:
		stage.call("_set_room", index, false)
		player.respawn()
		await _step(3)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-2/room_%d.png" % (index + 1))


func _local_x() -> float:
	return player.position.x - stage.room_index * 1280


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
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
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("STAGE_2: " + message + " (room=%d pos=%s)" % [stage.room_index + 1, player.position])
		quit(1)
		assert(condition, message)
