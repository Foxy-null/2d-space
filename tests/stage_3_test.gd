extends SceneTree

var failed := false
var checks := 0
var stage: Node2D
var player: PlayerController
var actions: Dictionary = {}
var flips: Array[int] = []
var respawns := 0
var jump_spacing := 20
var course_model := -1
var course_origin := 0.0
var course_reversed := false
var course_prefix := ""
const MORE_SOURCES := [[8], [5, 3], [2], [4], [2], [6]]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://stage_three_full_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_3.tscn", "Keyboard selection must start stage 3")
	stage = current_scene
	await stage.get_node("StageIntro").tree_exited
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
	for index in [23,24]:
		stage.rooms.get_child(index).get_node("DashCrystal").collected.connect(func(_body): actions["crystal"] = actions.get("crystal",0)+1)
	_fifth_connect()
	_sixth_connect()
	_check_hints(false)
	_check_help(false)
	_check_status()
	await _key(KEY_ESCAPE)
	_check_help(true)
	_check_hints(false)
	var echo_event := InputEventKey.new()
	echo_event.physical_keycode = KEY_ESCAPE
	echo_event.pressed = true
	echo_event.echo = true
	Input.parse_input_event(echo_event)
	await _step()
	_check(paused, "Holding Esc must not repeatedly toggle the help menu")
	await _click(stage.get_node("PauseMenu/Overlay/Center/Panel/Rows/Menu/Hints"))
	_check_hints(true)
	await _click(stage.get_node("PauseMenu").menu.get_node("Resume"))
	_check_help(false)
	await _gamepad_hints()
	_check_help(true)
	await _key(KEY_DOWN)
	await _gamepad_hints(JOY_BUTTON_A)
	_check_hints(false)
	await _key(KEY_ESCAPE)
	_check_help(false)
	await _toggle_hints()
	_check_hints(true)
	_check(stage.rooms.get_child_count() == 37, "Stage 3 has thirty-seven native rooms")
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
	for index in stage.rooms.get_child_count():
		if index >= 2 and index < 6:
			await _fall_into_pit([0, 0, 350, 620, 470, 340][index])
		if index > 0 and index < 6:
			await _fall_into_ceiling_pit([0, 460, 330, 320, 330, 530][index])
			if index != 2:
				await _fall_into_ceiling_pit([0, 950, 0, 850, 920, 950][index])
		actions.clear()
		flips.clear()
		var respawns_before := respawns
		match index:
			0:
				await _room_one_wall_course()
				_check(actions.has("launch_spring"), "The first room launches from its Spring into the wall kicks")
				_drive("move_right")
				await _until(func(): return actions.has("return_spring"), 160, "The first room's kicks enter Up gravity and its ceiling Spring")
				await _until(func(): return player.gravity_direction == 1, 100, "The ceiling Spring passes through Down gravity before the arrival switch")
			1:
				await _room_two_wall_course()
				_drive("move_right")
				await _until(func(): return actions.has("bumper"), 180, "The actual ceiling route rebounds from the pinball spring")
				await _kick_gate(1060, 1, "", true)
			2:
				await _kick_gate(240, -1)
				await _cross_ceiling_pit(330, 470)
				_check_status()
				await _click(stage.get_node("HUD/PauseButton"))
				_check_help(true)
				await _click(stage.get_node("PauseMenu/Overlay/Center/Panel/Rows/Menu/Hints"))
				_check_hints(true)
				await _click(stage.get_node("PauseMenu/Overlay/Center/Panel/Rows/Menu/Hints"))
				_check_hints(false)
				if OS.get_cmdline_user_args().has("--screenshots"):
					RenderingServer.force_draw()
					root.get_texture().get_image().save_png("res://docs/screenshots/stage-3/help_menu_inverted.png")
				await _key(KEY_ESCAPE)
				_check_help(false)
				if OS.get_cmdline_user_args().has("--screenshots"):
					RenderingServer.force_draw()
					root.get_texture().get_image().save_png("res://docs/screenshots/stage-3/room_3_inverted.png")
				await _cross_crystal_wall()
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
				await _cross_floating_spring()
			5:
				await _kick_gate(260, -1)
				await _kick_pair(true, -10, true)
				_check(actions.has("spring"), "The final ceiling route uses the inverted Spring")
				await _kick_gate(960, -1, "MovingUpGate")
				await _cross_ceiling_pit(950, 1070)
				_check(actions.has("exit_wind"), "The final ceiling pit is crossed against a headwind")
				await _kick_gate(1110, 1, "DownGate")
			6:
				await _room_seven_course()
			7:
				await _room_eight_course()
			8:
				await _room_nine_course()
			_:
				if index < 15: await _composite_course(index)
				elif index < 21: await _third_course(index)
				elif index < 25: await _para_course(index)
				elif index < 31: await _fifth_course(index)
				else: await _sixth_course(index)
		if failed:
			quit(1)
			return
		await _reach_goal()
		_check(stage.cleared.has(index), "Actual arrival must clear room %d" % (index + 1))
		_check(respawns == respawns_before, "The real route crosses room %d without falling" % (index + 1))
		if index >= 2:
			var room: Node2D = stage.rooms.get_child(index)
			_check(room.get_node("ReturnBridge").visible and not room.get_node("ReturnBridge/Collision").disabled and not room.get_node("PitWarning").visible, "Clearing the room fills its pit and hides its warning")
		_check(actions.get("wall_jump", 0) >= [2, 3, 1, 4, 1, 5, 3, 1, 1, 0, 2, 3, 3, 3, 1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 4, 0, 4, 0, 0, 0, 4, 0, 0, 0, 4, 4][index], "Each route keeps its wall-kick challenges in room %d" % (index + 1))
		if index == 8:
			_check(actions.get("jump", 0) == 2 and flips == [-1, 1], "The ninth room connects a tailwind Jump to one return kick without repeating the gravity cycle")
		if index == 9:
			_check(actions.get("launch_spring", 0) == 1 and actions.get("air_jump", 0) == 2 and actions.get("wall_jump", 0) == 0, "The shortened tenth room uses the real Spring entry and both Boots instead of repeating wall kicks")
		if index == 11:
			_check(actions.get("wall_jump", 0) == 3 and actions.has("bumper") and not actions.has("launch_spring") and not actions.has("return_spring") and flips == [-1, 1], "The shortened twelfth room connects its Up Dash to the wall transfers and bumper without repeating the Spring course")
		if index == 12:
			_check(actions.get("wall_jump", 0) == 3 and actions.get("air_jump", 0) == 0 and actions.get("jump_crystal", 0) == 0, "The shortened thirteenth room ends with a downward Dash instead of repeating the Boots course")
		if index == 13:
			_check(actions.get("wall_jump", 0) == 3 and actions.has("bumper") and actions.get("jump_crystal", 0) == 0 and flips == [-1, 1], "The shortened fourteenth room keeps its leftward wall transfers and bumper without repeating the crystal course")
		if index == 14:
			_check(actions.has("spring") and actions.get("exit_spring", 0) == 0 and flips == [-1, 1], "The shortened fifteenth room links its inverted Spring and horizontal Dash through one Down")
		_check(actions.get("dash", 0) == ([0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 2, 1, 1, 0, 1, 2, 2, 2, 2, 3, 4, 0, 0, 2, 2, 1, 2, 1, 1, 3, 2, 0, 1, 2, 0, 2, 1][index]), "The real inputs use each course's intended Dash resources")
		_check(flips.has(-1) and flips.has(1), "Room %d uses both gravity directions" % (index + 1))
		if index in [3, 5]:
			_check(flips.count(-1) == 2 and flips.count(1) == 2, "Later rooms use two intended cycles without an accidental return flip")
		if failed:
			quit(1)
			return
		_reset_course()
		print("STAGE_3_ROOM_%d_OK (wall kicks=%d, flips=%s)" % [index + 1, actions.get("wall_jump", 0), flips])
		if index < stage.rooms.get_child_count() - 1:
			if index == 0:
				await _toggle_hints()
			_check(not stage.completed, "The former final room and intermediate additions never end the stage")
			await _cross_room_boundary()
			if index == 0:
				_check_hints(true)
				await _toggle_hints()
				_check_hints(false)
	_check(stage.completed and stage.get_node("HUD/Completion").visible, "Final arrival displays completion without leaving the stage")
	if OS.get_cmdline_user_args().has("--screenshots"):
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-3")
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-3/clear.png")
	await _retry()
	var final_index: int = stage.rooms.get_child_count()-1
	var final_room: Node2D = stage.rooms.get_child(final_index)
	_check(stage.completed and final_room.get_node("Goal").is_pressed(), "Retry keeps the actual final goal and completion")
	player.set_gravity_direction(-1)
	player.global_position.y = -60
	await _step(3)
	_check(player.gravity_direction == 1 and player.position.y > 0, "Inverted falls reset to the current entrance")
	player.global_position.y = float(final_room.get_meta("room_bottom"))+60
	await _step(3)
	_check(stage.room_index == final_index and player.global_position.y < float(final_room.get_meta("room_bottom")), "Falling below the actual final room retries its entrance")
	player.global_position.x = final_room.global_position.x + float(final_room.get_meta("room_width")) + 5
	await _step(25)
	_check(stage.room_index == final_index-1 and player.position.distance_to(stage.rooms.get_child(final_index-1).get_node("Return").global_position)<5, "Backtracking uses the actual preceding room's right entrance")
	_check(bridge.visible and not bridge.get_node("Collision").disabled, "Backtracking preserves the return bridge")
	_check(stage.completed and stage.cleared.size() == 37 and not stage.get_node("HUD/Completion").visible, "Backtracking preserves all thirty-seven cleared rooms without a completion overlay")
	await _retry()
	_check(player.position.distance_to(stage.rooms.get_child(final_index-1).get_node("Return").global_position)<5, "Retry after backtracking keeps the preceding right entrance")
	stage._set_room(4, true)
	player.respawn()
	await _step(3)
	_check_hints(false)
	var gate: Area2D = stage.rooms.get_child(4).get_node("UpGate")
	await _step(30)
	_check(gate.position != gate.get("_initial_position"), "Moving gates actually travel")
	await _retry()
	_check(gate.position.distance_to(gate.get("_initial_position")) < 5, "Retry resets the moving gate")
	_drive("move_left")
	for frame in 180:
		if _x() < 820 and player.is_on_floor():
			break
		FullJumpInput.release_after_apex(player)
		if player.is_on_floor() and player.is_on_wall():
			FullJumpInput.press(player)
		await _step()
	_check(stage.room_index == 4 and _x() < 820 and player.is_on_floor(), "Backtrack over the arrival switch onto the return bridge")
	_drive("move_right")
	await _until(func(): return _x() > 1055, 100, "Walk under the exit landing without getting stuck")
	_check(player.is_on_floor(), "The return bridge provides room below the exit landing")
	_release_inputs()
	await _key(KEY_ESCAPE)
	_check_help(true)
	for move in 8:
		if root.gui_get_focus_owner() == stage.get_node("PauseMenu").menu.get_node("Return"):
			break
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(paused and stage.get_node("PauseMenu").confirmation.visible, "Return waits for confirmation")
	await _key(KEY_UP)
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Keyboard navigation selects the return button inside the help menu")
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	stage = current_scene
	player = stage.player
	_check(stage.room_index == 0 and stage.cleared.is_empty() and not stage.completed, "Re-selecting stage 3 starts fresh")
	await stage.get_node("StageIntro").tree_exited
	_check_hints(false)
	_check_help(false)
	_check(stage.get_node("HUD/PauseButton").focus_mode == Control.FOCUS_NONE, "Jump cannot focus the help trigger during gameplay")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _screenshots()
	await _click(stage.get_node("HUD/PauseButton"))
	await _click(stage.get_node("PauseMenu/Overlay/Center/Panel/Rows/Menu/Return"))
	await _click(stage.get_node("PauseMenu").confirmation.get_node("Return"))
	await _step(3)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "The return button opens stage selection")
	_release_inputs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("STAGE_3_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _cross_room_boundary(forward := true) -> void:
	var index: int = stage.room_index
	var room: Node2D = stage.rooms.get_child(index)
	var target := index + (1 if forward else -1)
	var direction: int = stage._exit_direction(room) * (1 if forward else -1)
	_release_inputs()
	Input.action_press("move_right" if direction > 0 else "move_left", para_strength)
	if player.get_held_object() != null:
		Input.action_press("wall_grab")
	for frame in 1000:
		if stage.room_index != index or failed:
			break
		FullJumpInput.release_after_apex(player)
		if player.is_on_floor() and player.is_on_wall():
			FullJumpInput.press(player)
		await _step()
	_check(stage.room_index == target, "The real room boundary follows the course direction")
	_check(stage.transitioning and not player.controls_enabled, "The short room transition freezes controls")
	_release_inputs()
	await _step(25)
	_check(not stage.transitioning and player.controls_enabled, "Controls resume after the short transition")
	_check(stage.camera.position == stage._camera_position(), "The next room opens at its actual checkpoint")


func _room_seven_course() -> void:
	await _room_two_wall_course()
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() > 665, 120, "Reach the safe underside takeoff before the bumper")
	await _jump()
	await _until(func(): return _x() > 960, 200, "The left-facing ceiling route crosses its real bumper")
	await _kick_gate(1060, 1, "", true)


