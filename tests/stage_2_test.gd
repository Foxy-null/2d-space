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
	stage.rooms.get_child(0).get_node("LaunchSpring").launched.connect(func(_body): actions["launch_spring"] = actions.get("launch_spring", 0) + 1)
	stage.rooms.get_child(0).get_node("ReturnSpring").launched.connect(func(_body): actions["return_spring"] = actions.get("return_spring", 0) + 1)
	stage.rooms.get_child(1).get_node("CeilingBumper").launched.connect(func(_body): actions["bumper"] = actions.get("bumper", 0) + 1)
	stage.rooms.get_child(2).get_node("ExitJumpCrystal").collected.connect(func(_body): actions["jump_crystal"] = actions.get("jump_crystal", 0) + 1)
	stage.rooms.get_child(4).get_node("ExitSpring").launched.connect(func(_body): actions["exit_spring"] = actions.get("exit_spring", 0) + 1)
	stage.rooms.get_child(5).get_node("CeilingSpring").launched.connect(func(_body): actions["spring"] = actions.get("spring", 0) + 1)
	stage.rooms.get_child(4).get_node("Headwind").body_entered.connect(func(body):
		if body == player:
			actions["wind"] = actions.get("wind", 0) + 1
	)
	for index in [3, 5]:
		var wind_name := "ExitUpdraft" if index == 3 else "ExitHeadwind"
		stage.rooms.get_child(index).get_node(wind_name).body_entered.connect(func(body):
			if body == player:
				actions["exit_wind"] = actions.get("exit_wind", 0) + 1
		)
	_check_hints(false)
	_check_help(false)
	_check_status(false)
	await _key(KEY_H)
	_check_help(true)
	_check_hints(false)
	var echo_event := InputEventKey.new()
	echo_event.physical_keycode = KEY_H
	echo_event.pressed = true
	echo_event.echo = true
	Input.parse_input_event(echo_event)
	await _step()
	_check(stage.help_menu_visible, "Holding H must not repeatedly toggle the help menu")
	await _click(stage.get_node("HUD/HelpMenu/Rows/ToggleHints"))
	_check_hints(true)
	await _click(stage.get_node("HUD/HelpButton"))
	_check_help(false)
	await _gamepad_hints()
	_check_help(true)
	await _gamepad_hints(JOY_BUTTON_A)
	_check_hints(false)
	await _key(KEY_ESCAPE)
	_check_help(false)
	await _toggle_hints()
	_check_hints(true)
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
	_check_hints(true)
	await _toggle_hints()
	_check_hints(false)
	await _verify_shortcuts()
	stage._set_room(0, false)
	player.respawn()
	await _step(3)
	for index in 6:
		if index >= 2:
			await _fall_into_pit([0, 0, 350, 620, 470, 340][index])
		if index > 0:
			await _fall_into_ceiling_pit([0, 500, 330, 320, 330, 530][index])
			await _fall_into_ceiling_pit([0, 950, 700, 850, 920, 950][index])
		actions.clear()
		flips.clear()
		var respawns_before := respawns
		match index:
			0:
				await _kick_pair(false, 0, true)
				_check(actions.has("launch_spring"), "The first room launches from its Spring into the wall kicks")
				_drive("move_right")
				await _until(func(): return actions.has("return_spring"), 160, "The first room's kicks enter Up gravity and its ceiling Spring")
				await _until(func(): return player.gravity_direction == 1, 100, "The ceiling Spring passes through Down gravity before the arrival switch")
			1:
				await _cross_ceiling_pit(500, 600)
				await _kick_pair(true, 0)
				_drive("move_right")
				await _until(func(): return actions.has("bumper"), 180, "The actual ceiling route rebounds from the pinball spring")
				await _kick_gate(1060, 1, "", true)
			2:
				await _kick_gate(240, -1)
				await _cross_ceiling_pit(330, 470)
				if OS.get_cmdline_user_args().has("--screenshots"):
					RenderingServer.force_draw()
					root.get_texture().get_image().save_png("res://docs/screenshots/stage-2/room_3_inverted.png")
				await _cross_crystal_pit(700, 1060)
			3:
				await _kick_gate(280, -1)
				await _cross_ceiling_pit(320, 450)
				await _kick_gate(580, 1)
				_drive("move_right")
				await _until(func(): return player.is_on_floor() and _x() > 580, 120, "Reach the edge before the floor pit")
				await _jump()
				await _kick_gate(840, -1)
				await _cross_ceiling_pit(850, 1020)
				_check(actions.has("exit_wind"), "The second ceiling crossing passes through a vertical gust")
				await _kick_gate(1100, 1, "DownGate")
			4:
				await _kick_gate(360, -1, "UpGate")
				await _cross_ceiling_pit(330, 470)
				_check(actions.has("wind") and player.velocity.x < player.move_speed, "The ceiling jump actually crosses a slowing headwind")
				await _kick_pair(true, 130)
				_drive("move_right")
				await _until(func(): return actions.has("exit_spring"), 150, "The short overhead platform leads into its exit Spring")
				await _until(func(): return player.gravity_direction == 1, 120, "The exit Spring reaches the right-hand Down gate")
			5:
				await _kick_gate(260, -1)
				await _kick_pair(true, -10, true)
				_check(actions.has("spring"), "The final ceiling route uses the inverted Spring")
				await _kick_gate(960, -1, "MovingUpGate")
				await _cross_ceiling_pit(950, 1070)
				_check(actions.has("exit_wind"), "The final ceiling pit is crossed against a headwind")
				await _kick_gate(1110, 1, "DownGate")
		if failed:
			quit(1)
			return
		await _reach_goal()
		_check(stage.cleared.has(index), "Actual arrival must clear room %d" % (index + 1))
		_check(respawns == respawns_before, "The no-dash route crosses room %d without falling" % (index + 1))
		if index >= 2:
			var room: Node2D = stage.rooms.get_child(index)
			_check(room.get_node("ReturnBridge").visible and not room.get_node("ReturnBridge/Collision").disabled and not room.get_node("PitWarning").visible, "Clearing the room fills its pit and hides its warning")
			if index == 3:
				for curtain in room.find_children("*UpCurtain", "Area2D", false, false):
					_check(not curtain.monitoring and not curtain.visible, "Cleared room 4 stops its bypass curtains so the floor return route remains usable")
		_check(actions.get("wall_jump", 0) >= [2, 3, 1, 4, 3, 5][index], "Each route keeps its wall-kick challenges in room %d" % (index + 1))
		_check(not actions.has("dash"), "Room %d can be completed without dash" % (index + 1))
		_check(flips.has(-1) and flips.has(1), "Room %d uses both gravity directions" % (index + 1))
		if index in [3, 5]:
			_check(flips.count(-1) == 2 and flips.count(1) == 2, "Later rooms use two intended cycles without an accidental return flip")
		if failed:
			quit(1)
			return
		print("STAGE_2_ROOM_%d_OK (wall kicks=%d, flips=%s)" % [index + 1, actions.get("wall_jump", 0), flips])
		if index < 5:
			if index == 0:
				await _toggle_hints()
			Input.action_press("move_right")
			await _until(func(): return stage.room_index == index + 1, 150, "Cross the open exit")
			_check(stage.transitioning and not player.controls_enabled, "Camera slides freeze controls")
			_release_inputs()
			await _step(25)
			_check(not stage.transitioning and player.controls_enabled, "Controls resume after the camera slide")
			_check(stage.camera.position == Vector2((index + 1) * 1280 + 640, 360), "Camera settles on the next room")
			if index == 0:
				_check_hints(true)
				await _toggle_hints()
				_check_hints(false)
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
	await _key(KEY_H)
	_check_help(true)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Keyboard navigation selects the return button inside the help menu")
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	stage = current_scene
	player = stage.player
	_check(stage.room_index == 0 and stage.cleared.is_empty() and not stage.completed, "Re-selecting stage 2 starts fresh")
	_check_hints(false)
	_check_help(false)
	_check(stage.get_node("HUD/HelpButton").focus_mode == Control.FOCUS_NONE, "Jump cannot focus the help trigger during gameplay")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _screenshots()
	await _click(stage.get_node("HUD/HelpButton"))
	await _click(stage.get_node("HUD/HelpMenu/Rows/ReturnToStageSelect"))
	await _step(3)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "The return button opens stage selection")
	_release_inputs()
	print("STAGE_2_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _verify_shortcuts() -> void:
	stage._set_room(2, false)
	for diagonal in [false, true]:
		for delay in [0, 15, 30, 45, 55, 60]:
			_release_inputs()
			player.respawn()
			await _step(3)
			var before := respawns
			_drive("move_right", true)
			await _until(func(): return player.is_on_floor() and player.position.y < 410 and _x() > 240, 160, "Climb the launch wall using only normal gravity")
			_drive("move_right")
			await _jump()
			await _step(delay)
			if diagonal:
				Input.action_press("move_up")
			Input.action_press("dash")
			await _step()
			Input.action_release("move_up")
			Input.action_release("dash")
			for frame in 180:
				if respawns > before or (player.is_on_floor() and _x() > 1080):
					break
				await _step()
			_check(respawns > before and not stage.cleared.has(2), "Room 3's enlarged gap defeats an elevated jump plus dash (diagonal=%s, delay=%d)" % [diagonal, delay])
			if failed:
				return
	stage._set_room(3, false)
	for second in [false, true]:
		_release_inputs()
		player.respawn()
		if second:
			player.global_position = stage.rooms.get_child(3).to_global(Vector2(790, 614))
		await _step(3)
		_drive("move_right", true)
		var wall_x := 840 if second else 280
		await _until(func(): return player.gravity_direction == -1 or (player.is_on_floor() and player.position.y < 410 and _x() > wall_x), 160, "Climbing the floor wall reaches its gravity curtain")
		_drive("move_right")
		await _until(func(): return player.gravity_direction == -1, 50, "The gravity curtain intercepts the original floor bypass")
		_check(not stage.cleared.has(3), "Room 4 cannot leave either floor wall without encountering Up gravity")
		if failed:
			return
	_release_inputs()


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


func _fall_into_ceiling_pit(edge_x: int) -> void:
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	_release_inputs()
	player.set_gravity_direction(-1)
	player.global_position = room.to_global(Vector2(edge_x - 24, 106))
	await _step(3)
	var respawns_before := respawns
	_drive("move_right")
	await _until(func(): return respawns > respawns_before, 240, "Walking into the ceiling pit without jumping or grabbing must cause a retry")
	_release_inputs()
	await _step(2)
	_check(stage.room_index == room.get_index() and player.global_position.distance_to(room.get_node("Spawn").global_position) < 20, "A ceiling pit returns to the current entrance")
	_check(player.gravity_direction == 1 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "An inverted pit fall resets gravity and resources")


func _cross_ceiling_pit(edge_x: int, end_x: int) -> void:
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() > edge_x - 36 and _x() < edge_x, 200, "Reach the ceiling pit before leaving its edge")
	_check(player.gravity_direction == -1, "The upper pit must be crossed while inverted")
	await _jump()
	await _until(func(): return player.is_on_floor() and _x() > end_x, 110, "An inverted jump must land beyond the ceiling pit")


