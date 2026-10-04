extends SceneTree

var failed := false
var checks := 0
var crystal_collections := 0
var airborne_dashes := 0
var stage: Node2D
var player: PlayerController
var screenshots := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	screenshots = OS.get_cmdline_user_args().has("--screenshots")
	if screenshots:
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-2")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	await _click(current_scene.get_node("Margin/Content/Stages/Stage2"))
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "Mouse must start stage 2")
	stage = current_scene
	player = stage.player
	_check(stage.room_index == 0 and stage.rooms.get_child_count() == 6, "Start at room 1 of six")
	_check(player.wall_actions_enabled and player.dash_enabled, "Actions must be available from the beginning")
	_check(stage.get_node("HUD/Margin/Panel/Rows/Gravity").visible, "Gravity must be visible in every room")
	for room in stage.rooms.get_children():
		_check(not room.get_node("Goal").locked, "Arrival switches must be unlocked without prescribed actions")
	stage.get_node("Rooms/Room4/DashCrystal").collected.connect(_on_crystal)
	player.movement_action.connect(_on_action)
	var inverted_rooms: Array[int] = []
	for index in 6:
		_check(stage.room_index == index, "Course must enter each room in order")
		await _screenshot("room_%d" % (index + 1))
		var saw_up := false
		var saw_down := false
		var jumped_for_crystal := false
		var first_dash := false
		var second_dash := false
		Input.action_press("move_right")
		for frame in 650:
			var local_x := player.global_position.x - index * 1280.0
			saw_up = saw_up or player.gravity_direction < 0
			saw_down = saw_down or (saw_up and player.gravity_direction > 0)
			Input.action_release("jump")
			Input.action_release("dash")
			if player.is_on_floor() and player.is_on_wall():
				Input.action_press("jump")
			if index == 3:
				if not jumped_for_crystal and local_x >= 360 and player.is_on_floor():
					Input.action_press("jump")
					jumped_for_crystal = true
				elif jumped_for_crystal and not first_dash and local_x >= 420 and not player.is_on_floor():
					Input.action_press("dash")
					first_dash = true
				elif first_dash and not second_dash and crystal_collections > 0 and player.is_dash_ready() and not player.is_dashing() and not player.is_on_floor():
					Input.action_press("dash")
					second_dash = true
			if local_x >= 1190:
				Input.action_release("move_right")
			if stage.cleared.has(index):
				break
			await _step()
		_release_inputs()
		_check(stage.cleared.has(index), "Room %d must be playable from its entrance with real inputs" % (index + 1))
		if index in [2, 4, 5]:
			_check(saw_up and saw_down, "Gravity route must reach the ceiling and return to the floor")
			inverted_rooms.append(index)
		if index < 5:
			Input.action_press("move_right")
			for frame in 90:
				if stage.room_index != index:
					break
				await _step()
			_release_inputs()
			_check(stage.transitioning and not player.controls_enabled, "Room boundary must freeze controls during the camera slide")
			await _step(25)
			_check(stage.room_index == index + 1 and player.controls_enabled, "Next room must resume safely")
	_check(inverted_rooms.size() == 3, "Three easy rooms must use gravity reversal")
	_check(crystal_collections > 0 and airborne_dashes >= 2, "Crystal practice must allow airborne dash refill and a second dash")
	_check(stage.completed and stage.get_node("HUD/Completion").visible, "Final arrival must display completion")
	await _screenshot("completed")
	await _key(KEY_R)
	_check(stage.room_index == 5 and stage.completed and player.gravity_direction == 1, "Retry must keep completed rooms and restore down gravity")
	_check(player.global_position.x < 5 * 1280 + 100 and player.is_dash_ready(), "Retry must restore the current entrance and dash")
	player.global_position.y = 800
	await _step(3)
	_check(stage.room_index == 5 and player.global_position.y < 720, "Falling must return to the current room")
	player.set_gravity_direction(-1)
	player.global_position.y = -60
	await _step(3)
	_check(player.gravity_direction == 1 and player.global_position.y > 0, "Falling above the screen must also restore down gravity")
	Input.action_press("move_left")
	for frame in 60:
		if stage.room_index == 4:
			break
		await _step()
	_release_inputs()
	await _step(25)
	_check(stage.room_index == 4 and stage.completed and stage.cleared.size() == 6, "Backtracking must preserve cleared rooms")
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Esc must return to selection")
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "Keyboard must start stage 2")
	stage = current_scene
	_check(stage.room_index == 0 and stage.cleared.is_empty() and not stage.completed, "A new play must reset progress")
	stage.call("_transition_to", 1)
	await _joy_button(JOY_BUTTON_BACK)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Back must return during a transition")
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	await _joy_button(JOY_BUTTON_A)
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "Gamepad must start stage 2 and skip unavailable stages")
	_check(current_scene.get_node("HUD/ReturnToStageSelect").focus_mode == Control.FOCUS_NONE, "Jump must not focus the return button")
	await _click(current_scene.get_node("HUD/ReturnToStageSelect"))
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Mouse button must return to selection")
	if screenshots:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-selection.png")
	print("STAGE_2_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _on_crystal(_body: PlayerController) -> void:
	crystal_collections += 1


func _on_action(action: String) -> void:
	if action == "dash" and not player.is_on_floor():
		airborne_dashes += 1


func _screenshot(filename: String) -> void:
	if screenshots:
		await _step(3)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-2/%s.png" % filename)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	await _press(event)


func _joy_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	await _press(event)


func _press(event: InputEvent) -> void:
	event.set("pressed", true)
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.set("pressed", false)
	Input.parse_input_event(event)
	await _step(3)


func _click(button: Button) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await _step()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = motion.position
	event.global_position = motion.position
	event.pressed = true
	root.push_input(event, true)
	await _step()
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _step(3)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _release_inputs() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("STAGE_2: " + message)
		quit(1)