func _room_eight_course(jump_delay: int = 20) -> void:
	var air_before: int = actions.get("air_jump", 0)
	if stage.room_index == 9:
		await _room_ten_entry()
	else:
		await _kick_gate(240, -1)
		await _cross_ceiling_pit(330, 470)
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() >= 760 and _x() < 800, 180, "Reach the upper rest before the two-crystal descent")
	_release_inputs()
	await _step(30)
	for crystal in ["ExitJumpCrystal", "SecondJumpCrystal"]:
		await _jump()
		await _step(jump_delay)
		_check(not _course_node(crystal).visible and player.is_air_jump_ready(), "A real descending jump reaches " + crystal)
	await _jump()
	await _step(jump_delay)
	Input.action_press("move_down")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	Input.action_release("move_down")
	await _until(func(): return player.position.y >= 480, 90, "Two extra jumps and a downward Dash clear the deeper hanging wall")
	_drive("move_right")
	await _until(func(): return player.gravity_direction == 1 and _x() > 900, 110, "The extended descent reaches Down gravity")
	_check(actions.get("air_jump", 0) - air_before == 2, "The upper course spends both separate crystal jumps")


func _room_ten_entry() -> void:
	var springs_before: int = actions.get("launch_spring", 0)
	_drive("move_right")
	await _until(func(): return player.gravity_direction == -1 and _fifth_floor("A_MiddleCeiling"), 240, "The actual Spring launches through Up and lands beyond the first ceiling gap")
	_release_inputs()
	await _step(20)
	var rest := player.position
	await _step(180)
	_check(player.position.distance_to(rest) < 2 and player.is_on_floor() and player.is_dash_ready(), "The Spring landing allows three input-free seconds and recovers Dash")
	_check(actions.get("launch_spring", 0) == springs_before + 1, "The new entry uses one actual launch from its Spring")
	for entry in [["A_ExitJumpCrystal", 12.0], ["A_SecondJumpCrystal", 12.0], ["A_DownGate", 7.0]]:
		var shape: CollisionShape2D = stage.rooms.get_child(9).get_node(entry[0] + "/CollisionShape2D")
		var bounds := shape.get_global_transform_with_canvas() * shape.shape.get_rect().grow(entry[1])
		_check(root.get_visible_rect().grow(-4).encloses(bounds), "The next actual Boots and Down ink fit the viewport from the new rest")
		for path in ["HUD/Margin/Panel", "HUD/PauseButton", "HUD/Status"]:
			var panel: Control = stage.get_node(path)
			_check(not panel.is_visible_in_tree() or not panel.get_global_rect().grow(4).intersects(bounds), "The next actual Boots and Down stay clear of visible HUD " + path)


func _room_twelve_entry(jump_delay: int = 20) -> void:
	_drive("move_right")
	await _until(func(): return _x() >= 300 and player.is_on_floor(), 120, "Walk to the safe floor below the high Up")
	_release_inputs()
	await _jump()
	await _step(jump_delay)
	Input.action_press("move_up")
	Input.action_press("dash")
	await _step()
	_release_inputs()
	await _until(func(): return player.gravity_direction == -1 and player.is_on_floor(), 180, "The actual Jump and Up Dash reach the high gate and existing ceiling")
	await _step(20)
	var rest := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(rest) < 2 and player.is_dash_ready(), "The first ceiling allows three input-free seconds after the real Up Dash")