func _cross_crystal_pit(edge_x: int, end_x: int) -> void:
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() > edge_x - 36 and _x() < edge_x, 180, "Reach the wide ceiling gap")
	await _jump()
	await _until(func(): return player.is_air_jump_ready() and _x() >= 850, 70, "Collect the crystal during the first inverted jump")
	_check(actions.has("jump_crystal") and not player.is_on_floor(), "The crystal grants a jump in the middle of the ceiling gap")
	_check(stage.get_node("HUD/Status/Rows/Resources").text.contains("空中ジャンプ：1"), "The HUD shows the available crystal jump even with hints hidden")
	await _jump()
	await _until(func(): return player.gravity_direction == 1 and _x() > end_x - 40, 100, "The air jump reaches the far ceiling's return gate")
	_check(actions.has("air_jump"), "The wide late gap is crossed with an actual air jump")
	_check(not stage.get_node("HUD/Status/Rows/Resources").text.contains("空中ジャンプ：1"), "The HUD clears the extra jump after use")


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
	await _until(func(): return player.is_wall_grabbing() and (player.position.y > kick_y if inverted else player.position.y < 480), 110, "Climb to the gate's height at x=%d" % wall_x)
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
	_check_status(target < 0)
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


func _check_hints(expected: bool) -> void:
	var consistent := true
	for hint in get_nodes_in_group("stage_2_hints"):
		consistent = consistent and hint.visible == expected
	_check(stage.hints_visible == expected and consistent and not get_nodes_in_group("stage_2_hints").is_empty(), "All explanations and path arrows follow the hint setting")
	_check(stage.get_node("HUD/Margin/Panel/Rows/Title").text.contains(stage.HINTS[stage.room_index]) == expected, "HUD explanations follow the hint setting")
	_check(stage.rooms.get_child(1).get_node("UpGate/Arrow").visible and stage.get_node("HUD/Status").visible, "Mechanism directions and player resources stay visible")


