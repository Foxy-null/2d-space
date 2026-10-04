extends SceneTree

var failed := false
var checks := 0
var stage: Node2D
var player: PlayerController
var actions: Dictionary = {}
var flips: Array[int] = []
var respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "Keyboard selection must start stage 2")
	stage = current_scene
	player = stage.player
	player.movement_action.connect(func(action: String): actions[action] = actions.get(action, 0) + 1)
	player.gravity_changed.connect(func(inverted: bool): flips.append(-1 if inverted else 1))
	player.respawned.connect(func(): respawns += 1)
	_check(stage.rooms.get_child_count() == 6, "Stage 2 has six rooms")
	_check(player.wall_actions_enabled and player.dash_enabled, "Walls and dash are available from the start")
	for room in stage.rooms.get_children():
		var goal: ArrivalSwitch = room.get_node("Goal")
		_check(not goal.locked and not goal.get_node("Bubble").visible, "Goals are unlocked without tutorial counters")
		_check(not goal.get_node("UnlockSound").playing, "Starting a room must not play an unlock chime")
	var bridge: StaticBody2D = stage.rooms.get_child(4).get_node("ReturnBridge")
	_check(not bridge.visible and bridge.get_node("Collision").disabled, "The first moving-gate challenge keeps its gap")
	var camera_position: Vector2 = stage.camera.position
	Input.action_press("move_right")
	Input.action_press("dash")
	await _step()
	_check(player.is_dashing(), "Dash remains usable as assistance")
	_release_inputs()
	await _step(12)
	_check(stage.camera.position == camera_position, "The room camera remains fixed while moving")
	await _retry()
	for index in 6:
		if index >= 2:
			await _fall_into_pit([0, 0, 350, 620, 470, 340][index])
		actions.clear()
		flips.clear()
		var respawns_before := respawns
		match index:
			0:
				await _kick_pair(false, 0)
			1:
				await _kick_pair(true, 0)
			2:
				await _kick_gate(240, -1)
				await _kick_pair(true, 130)
			3:
				await _kick_gate(280, -1)
				await _kick_gate(580, 1)
				_drive("move_right")
				await _until(func(): return player.is_on_floor() and _x() > 580, 120, "Reach the edge before the floor pit")
				await _jump()
				await _kick_gate(840, -1)
			4:
				await _kick_gate(360, -1, "UpGate")
				await _kick_pair(true, 130)
			5:
				await _kick_gate(260, -1)
				await _kick_pair(true, -10)
				await _kick_gate(960, -1, "MovingUpGate")
		if index > 0:
			await _kick_gate([0, 1060, 1060, 1100, 1060, 1110][index], 1)
		if failed:
			quit(1)
			return
		await _reach_goal()
		_check(stage.cleared.has(index), "Actual arrival must clear room %d" % (index + 1))
		_check(respawns == respawns_before, "The no-dash route crosses room %d without falling" % (index + 1))
		if index >= 2:
			var room: Node2D = stage.rooms.get_child(index)
			_check(room.get_node("ReturnBridge").visible and not room.get_node("ReturnBridge/Collision").disabled and not room.get_node("PitWarning").visible, "Clearing the room fills its pit and hides its warning")
		_check(actions.get("wall_jump", 0) >= [2, 3, 4, 4, 4, 5][index], "The harder route uses chained wall kicks in room %d" % (index + 1))
		_check(not actions.has("dash"), "Room %d can be completed without dash" % (index + 1))
		if index > 0:
			_check(flips.has(-1) and flips.has(1), "Room %d uses both gravity directions" % (index + 1))
		if index in [3, 5]:
			_check(flips.count(-1) >= 2 and flips.count(1) >= 2, "Later rooms combine repeated flips")
		if failed:
			quit(1)
			return
		print("STAGE_2_ROOM_%d_OK (wall kicks=%d, flips=%s)" % [index + 1, actions.get("wall_jump", 0), flips])
		if index < 5:
			Input.action_press("move_right")
			await _until(func(): return stage.room_index == index + 1, 150, "Cross the open exit")
			_check(stage.transitioning and not player.controls_enabled, "Camera slides freeze controls")
			_release_inputs()
			await _step(25)
			_check(not stage.transitioning and player.controls_enabled, "Controls resume after the camera slide")
			_check(stage.camera.position == Vector2((index + 1) * 1280 + 640, 360), "Camera settles on the next room")
	_check(stage.completed and stage.get_node("HUD/Completion").visible, "Final arrival displays completion without leaving the stage")
	if OS.get_cmdline_user_args().has("--screenshots"):
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-2")
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-2/clear.png")
	await _retry()
	_check(stage.completed and stage.rooms.get_child(5).get_node("Goal").is_pressed(), "Retry keeps cleared goals and completion")
	player.set_gravity_direction(-1)
	player.global_position.y = -60
	await _step(3)
	_check(player.gravity_direction == 1 and player.position.y > 0, "Inverted falls reset to the current entrance")
	player.global_position.y = 800
	await _step(3)
	_check(stage.room_index == 5 and player.global_position.y < 720, "Falling below the screen retries the current room")
	player.global_position.x = 5 * 1280 - 5
	await _step(25)
	_check(stage.room_index == 4 and player.position.x > 4 * 1280 + 1200, "Backtracking uses the right entrance")
	_check(bridge.visible and not bridge.get_node("Collision").disabled, "Backtracking preserves the return bridge")
	_check(stage.completed and stage.cleared.size() == 6 and not stage.get_node("HUD/Completion").visible, "Backtracking preserves cleared rooms without a completion overlay")
	await _retry()
	_check(player.position.x > 4 * 1280 + 1200, "Retry after backtracking keeps the right entrance")
	var gate: Area2D = stage.rooms.get_child(4).get_node("UpGate")
	await _step(30)
	_check(gate.position != gate.get("_initial_position"), "Moving gates actually travel")
	await _retry()
	_check(gate.position.distance_to(gate.get("_initial_position")) < 5, "Retry resets the moving gate")
	_drive("move_left")
	for frame in 180:
		if _x() < 820 and player.is_on_floor():
			break
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_check(stage.room_index == 4 and _x() < 820 and player.is_on_floor(), "Backtrack over the arrival switch onto the return bridge")
	_drive("move_right")
	await _until(func(): return _x() > 1055, 100, "Walk under the exit landing without getting stuck")
	_check(player.is_on_floor(), "The return bridge provides room below the exit landing")
	_release_inputs()
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Escape returns to the stage menu")
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	stage = current_scene
	player = stage.player
	_check(stage.room_index == 0 and stage.cleared.is_empty() and not stage.completed, "Re-selecting stage 2 starts fresh")
	_check(stage.get_node("HUD/ReturnToStageSelect").focus_mode == Control.FOCUS_NONE, "Jump cannot focus the return button")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _screenshots()
	stage.get_node("HUD/ReturnToStageSelect").pressed.emit()
	await _step(3)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "The return button opens stage selection")
	_release_inputs()
	print("STAGE_2_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _fall_into_pit(edge_x: int) -> void:
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	_check(not room.get_node("ReturnBridge").visible and room.get_node("ReturnBridge/Collision").disabled and room.get_node("PitWarning").visible, "A fresh room has an open and marked pit")
	_release_inputs()
	player.global_position = room.to_global(Vector2(edge_x - 24, 614))
	await _step(3)
	var respawns_before := respawns
	_drive("move_right")
	await _until(func(): return respawns > respawns_before, 180, "Walking into the actual pit must trigger a fall retry")
	_release_inputs()
	await _step(2)
	_check(stage.room_index == room.get_index() and player.global_position.distance_to(room.get_node("Spawn").global_position) < 20, "A pit fall returns to the current entrance")
	_check(player.gravity_direction == 1 and player.is_dash_ready() and player.get_wall_stamina() > 2.9 and not stage.cleared.has(stage.room_index), "A pit fall restores resources without clearing the room")
	for gate in room.find_children("*", "Area2D", true, false):
		if gate.get("moving_enabled") == true:
			_check(gate.position.distance_to(gate.get("_initial_position")) < 10, "A pit fall restarts its moving gate")


func _kick_pair(inverted: bool, shift: int) -> void:
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and player.is_on_wall() and _x() > 500 + shift, 260, "Reach the inner wall")
	await _jump()
	await _step(10)
	_drive("move_left", true, inverted)
	await _until(func(): return player.is_wall_grabbing() and (player.position.y > 300 if inverted else player.position.y < 420), 80, "Climb just below the higher overhang")
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _x() < 500 + shift and (player.position.y > 480 if inverted else player.position.y < 240), 130, "Kick onto the opposing wall")
	_drive("move_right", true, inverted)
	await _jump()
	Input.action_release("wall_grab")
	Input.action_release("move_up")
	Input.action_release("move_down")