func _room_thirteen_descent(jump_delay: int = 20) -> void:
	_drive("move_right")
	await _until(func(): return _x() >= 1020 and player.is_on_floor(), 120, "Reach the actual final ceiling above the moving Down")
	_release_inputs()
	await _step(20)
	var rest := player.position
	var gate: Area2D = _course_node("DownGate")
	var shape: CollisionShape2D = gate.get_node("CollisionShape2D")
	var gate_bounds := Rect2()
	for frame in 180:
		await _step()
		var bounds := shape.get_global_transform_with_canvas() * shape.shape.get_rect().grow(7)
		gate_bounds = bounds if frame == 0 else gate_bounds.merge(bounds)
	_check(player.position.distance_to(rest) < 2 and player.is_on_floor() and player.is_dash_ready(), "The final ceiling allows three input-free seconds before choosing the Down approach")
	_check(root.get_visible_rect().grow(-4).encloses(gate_bounds), "The moving Down ring stays inside the viewport throughout the three-second rest")
	for path in ["HUD/Margin/Panel", "HUD/PauseButton", "HUD/Status"]:
		var panel: Control = stage.get_node(path)
		_check(not panel.is_visible_in_tree() or not panel.get_global_rect().grow(4).intersects(gate_bounds), "The moving Down ring stays clear of visible HUD " + path)
	await _until(func(): return gate.position.y <= 420, 150, "Wait on the ceiling for the visible Down's broad upper approach")
	await _jump()
	await _step(jump_delay)
	Input.action_press("move_down")
	Input.action_press("dash")
	await _step()
	_release_inputs()
	await _until(func(): return player.gravity_direction == 1, 120, "The inverted Jump and actual downward Dash enter the moving Down")
	_check(actions.get("dash", 0) == 1, "The thirteenth room uses its downward Dash instead of a final wall kick")


func _room_nine_course() -> void:
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() >= 288, 180, "Reach the tailwind takeoff before the marked floor edge")
	await _jump()
	await _until(func(): return player.gravity_direction == -1, 90, "The tailwind carries the ordinary Jump into the distant Up")
	_release_inputs()
	await _until(func(): return player.is_on_floor(), 120, "The momentum ends on the safe inverted ceiling beyond the wind")
	var rest := player.position
	await _step(180)
	_check(player.gravity_direction == -1 and player.is_on_floor() and player.position.distance_to(rest) < 2 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "The ceiling allows three input-free seconds with full movement resources")
	await _kick_gate(1100, 1, "DownGate")


func _room_fifteen_course() -> void:
	await _kick_gate(260, -1)
	_release_inputs()
	await _until(func(): return player.gravity_direction == -1 and player.is_on_floor(), 180, "The first Up leads to the safe ceiling before the Spring")
	await _step(20)
	var rest := player.position
	await _step(180)
	_check(player.gravity_direction == -1 and player.is_on_floor() and player.position.distance_to(rest) < 2 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "The Spring approach allows three input-free seconds with full resources")
	_drive("move_right")
	await _until(func(): return actions.has("spring"), 180, "The real inverted Spring launches toward the moving Down")
	_check(player.is_dash_ready(), "The Spring restores the Dash for the exit crossing")
	await _until(func(): return player.gravity_direction == 1, 120, "The real Spring reaches Down without spending the crossing Dash")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	_drive("move_right")


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
			_check(respawns > before and not stage.cleared.has(2), "Room 3's floor hazards reject an elevated jump plus late dash (diagonal=%s, delay=%d)" % [diagonal, delay])
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
		await _until(func(): return player.gravity_direction == -1 or (player.is_on_floor() and player.position.y < 410 and _x() > wall_x), 160, "Climbing the floor wall reaches its enlarged Up gate")
		_drive("move_right")
		await _until(func(): return player.gravity_direction == -1, 50, "The existing Up gate intercepts the original floor bypass")
		_check(not stage.cleared.has(3), "Room 4 cannot leave either floor wall without encountering Up gravity")
		if failed:
			return
	await _verify_middle_gate_mantle()
	_release_inputs()


func _verify_middle_gate_mantle() -> void:
	for index in [3]:
		_release_inputs()
		stage._set_room(index, false)
		player.respawn()
		await _step(4)
		var before := respawns
		await _kick_gate(280, -1)
		await _cross_ceiling_pit(320, 450)
		_drive("move_right")
		await _until(func(): return player.is_on_wall() and _x() > 555, 120, "Reach the actual middle ceiling wall")
		_drive("move_right", true, true)
		await _until(func(): return respawns > before or player.gravity_direction == 1 or _x() > 625, 180, "Attempt the previously successful middle-wall mantle")
		_check(respawns == before and player.gravity_direction == 1 and _x() < 625 and not stage.cleared.has(index), "The native MiddleDown intercepts grab descent before the ceiling wall can be mantled underneath")
		if failed: return
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


func _cross_floating_spring() -> void:
	_drive("move_right")
	await _until(func(): return _x() >= 914, 200, "Reach the wide ceiling's actual Spring takeoff")
	await _jump()
	await _step(20)
	_release_inputs()
	Input.action_press("move_down")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	Input.action_release("move_down")
	await _until(func(): return actions.has("exit_spring"), 180, "Down dash below the floating Spring and rise naturally into it")
	_drive("move_right")
	await _until(func(): return player.gravity_direction == 1, 120, "The actual Spring reaches the right-hand Down gate")


func _cross_crystal_wall(jump_delay: int = 20) -> void:
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() >= 760 and _x() < 800, 180, "Reach the wide ceiling rest before the hanging spikes")
	_release_inputs()
	await _step(30)
	await _jump()
	await _step(jump_delay)
	_check(player.is_air_jump_ready() and actions.has("jump_crystal") and not player.is_on_floor(), "The first inverted jump actually collects the airborne crystal")
	_check(stage.get_node("HUD/Status/Rows/Resources").text.contains("空中ジャンプ：1"), "The HUD shows the available crystal jump even with hints hidden")
	await _jump()
	await _step(jump_delay)
	Input.action_press("move_down")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	Input.action_release("move_down")
	await _until(func(): return player.position.y >= 500, 90, "The air jump and downward dash descend below the hanging spikes")
	_drive("move_right")
	await _until(func(): return player.gravity_direction == 1 and _x() > 900, 100, "The descent reaches the real return gate beyond the wall")
	_check(actions.has("air_jump"), "The crystal right is actually spent before returning to the floor")
	_check(not stage.get_node("HUD/Status/Rows/Resources").text.contains("空中ジャンプ：1"), "The HUD clears the extra jump after use")


func _room_one_wall_course(land_on_cap: bool = false, takeoffs := Vector4(548, 440, 332, 78)) -> void:
	_drive("move_right")
	await _until(func(): return player.is_on_wall() and _x() > 600, 260, "Spring reaches the first wall below its overhang")
	await _until(func(): return player.position.y >= takeoffs.x, 100, "Let the Spring descent leave room to kick around the lower lip")
	_drive("move_left", true)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _x() < 500, 90, "Kick onto the first left grip")
	await _until(func(): return player.position.y < takeoffs.y, 90, "Climb below the left overhang")
	_drive("move_right", true)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _x() > 600, 90, "Kick over the lower overhang onto the middle right grip")
	await _until(func(): return player.position.y < takeoffs.z, 90, "Climb below the upper right overhang")
	_drive("move_left", true)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _x() < 500, 90, "Kick above the left overhang")
	await _until(func(): return player.position.y < takeoffs.w, 140, "Climb the clear upper wall before the last transfer")
	_drive("move_right", true)
	await _jump()
	_drive("move_right")
	if land_on_cap:
		await _until(func(): return _x() > 626, 90, "Cross above the right wall")
		_release_inputs()
		await _until(func(): return player.is_on_floor() and _x() > 640 and _x() < 680, 120, "Land on the right wall cap before the gravity gate")