func _toggle_hints() -> void:
	await _key(KEY_H)
	await _click(stage.get_node("HUD/HelpMenu/Rows/ToggleHints"))
	await _key(KEY_H)


func _check_help(expected: bool) -> void:
	_check(stage.help_menu_visible == expected and stage.get_node("HUD/HelpMenu").visible == expected, "The help menu follows its setting and starts closed")
	_check(stage.get_node("HUD/HelpMenu/Rows/ReturnToStageSelect").is_visible_in_tree() == expected, "Return and hint controls stay inside the help menu")
	_check(player.controls_enabled != expected, "Opening the menu suspends character input and closing restores it")
	_check((root.gui_get_focus_owner() != null) == expected, "Only the open help menu owns keyboard and controller focus")


func _check_status(inverted: bool) -> void:
	var status: Control = stage.get_node("HUD/Status")
	var gauge: ProgressBar = stage.get_node("HUD/Status/Rows/Stamina")
	_check((status.position.y > 360) == inverted, "Resources switch to the side opposite gravity in the same frame")
	_check(is_equal_approx(gauge.value, player.get_wall_stamina()) and is_equal_approx(gauge.max_value, player.wall_stamina_max), "The stamina gauge displays the actual remaining resource")
	_check(not stage.get_node("HUD/Status/Rows/Resources").text.contains("秒") and not stage.get_node("HUD/Margin/Panel/Rows/Gravity").visible, "Stamina seconds and gravity text are absent")


func _click(button: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await _step()
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await _step()
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _step(2)


func _gamepad_hints(button: JoyButton = JOY_BUTTON_Y) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)


func _screenshots() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-2")
	for index in 6:
		stage.call("_set_room", index, false)
		player.respawn()
		await _step(3)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-2/room_%d.png" % (index + 1))
		if index == 4:
			await _toggle_hints()
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-2/room_5_hints.png")
			await _toggle_hints()
			await _key(KEY_H)
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-2/help_menu.png")
			await _key(KEY_H)


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