func _kick_gate(wall_x: int, target: int, moving_gate: String = "") -> void:
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and player.is_on_wall() and absf(_x() - (wall_x - 18)) < 4, 260, "Reach launch wall at x=%d" % wall_x)
	_check(player.gravity_direction != target, "The gate must be reached by the upcoming wall kick")
	var inverted := player.gravity_direction < 0
	_drive("move_left", true, inverted)
	var kick_y := 440 if wall_x >= 1000 else 280
	await _until(func(): return player.is_wall_grabbing() and (player.position.y > kick_y if inverted else player.position.y < 480), 110, "Climb to the gate's height at x=%d" % wall_x)
	if not moving_gate.is_empty():
		Input.action_release("move_up")
		var gate: Area2D = stage.rooms.get_child(stage.room_index).get_node(moving_gate)
		await _until(func(): return gate.position.y >= 400 and gate.position.y <= 430 and gate.get("_toward_b"), 200, "Hold the wall until the small moving gate reaches the kick path")
	await _jump()
	Input.action_release("wall_grab")
	Input.action_release("move_up")
	Input.action_release("move_down")
	await _until(func(): return player.gravity_direction == target, 70, "A wall kick must enter the gravity gate")
	_drive("move_right")


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
	_check(stage.cleared.has(stage.room_index), "Reach and physically press the arrival switch")


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


func _retry() -> void:
	_release_inputs()
	Input.action_press("reset")
	await _step()
	Input.action_release("reset")
	await _step(2)
	_check(player.gravity_direction == 1 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "Retry restores gravity and resources")


func _until(condition: Callable, limit: int, message: String) -> void:
	for frame in limit:
		if condition.call() or failed:
			return
		await _step()
	_check(false, message)


func _x() -> float:
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


func _screenshots() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-2")
	for index in 6:
		stage.call("_set_room", index, false)
		player.respawn()
		await _step(3)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-2/room_%d.png" % (index + 1))


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
		failed = true
		push_error("STAGE_2: %s (room=%d pos=%s gravity=%d)" % [message, stage.room_index + 1 if stage != null else 0, player.position if player != null else Vector2.ZERO, player.gravity_direction if player != null else 0])