func _room_two_wall_course(takeoffs := Vector2(280, 560)) -> void:
	await _cross_ceiling_pit(460, 560)
	_drive("move_right")
	await _until(func(): return player.is_on_wall() and player.is_on_floor() and _x() > 550, 100, "Reach the second room's inverted wall")
	await _jump()
	await _step(10)
	_drive("move_left", true, true)
	await _until(func(): return player.is_wall_grabbing() and player.position.y > takeoffs.x, 100, "Descend above the landing's projection")
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _x() < 500 and player.position.y > 370, 130, "Kick below the left step without resting on its spikes")
	await _until(func(): return player.position.y > takeoffs.y, 120, "Descend toward the open floor before the return kick")
	_drive("move_right", true, true)
	await _jump()
	_drive("move_right")
	await _until(func(): return _x() > 643, 100, "Clear the lower wall tip before braking")
	_release_inputs()
	await _until(func(): return player.is_on_floor() and _x() > 635 and _x() < 715, 140, "Rest on the safe underside after both wall transfers")


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
	if _model_index() in [3, 8] and target < 0:
		climb_y = 540 if wall_x == 280 else 500
	await _until(func(): return player.is_wall_grabbing() and (player.position.y > kick_y if inverted else player.position.y < climb_y), 110, "Climb to the gate's height at x=%d" % wall_x)
	if not moving_gate.is_empty():
		Input.action_release("move_up")
		Input.action_release("move_down")
		var gate: Area2D = _course_node(moving_gate)
		if gate.get("move_offset").x != 0:
			await _until(func(): return _course_local_x(gate.position.x) >= 1000 and _course_local_x(gate.position.x) <= 1030, 150, "Wait for the horizontal return gate")
		else:
			var low := 450 if target > 0 else 400
			await _until(func(): return gate.position.y >= low and gate.position.y <= low + 20 and gate.get("_toward_b"), 200, "Hold the wall until the small moving gate reaches the kick path")
	await _jump()
	Input.action_release("wall_grab")
	Input.action_release("move_up")
	Input.action_release("move_down")
	await _until(func(): return player.gravity_direction == target, 70, "A wall kick must enter the gravity gate")
	_check_status()
	_drive("move_right")


func _reach_goal() -> void:
	_drive("move_right")
	var goal: ArrivalSwitch = stage.rooms.get_child(stage.room_index).get_node("Goal")
	var menu_during_press := false
	for frame in 320:
		if stage.cleared.has(stage.room_index):
			break
		if stage.room_index == 0 and goal.pressing:
			menu_during_press = true
			_release_inputs()
			await _key(KEY_ESCAPE)
			_check_help(true)
			await _step(20)
			_check(not goal.is_pressed() and not stage.cleared.has(0), "Pausing freezes the arrival press before completion")
			await _key(KEY_ESCAPE)
			_check_help(false)
			await _step(20)
			_check(goal.is_pressed() and stage.cleared.has(0), "The arrival press completes after resuming")
			break
		FullJumpInput.release_after_apex(player)
		if _x() >= 1140:
			Input.action_release("move_left" if _mirrored() else "move_right")
		elif player.is_on_floor() and player.is_on_wall():
			FullJumpInput.press(player)
		await _step()
	_release_inputs()
	if stage.room_index == 0:
		_check(menu_during_press, "Exercise opening help before the arrival press finishes")
	_check(stage.cleared.has(stage.room_index), "Reach and physically press the arrival switch")


func _drive(direction: String, grab := false, inverted := false) -> void:
	_release_inputs()
	if _mirrored():
		direction = "move_left" if direction == "move_right" else "move_right"
	Input.action_press(direction)
	if grab:
		Input.action_press("wall_grab")
		Input.action_press("move_down" if inverted else "move_up")


func _jump() -> void:
	FullJumpInput.press(player)
	await _step()
	FullJumpInput.release_after_apex(player)


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
	return _course_local_x(player.position.x - stage.rooms.get_child(stage.room_index).global_position.x)


func _course_local_x(local_x: float) -> float:
	local_x -= course_origin
	return 1280.0 - local_x if _mirrored() else local_x


func _mirrored() -> bool:
	return course_reversed if course_model >= 0 else stage.room_index == 6


func _model_index() -> int:
	return course_model if course_model >= 0 else stage.room_index


func _course_node(path: String) -> Node:
	return stage.rooms.get_child(stage.room_index).get_node(course_prefix + path)


func _reset_course() -> void:
	course_model = -1
	course_origin = 0
	course_reversed = false
	course_prefix = ""


func _set_part(index: int, part: int) -> void:
	course_model = MORE_SOURCES[index - 9][part] - 1
	course_reversed = index in [10, 13]
	course_origin = (1280 if index == 10 and part == 0 else 0) if course_reversed else part * 1280
	course_prefix = "A_" if part == 0 else "B_"


func _connect_composite_signals() -> void:
	var launch_events := {"LaunchSpring": "launch_spring", "ReturnSpring": "return_spring", "CeilingBumper": "bumper", "ExitSpring": "exit_spring", "CeilingSpring": "spring"}
	for node in stage.rooms.get_child(stage.room_index).get_children():
		if node.has_meta("route_connected"): continue
		if node.has_signal("launched"):
			var kind := ""
			for suffix in launch_events:
				if node.name.ends_with(suffix): kind = launch_events[suffix]
			if not kind.is_empty():
				node.launched.connect(func(_body): actions[kind] = actions.get(kind, 0) + 1)
				node.set_meta("route_connected", true)
		if node.has_signal("collected") and node.name.ends_with("JumpCrystal"):
			node.collected.connect(func(_body): actions["jump_crystal"] = actions.get("jump_crystal", 0) + 1)
			node.set_meta("route_connected", true)


func _composite_course(index: int, rest_frames := 180) -> void:
	_connect_composite_signals()
	for part in MORE_SOURCES[index - 9].size():
		_set_part(index, part)
		if index == 11:
			await _room_twelve_entry(jump_spacing)
		await _part_course()
		if failed: return
		if part < MORE_SOURCES[index - 9].size() - 1:
			_drive("move_right")
			await _until(func(): return _x() >= 1140 and player.is_on_floor() and player.gravity_direction == 1, 220, "Reach the real rest between the two challenges")
			_release_inputs()
			await _step(15)
			var rest: Vector2 = player.position
			await _step(rest_frames)
			_check(player.position.distance_to(rest) < 2 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "The seam offers a safe input-free rest before continuing")
			_drive("move_right")
			await _until(func(): return _x() > 1352, 100, "Walk from the rest into the second challenge without teleporting")
			_release_inputs()


func _part_course() -> void:
	match course_model:
		0:
			await _room_one_wall_course()
			_drive("move_right")
			await _until(func(): return actions.has("return_spring"), 160, "Use the ceiling Spring after the wall kicks")
			await _until(func(): return player.gravity_direction == 1, 100, "Return through Down gravity")
		1:
			await _room_two_wall_course()
			_drive("move_right")
			await _until(func(): return actions.has("bumper"), 180, "Cross the real rebound before the exit wall")
			await _kick_gate(1060, 1, "", true)
		2:
			await _kick_gate(240, -1)
			await _cross_ceiling_pit(330, 470)
			await _cross_crystal_wall(jump_spacing)
		3:
			await _kick_gate(280, -1)
			await _cross_ceiling_pit(320, 450)
			await _kick_gate(580, 1)
			_drive("move_right")
			await _until(func(): return player.is_on_floor() and _x() > 580, 120, "Rest before the inner floor gap")
			await _jump()
			await _kick_gate(840, -1)
			await _cross_ceiling_pit(850, 1020)
			if stage.room_index == 12:
				await _room_thirteen_descent(jump_spacing)
			else:
				await _kick_gate(1100, 1, "DownGate")
		4:
			await _kick_gate(360, -1, "UpGate")
			await _cross_ceiling_pit(330, 470)
			await _cross_floating_spring()
		5:
			await _room_fifteen_course()
		7: await _room_eight_course(jump_spacing)
		8: await _room_nine_course()


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
	var hints := get_nodes_in_group("stage_3_hints")
	var labels := hints.filter(func(hint): return hint is Label)
	var routes := hints.filter(func(hint): return hint is Line2D)
	_check(stage.hints_visible == expected and not labels.is_empty() and labels.all(func(hint): return hint.visible == expected), "All explanation labels follow the hint setting")
	_check(not routes.is_empty() and routes.all(func(hint): return hint.visible == expected), "Route lines and arrowheads follow the optional hint setting")
	_check(stage.get_node("HUD/Margin/Panel/Rows/Title").text.contains(stage.HINTS[stage.room_index]) == expected, "HUD explanations follow the hint setting")
	_check(stage.rooms.get_child(1).get_node("UpGate/Arrow").visible and stage.get_node("HUD/Status").visible, "Mechanism directions and player resources stay visible")


func _toggle_hints() -> void:
	await _key(KEY_ESCAPE)
	await _click(stage.get_node("PauseMenu/Overlay/Center/Panel/Rows/Menu/Hints"))
	await _key(KEY_ESCAPE)


func _check_help(expected: bool) -> void:
	_check(paused == expected and stage.get_node("PauseMenu/Overlay").visible == expected, "The help menu follows its setting and starts closed")
	_check(stage.get_node("PauseMenu/Overlay/Center/Panel/Rows/Menu/Return").is_visible_in_tree() == expected, "Return and hint controls stay inside the help menu")
	_check(player.can_process() != expected, "Opening the menu stops the player and closing resumes it")
	_check((root.gui_get_focus_owner() != null) == expected, "Only the open help menu owns keyboard and controller focus")


func _check_status() -> void:
	var status: Control = stage.get_node("HUD/Status")
	var gauge: ProgressBar = stage.get_node("HUD/Status/Rows/Stamina")
	var bottom := status.position.y > 360
	_check((stage.get_node("HUD/Margin/Panel/Rows/Title").get_global_rect().position.y > 360) == bottom, "The room title stays on the same side as the stamina gauge during the delayed layout change")
	_check((stage.get_node("HUD/PauseButton").position.y > 360) == bottom, "The help trigger stays on the same side as the stamina gauge")
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


func _gamepad_hints(button: JoyButton = JOY_BUTTON_BACK) -> void:
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
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-3")
	for index in stage.rooms.get_child_count():
		stage.call("_set_room", index, false)
		player.respawn()
		await _step(3)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-3/room_%d.png" % (index + 1))
		if index == 4:
			await _toggle_hints()
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-3/room_5_hints.png")
			await _toggle_hints()
			await _key(KEY_ESCAPE)
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-3/help_menu.png")
			await _key(KEY_ESCAPE)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _release_inputs() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		if action != "jump" or not FullJumpInput.is_holding():
			Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("STAGE_3: %s (room=%d pos=%s gravity=%d)" % [message, stage.room_index + 1 if stage != null else 0, player.position if player != null else Vector2.ZERO, player.gravity_direction if player != null else 0])


var third_strength := 1.0


func _third_x() -> float:
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	var local_x: float = player.position.x - room.global_position.x
	return float(room.get_meta("room_width")) - local_x if room.get_meta("third_mirror", false) else local_x


func _third_drive(target: float, grip := false) -> void:
	_release_inputs()
	var mirrored: bool = stage.rooms.get_child(stage.room_index).get_meta("third_mirror", false)
	var velocity := -player.velocity.x if mirrored else player.velocity.x
	var direction := (target - _third_x()) * 8.0 - velocity * 0.6
	if absf(direction) > 12:
		Input.action_press("move_left" if (direction > 0) == mirrored else "move_right", third_strength)
	if grip:
		Input.action_press("wall_grab")
		Input.action_press("move_down" if player.gravity_direction < 0 else "move_up")


func _third_walk(target: float, limit := 600) -> void:
	for frame in limit:
		_third_drive(target)
		if absf(_third_x() - target) < 4 and absf(player.velocity.x) < 35 and player.is_on_floor():
			_release_inputs()
			return
		await _step()
		if failed: return
	_check(false, "Reach the actual third-expansion rest x=%.1f (x=%.1f y=%.1f)" % [target,_third_x(),player.position.y])


func _third_dash(aim: Vector2) -> void:
	_release_inputs()
	if stage.rooms.get_child(stage.room_index).get_meta("third_mirror", false): aim.x *= -1
	if aim.x != 0: Input.action_press("move_right" if aim.x > 0 else "move_left", third_strength)
	if aim.y != 0: Input.action_press("move_down" if aim.y > 0 else "move_up")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")


func _third_rest() -> void:
	_release_inputs()
	await _step(15)
	var at := player.position
	await _step(180)
	_check(player.is_on_floor() and at.distance_to(player.position) < 2 and player.is_dash_ready(), "A real intermediate landing permits three seconds without input and refills Dash")


func _third_horizontal(gap := 20, land_only := false) -> void:
	await _third_walk(640)
	_third_drive(1300)
	await _jump()
	await _step(gap)
	await _third_dash(Vector2.RIGHT)
	await _until(func(): return not player.is_dashing(), 30, "The first horizontal Dash finishes")
	_check(player.is_dash_ready(), "The actual airborne Crystal refills the spent horizontal Dash")
	await _third_dash(Vector2.RIGHT)
	await _until(func(): return player.is_on_floor() and _third_x() > 1040, 120, "The second Dash reaches the real landing ceiling")
	if land_only:
		await _third_walk(1290)
		return
	await _third_walk(1500)


func _third_vertical(aim: Vector2, gap := 20, target_gravity := 1) -> void:
	_release_inputs()
	await _jump()
	await _step(gap)
	await _third_dash(aim)
	await _until(func(): return not player.is_dashing(), 30, "The first vertical Dash finishes")
	_check(player.is_dash_ready(), "The actual airborne Crystal refills the spent vertical Dash")
	await _third_dash(aim)
	await _until(func(): return player.gravity_direction == target_gravity and player.is_on_floor(), 240, "The second vertical Dash reaches the real gate and safe landing")


func _third_entry(index: int, gap := 20) -> void:
	match index:
		15, 17:
			await _third_walk(550)
		16:
			await _third_walk(800)
		18:
			await _third_shaft()
		19:
			await _third_walk(700)
			await _third_vertical(Vector2.UP, gap, -1)
		20:
			await _third_walk(450)
			await _third_vertical(Vector2.UP, gap, -1)
			await _third_walk(900)
	_check(player.gravity_direction == -1, "The intermediate rest follows the actual Up route")
	await _third_rest()
	await _third_capture("room_%d_rest" % (index+1))


func _third_course(index: int, gap := 20) -> void:
	await _third_entry(index, gap)
	match index:
		15, 17:
			await _third_horizontal(gap)
		16, 20:
			await _third_vertical(Vector2.DOWN, gap, 1)
		19:
			await _third_exit_high(gap)
		18:
			await _third_walk(850)
			await _jump()
			await _step(gap)
			await _third_dash(Vector2.DOWN)
			await _until(func(): return not player.is_dashing() and player.position.y > 530, 90, "Descend below the actual spiked dogleg")
			await _third_capture("room_19_corner")
			_check(player.is_dash_ready(), "The corner's real Crystal refills Dash")
			await _third_dash(Vector2(1, 1))
			_third_drive(1200)
			await _until(func(): return player.gravity_direction == 1 and player.is_on_floor(), 240, "The changed Dash direction passes below the spikes into Down")
	if not failed: await _third_goal()


func _third_exit_high(gap := 20) -> void:
	await _third_walk(1500)
	await _jump()
	await _step(gap)
	await _third_dash(Vector2.DOWN)
	await _until(func(): return player.gravity_direction == 1 and player.is_on_floor(), 180, "The descending Dash enters Down below the high left ceiling")


func _third_shaft(takeoff := 490.0, enter_gate := true) -> void:
	_third_drive(310, true)
	await _until(func(): return player.is_wall_grabbing() and player.position.y < 1004, 180, "Climb below the lower shaft cap")
	_third_drive(110, true)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _third_x() < 170 and player.position.y < 850, 180, "Kick to the opposing grip below its projection")
	_third_drive(310, true)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _third_x() > 250 and player.position.y < 704, 180, "Kick back above the lower lip")
	_third_drive(110, true)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _third_x() < 170 and player.position.y < takeoff, 180, "Reach the high grip above both projections")
	if not enter_gate: return
	_third_drive(480, true)
	await _jump()
	await _until(func(): return player.gravity_direction == -1, 180, "The last wall kick enters Up gravity")
	await _third_walk(700)


func _third_goal() -> void:
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	var goal_x := float(room.get_meta("room_width")) - 104.0
	for frame in 600:
		if stage.cleared.has(stage.room_index):
			_release_inputs()
			await _third_capture("room_%d_arrival" % (stage.room_index+1))
			return
		_third_drive(goal_x, true)
		if player.is_on_floor() and player.is_on_wall(): await _jump()
		await _step()
		if failed: return
	_check(false, "Physically press the third-expansion arrival switch")


func _third_capture(_name: String) -> void:
	pass


var para_strength := 1.0
var para_gap := 20


func _para_x() -> float:
	return player.position.x-stage.rooms.get_child(stage.room_index).position.x


func _para_drive(target: float, grip := false) -> void:
	_release_inputs()
	var direction := (target-_para_x())*8.0-player.velocity.x*0.6
	if absf(direction)>12: Input.action_press("move_right" if direction>0 else "move_left", para_strength)
	if grip or player.get_held_object() != null: Input.action_press("wall_grab")


func _para_walk(target: float, limit := 600) -> void:
	for frame in limit:
		_para_drive(target)
		if absf(_para_x()-target)<4 and absf(player.velocity.x)<35 and player.is_on_floor():
			_release_inputs()
			if player.get_held_object()!=null: Input.action_press("wall_grab")
			return
		await _step()
		if failed: return
	_check(false,"Reach static para rest x=%.1f (x=%.1f y=%.1f g=%d floor=%s deaths=%d)"%[target,_para_x(),player.position.y,player.gravity_direction,player.is_on_floor(),respawns])


func _para_grab() -> void:
	var room: Node2D=stage.rooms.get_child(stage.room_index)
	var creature: Node2D=room.get_node("Parachute")
	var approach: float = creature.position.x+(-40 if _para_x()<creature.position.x else 40)
	await _para_walk(clampf(approach, 54, float(room.get_meta("room_width", 1280.0))-54))
	_release_inputs()
	Input.action_press("wall_grab")
	await _step()

	_check(player.get_held_object()==creature,"Grab the actual room's Parachute")


func _para_rise(wind_x: float, target_y: float, rest_x: float, phase := "wind") -> void:
	_para_drive(wind_x)
	await _until(func(): return absf(_para_x()-wind_x)<15,160,"Enter the actual vertical wind")
	for frame in 650:
		_para_drive(wind_x)
		if (player.position.y-target_y)*player.gravity_direction<0: break
		await _step()
		if failed: return
	_check((player.position.y-target_y)*player.gravity_direction<0,"The held Parachute rises against the current gravity (p=%s)"%player.position)
	await _para_capture("room_%d_%s"%[stage.room_index+1,phase])
	await _para_walk(rest_x,350)


func _para_rest(phase := "rest") -> void:
	_release_inputs()
	Input.action_press("wall_grab")
	await _step(15)
	var point := player.position
	await _step(30)
	_check(player.is_on_floor() and player.position.distance_to(point)<2 and player.is_dash_ready(),"A static landing supports observation and restores Dash")
	if (stage.room_index==23 and phase=="ceiling") or (stage.room_index==24 and phase=="deep_rest"):
		var arrow:Control=stage.rooms.get_child(stage.room_index).get_node("DownGate/Arrow")
		var bounds:=Rect2(arrow.get_global_transform_with_canvas()*Vector2.ZERO,arrow.size)
		_check(root.get_visible_rect().encloses(bounds),"The whole next Down arrow is visible from the static takeoff before descending Dash")
	await _para_capture("room_%d_%s"%[stage.room_index+1,phase])


func _para_start(index: int) -> void:
	await _para_grab()
	match index:
		21: await _para_rise(450,850,820)
		22:
			_para_drive(2100)
			await _until(func(): return player.gravity_direction==-1,180,"Walk into Up before the deep inverted wind")
			await _para_walk(2100)
		23: await _para_rise(1900,850,1550)
		24: await _para_rise(450,620,820)
	await _para_rest("entry_rest")


func _para_flip_rest(index: int) -> void:
	if index==22: return
	_para_drive(1150 if index==23 else 1250)
	await _jump()
	await _until(func(): return player.gravity_direction==-1,180,"The high rest leads through the actual Up gate")
	await _para_walk(1100 if index==23 else (1450 if index==21 else 1180))
	await _para_rest("ceiling")


func _para_deep_rest(index: int) -> void:
	if index==22: await _para_rise(1670,950,1400)
	else: await _para_rise(1470,1100,1800,"reverse_wind")
	await _para_rest("deep_rest")


func _para_course(index: int) -> void:
	var start := Engine.get_physics_frames()
	var before_respawns := respawns
	await _para_start(index)
	await _para_flip_rest(index)
	if index in [22,24]: await _para_deep_rest(index)
	if index in [23,24]: await _para_vertical(1100 if index==23 else 1880)
	if failed: return
	if index in [21,22]:
		_para_drive(1950 if index==21 else 1050)
		await _jump()
		await _until(func(): return player.gravity_direction==1,240,"Glide from the final ceiling into Down")
	await _para_walk([2000,1000,900,2000][index-21])
	if failed: return
	await _para_goal()
	var seconds := float(Engine.get_physics_frames()-start)/60.0
	_check(seconds<30 and respawns==before_respawns,"The real course finishes without death within thirty seconds (%.2fs)"%seconds)
	_check(flips.has(-1) and flips.has(1),"The real route uses both gravity directions")
	print("GRAVITY_PARACHUTE_%d %.2fs axis=%.2f gap=%d dash=%d crystal=%d"%[index+1,seconds,para_strength,para_gap,actions.get("dash",0),actions.get("crystal",0)])


func _para_vertical(takeoff: float) -> void:
	await _para_walk(takeoff)
	_release_inputs()
	Input.action_press("wall_grab")
	await _jump()
	await _step(para_gap)
	await _para_dash(Vector2.DOWN)
	_release_inputs()
	Input.action_press("wall_grab")
	await _until(func(): return actions.has("crystal") and not player.is_dashing(),90,"Touch the real refill after spending the descending Dash")
	_check(player.is_dash_ready(),"The airborne Crystal restores Dash")
	await _para_capture("room_%d_refill"%(stage.room_index+1))
	await _para_dash(Vector2.DOWN)
	_para_drive(900 if stage.room_index==23 else 2000)
	await _until(func(): return player.gravity_direction==1 and player.is_on_floor(),240,"The second descending Dash reaches Down and a static floor")
	await _para_rest("exit_floor")


func _para_dash(aim: Vector2) -> void:
	_release_inputs()
	Input.action_press("wall_grab")
	if aim.x!=0: Input.action_press("move_right" if aim.x>0 else "move_left",para_strength)
	if aim.y!=0: Input.action_press("move_down" if aim.y>0 else "move_up")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")


func _para_goal() -> void:
	var goal: Node2D=stage.rooms.get_child(stage.room_index).get_node("Goal")
	for frame in 360:
		if stage.cleared.has(stage.room_index):
			_release_inputs()
			Input.action_press("wall_grab")
			await _para_capture("room_%d_arrival"%(stage.room_index+1))
			return
		_para_drive(goal.position.x,true)
		if player.is_on_floor() and player.is_on_wall(): await _jump()
		await _step()
		if failed:return
	_check(false,"Physically press the actual room arrival")


func _para_capture(_name: String) -> void:
	pass


func _fifth_connect() -> void:
	for index in range(25, 31):
		var room: Node2D = stage.rooms.get_child(index)
		for area in room.find_children("*", "Area2D", true, false):
			if area.has_signal("launched"):
				area.launched.connect(func(_body): actions["fifth_spring"] = actions.get("fifth_spring", 0)+1)
			if area.has_signal("collected"):
				var key := "fifth_crystal" if area.refill_kind == 0 else "fifth_boots"
				area.collected.connect(func(_body): actions[key] = actions.get(key, 0)+1)


func _fifth_floor(name: String) -> bool:
	if not player.is_on_floor(): return false
	for index in player.get_slide_collision_count():
		if player.get_slide_collision(index).get_collider() == stage.rooms.get_child(stage.room_index).get_node(name): return true
	return false


func _fifth_rest(phase: String) -> void:
	_release_inputs()
	if player.get_held_object() != null: Input.action_press("wall_grab")
	await _step(12)
	var point := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(point) < 2 and player.is_dash_ready(), "The actual intermediate surface allows three seconds of rest and a fresh departure")
	if stage.room_index==30 and phase=="entry_rest":
		var room: Node2D = stage.rooms.get_child(stage.room_index)
		var arrow: Control = room.get_node("DownGate/Arrow")
		_check(root.get_visible_rect().encloses(Rect2(arrow.get_global_transform_with_canvas()*Vector2.ZERO,arrow.size)),"The next left Down arrow is fully visible before the recovery jump")
		var landing: CollisionShape2D = room.get_node("LandingCeiling/Collision")
		var bounds := Rect2(landing.get_global_transform_with_canvas()*landing.shape.get_rect().position,landing.shape.get_rect().size)
		_check(root.get_visible_rect().intersection(bounds).size.x>240 and bounds.position.y>0 and bounds.end.y<root.get_visible_rect().size.y,"More than 240 pixels of the next left static ceiling are visible from the actual rest")
	if stage.room_index==28 and phase=="spring_rest":
		var arrow: Control = stage.rooms.get_child(28).get_node("DownGate/Arrow")
		var bounds := Rect2(arrow.get_global_transform_with_canvas()*Vector2.ZERO,arrow.size)
		_check(root.get_visible_rect().encloses(bounds),"The deep Down arrow is visible from the actual pre-Spring rest")
		for panel in [stage.get_node("HUD/Margin/Panel"),stage.get_node("HUD/PauseButton"),stage.get_node("HUD/Status")]:
			_check(not panel.visible or not panel.get_global_rect().intersects(bounds),"The deep Down arrow stays clear of visible HUD")
	await _fifth_capture("room_%d_%s" % [stage.room_index+1, phase])


func _fifth_grip(target: float) -> void:
	_para_drive(target, true)
	Input.action_press("move_up")


func _fifth_shaft(origin: float = 0) -> void:
	_fifth_grip(origin+310)
	await _until(func(): return player.is_wall_grabbing() and player.position.y < 1004, 180, "Climb below the actual lower projection")
	_fifth_grip(origin+110)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _para_x() < origin+170 and player.position.y < 850, 180, "Kick to the opposing native grip")
	_fifth_grip(origin+310)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _para_x() > origin+250 and player.position.y < 704, 180, "Kick above the lower projection")
	_fifth_grip(origin+110)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _para_x() < origin+170 and player.position.y < 490, 180, "Kick to the high grip above both projections")
	_fifth_grip(origin+480)
	await _jump()
	await _until(func(): return player.gravity_direction == -1, 180, "The final real kick enters the native Up gate")
	await _para_walk(origin+700)


func _fifth_horizontal_left(takeoff: float, target: float) -> void:
	await _para_walk(takeoff)
	_para_drive(target)
	await _jump()
	await _step(para_gap)
	var before := int(actions.get("fifth_crystal",0))
	await _para_dash(Vector2.LEFT)
	await _until(func(): return not player.is_dashing() and actions.get("fifth_crystal",0)>before, 60, "The first actual left Dash finishes and its real Crystal contact notification arrives")
	_check(player.is_dash_ready() and actions.get("fifth_crystal",0)>before, "The native airborne Crystal actually refills the spent left Dash")
	await _para_dash(Vector2.LEFT)
	_para_drive(target)
	await _until(func(): return _fifth_floor("LandingCeiling"), 180, "The second actual Dash lands under the left ceiling")
	await _para_walk(target)


func _fifth_release_toward(target: float) -> void:
	var direction := signf(target-_para_x())
	_para_drive(target)
	await _step(8)
	Input.action_release("wall_grab")
	await _step()
	_release_inputs()
	_check(player.get_held_object() == null and stage.rooms.get_child(stage.room_index).get_node("Parachute").linear_velocity.x * direction > 300, "Moving release actually throws the real umbrella in the declared direction")


func _fifth_entry(index: int) -> void:
	match index:
		25:
			await _fifth_shaft()
		26, 28:
			await _para_walk(1800)
			_check(player.gravity_direction == -1, "The right entrance enters Up and reaches its ceiling naturally")
		27:
			await _para_grab()
			await _para_rise(450, 1060, 650)
			await _fifth_rest("wind_rest")
			await _fifth_after_wind(index)
		29:
			await _para_walk(300)
			_check(player.is_air_jump_ready() and actions.get("fifth_boots",0)>0, "The real entrance boots supply an extra airborne Jump")
			await _jump()
			await _step(para_gap)
			await _jump()
			await _step(para_gap)
			_check(actions.get("air_jump",0) == 1, "The second real Jump consumes the actual extra charge")
			await _para_dash(Vector2.UP)
			_release_inputs()
			await _until(func(): return actions.get("fifth_crystal",0)>0 and not player.is_dashing(), 90, "The boosted ascent reaches the actual high recovery Crystal")
			_check(player.is_dash_ready(), "The high Crystal restores a spent upward Dash")
			await _fifth_capture("room_30_refill")
			await _para_dash(Vector2.UP)
			_para_drive(650)
			await _until(func(): return player.gravity_direction == -1 and _fifth_floor("UpperRest"), 240, "The recovered upward Dash reaches Up and the real high ceiling")
			await _para_walk(650)
		30:
			await _para_grab()
			await _para_rise(1900, 620, 1550)
			await _fifth_rest("wind_rest")
			await _fifth_after_wind(index)
	await _fifth_rest("entry_rest")


func _fifth_after_wind(index: int) -> void:
	if index == 27:
		await _fifth_release_toward(600)
		await _para_walk(820)
		_check(player.get_held_object() == null, "Walk bare under the low projection before using Grab on the shaft")
		await _fifth_shaft(600)
	else:
		await _fifth_release_toward(1250)
		_para_drive(1250)
		await _jump()
		await _until(func(): return player.gravity_direction == -1, 180, "The leftward flight enters the real Up gate")
		await _para_walk(1250)


func _fifth_course(index: int, entered := false) -> void:
	var start := Engine.get_physics_frames()
	var before := respawns
	if not entered: await _fifth_entry(index)
	match index:
		25,27:
			await _para_walk(830 if index == 25 else 1430)
			_para_drive(1200 if index == 25 else 1700)
			await _jump()
			await _step(para_gap)
			await _para_dash(Vector2.RIGHT)
			await _para_walk(1200 if index == 25 else 1800)
			_check(player.gravity_direction == 1 and _fifth_floor("ExitFloor"), "The real ceiling departure enters Down and the original exit floor")
		26:
			await _fifth_horizontal_left(1664,1000)
			await _fifth_rest("landing_rest")
			_para_drive(804)
			await _until(func(): return player.gravity_direction == 1, 180, "The left landing leads into the actual Down gate")
			await _para_walk(700)
		28:
			await _para_walk(1664)
			_para_drive(1200)
			await _jump()
			await _step(para_gap)
			await _para_dash(Vector2.LEFT)
			_para_drive(1200)
			await _until(func(): return _fifth_floor("MiddleCeiling"), 180, "The left Dash crosses the real headwind into the middle ceiling")
			await _para_walk(1200)
			await _fifth_rest("spring_rest")
			_para_drive(800)
			await _until(func(): return actions.get("fifth_spring",0)>0, 180, "The inverted route contacts the real ceiling Spring")
			await _fifth_capture("room_29_spring")
			await _para_walk(800)
			_check(player.gravity_direction == 1 and _fifth_floor("ExitFloor"), "The actual Spring reaches the deep Down and the left exit floor")
		29:
			await _para_walk(970)
			_para_drive(1080)
			await _jump()
			await _step(para_gap)
			await _para_dash(Vector2.DOWN)
			await _para_walk(1200)
			_check(player.gravity_direction == 1 and _fifth_floor("ExitFloor"), "The high ceiling's descending Dash enters Down above the right safe floor")
		30:
			await _fifth_horizontal_left(1150,550)
			await _fifth_rest("landing_rest")
			_para_drive(400)
			await _jump()
			await _until(func(): return player.gravity_direction == 1, 180, "The left ceiling's actual inverted Jump reaches Down")
			await _para_walk(500)
	if failed: return
	if index == 30:
		var creature: Node2D = stage.rooms.get_child(index).get_node("Parachute")
		_check(player.get_held_object() == null and creature.global_position.distance_to(player.global_position) > 150, "The genuinely thrown umbrella stays clear of the actual final descent and landing")
	await _fifth_capture("room_%d_exit_floor" % [index+1])
	await _fifth_goal()
	if failed: return
	if failed: return
	var seconds := float(Engine.get_physics_frames()-start)/60.0
	_check(respawns == before and seconds < 30, "The complete real course reaches its arrival without death within thirty seconds (%.2fs)" % seconds)
	_check(flips.has(-1) and flips.has(1), "Each new main route physically uses both gravity directions")
	print("GRAVITY_FIFTH_%d %.2fs axis=%.1f gap=%d dash=%d crystal=%d kicks=%d" % [index+1,seconds,para_strength,para_gap,actions.get("dash",0),actions.get("fifth_crystal",0),actions.get("wall_jump",0)])


func _fifth_capture(_name: String) -> void:
	pass


func _fifth_goal() -> void:
	var goal: Node2D = stage.rooms.get_child(stage.room_index).get_node("Goal")
	for frame in 360:
		if stage.cleared.has(stage.room_index):
			_release_inputs()
			if player.get_held_object() != null: Input.action_press("wall_grab")
			await _fifth_capture("room_%d_arrival" % [stage.room_index+1])
			return
		_para_drive(goal.position.x)
		if player.is_on_floor() and player.is_on_wall(): await _jump()
		await _step()
		if failed: return
	_check(false, "Physically press the new room's actual arrival")


func _sixth_connect() -> void:
	for room in stage.rooms.get_children().slice(31,37):
		for area in room.find_children("*","Area2D",true,false):
			if area.has_signal("launched"): area.launched.connect(func(_body):
				actions["sixth_launch"] = actions.get("sixth_launch",0)+1
			)
			if area.has_signal("collected"):
				var key := "sixth_crystal" if area.refill_kind==0 else "sixth_boots"
				area.collected.connect(func(_body): actions[key] = actions.get(key,0)+1)


func _sixth_entry(index: int) -> void:
	match index:
		31:
			_para_drive(360)
			await _until(func(): return player.gravity_direction==-1,240,"The native Spring ascent reaches the high Up gate")
			await _para_walk(800)
			await _fifth_rest("entry_rest")
		32:
			await _para_walk(1800)
			await _fifth_rest("entry_rest")
		33:
			await _para_walk(1720)
			_check(player.gravity_direction==-1 and player.is_air_jump_ready(),"The real inverted ceiling supplies the optional extra-Jump charge")
			await _fifth_rest("entry_rest")
		34:
			await _para_grab()
			await _para_walk(1800)
			await _fifth_rest("entry_rest")
		35:
			await _fifth_shaft()
			await _fifth_rest("entry_rest")
		36:
			await _para_walk(1800)
			await _fifth_rest("entry_rest")


func _sixth_course(index: int) -> void:
	var started := Engine.get_physics_frames()
	var before := respawns
	await _sixth_entry(index)
	match index:
		31:
			_sixth_down_grip(910)
			await _until(func(): return player.is_wall_grabbing(),180,"Reach the actual inverted grip")
			await _step(para_gap)
			_sixth_down_grip(710)
			await _jump()
			await _until(func(): return player.is_wall_grabbing() and _para_x()<770 and player.position.y>550,180,"Inverted kick reaches the opposing deeper grip")
			_sixth_down_grip(910)
			await _jump()
			await _until(func(): return player.is_wall_grabbing() and _para_x()>850 and player.position.y>696,180,"Kick below the first actual projection")
			_sixth_down_grip(710)
			await _jump()
			await _until(func(): return player.is_wall_grabbing() and _para_x()<770 and player.position.y>910,180,"Kick reaches the final deeper opposing wall")
			_sixth_down_grip(1080)
			await _jump()
			await _until(func(): return player.gravity_direction==1,180,"The final inverted kick enters Down")
			await _para_walk(1300)
			await _fifth_rest("landing_rest")
			_check(actions.get("wall_jump",0)>=4 and actions.get("sixth_launch",0)>0,"The route actually uses the Spring and inverted wall kicks")
		32:
			await _para_walk(1690)
			await _jump()
			await _step(para_gap)
			_para_drive(1760)
			await _until(func(): return actions.get("sixth_launch",0)>0,120,"The actual inverted jump returns into the circular bumper")
			_para_drive(800)
			await _until(func(): return _fifth_floor("LandingCeiling"),240,"The reflected trajectory reaches the native deeper left ceiling")
			await _para_walk(800)
			await _fifth_rest("landing_rest")
			await _para_walk(450)
			_para_drive(300)
			await _jump()
			await _step(para_gap)
			await _para_dash(Vector2.DOWN)
			for frame in 180:
				if player.gravity_direction==1: break
				_para_drive(300)
				await _step()
			await _para_walk(500)
			_check(player.gravity_direction==1 and _fifth_floor("ExitFloor"),"The real moving Down gate returns the route to the left floor")
		33:
			await _para_walk(1664)
			_para_drive(1450)
			await _jump()
			await _sixth_travel(1450,para_gap)
			await _jump()
			await _sixth_travel(1450,para_gap)
			_check(actions.get("air_jump",0)==1,"The deeper inverted step consumes one real extra Jump")
			await _para_dash(Vector2.DOWN)
			_para_drive(1200)
			await _until(func(): return _fifth_floor("LandingCeiling"),240,"The real extra Jump and downward Dash reach the deeper left ceiling")
			await _para_walk(1200)
			await _fifth_rest("landing_rest")
			_para_drive(850)
			await _jump()
			await _step(para_gap)
			await _para_dash(Vector2.DOWN)
			await _para_walk(700)
		34:
			var takeoff := 1800.0 + (para_gap - 20) * 4.0
			await _para_walk(takeoff)
			print("SIXTH_GLIDE_TAKEOFF axis=",para_strength," gap=",para_gap," requested=",takeoff," actual=",_para_x())
			_para_drive(800)
			await _jump()
			await _step(para_gap)
			await _until(func(): return player.gravity_direction==1,180,"The held umbrella route enters the actual Down before gliding")
			await _para_walk(800)
			await _fifth_rest("landing_rest")
			await _para_walk(550)
			_check(player.get_held_object()==stage.rooms.get_child(index).get_node("Parachute"),"The crosswind glide keeps the actual umbrella through its static landing")
		35:
			await _para_walk(830)
			_para_drive(1100)
			await _jump()
			await _step(para_gap)
			await _para_dash(Vector2(1,1))
			await _until(func(): return not player.is_dashing() and actions.get("sixth_crystal",0)>0,60,"The real diagonal Dash reaches the airborne refill and finishes")
			_check(player.is_dash_ready(),"Actual diagonal contact restores the spent Dash")
			_para_drive(1100)
			await _until(func(): return player.position.y>450,30,"The actual diagonal descent clears the hanging corner before the recovered Dash")
			await _para_dash(Vector2(1,1))
			_para_drive(1500)
			await _until(func(): return player.gravity_direction==1 and _fifth_floor("LandingFloor"),240,"The second diagonal Dash rounds the native corner and reaches Down above its visible safe landing")
			await _para_walk(1500)
			await _fifth_rest("landing_rest")
		36:
			_para_drive(1620)
			await _until(func(): return actions.get("sixth_launch",0)>0,180,"The actual inverted ceiling Spring begins the first downward leg")
			await _para_walk(1620)
			_check(player.gravity_direction==1 and _fifth_floor("MiddleFloor"),"The first native Down reaches the middle safe floor")
			await _fifth_rest("middle_rest")
			await _para_walk(1100)
			_fifth_grip(990)
			await _jump()
			await _sixth_mirrored_shaft()
			await _para_walk(600)
			await _fifth_rest("upper_rest")
			await _para_walk(800)
			_para_drive(500)
			await _jump()
			await _step(para_gap)
			await _para_dash(Vector2(-1,1))
			await _para_walk(500)
		_:
			_check(false,"The requested native sixth room has a real driver")
	await _fifth_goal()
	var seconds := float(Engine.get_physics_frames()-started)/60.0
	_check(respawns==before and stage.cleared.has(index) and seconds<30,"The actual native route reaches its arrival within thirty seconds without death")
	_check(flips.has(-1) and flips.has(1),"The mandatory route really uses both gravities and leaves all scrolls optional")
	print("GRAVITY_SIXTH_%d %.2fs axis=%.1f gap=%d kicks=%d launch=%d refill=%d" % [index+1,seconds,para_strength,para_gap,actions.get("wall_jump",0),actions.get("sixth_launch",0),actions.get("sixth_crystal",0)])


func _sixth_down_grip(target: float) -> void:
	_para_drive(target,true)
	Input.action_press("move_down")


func _sixth_travel(target: float,frames: int) -> void:
	for frame in frames:
		_para_drive(target)
		await _step()


func _sixth_mirrored_shaft() -> void:
	_fifth_grip(990)
	await _until(func(): return player.is_wall_grabbing() and player.position.y<1004,180,"Climb below the mirrored lower projection")
	_fifth_grip(1190)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _para_x()>1130 and player.position.y<850,180,"Kick right to the real opposing grip")
	_fifth_grip(990)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _para_x()<1050 and player.position.y<704,180,"Kick left above the native projection")
	_fifth_grip(1190)
	await _jump()
	await _until(func(): return player.is_wall_grabbing() and _para_x()>1130 and player.position.y<490,180,"Kick above the final mirrored projection")
	_fifth_grip(820)
	await _jump()
	await _until(func(): return player.gravity_direction==-1,180,"The real leftward kick enters Up beyond the shaft")


func _sixth_capture(_name: String) -> void:
	pass
