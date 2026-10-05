extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/stage_select.tscn", "F5 must start at stage selection")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _step(3)
	var menu := current_scene
	var stages: HBoxContainer = menu.get_node("Margin/Content/Stages")
	_check(stages.get_child_count() == 5, "Show exactly five stages")
	_check(root.gui_get_focus_owner() == stages.get_child(0), "Stage 1 must initially have keyboard/gamepad focus")
	_check(not stages.get_child(0).disabled, "Tutorial must be playable")
	_check(not stages.get_child(1).disabled and stages.get_child(1).focus_mode == Control.FOCUS_ALL, "Stage 2 must be playable and focusable")
	_check(stages.get_child(1).text.begins_with("ステージ 2") and stages.get_child(1).position.x > stages.get_child(0).position.x, "Stage 2 follows stage 1")
	for index in range(2, 5):
		var button: Button = stages.get_child(index)
		_check(button.text.begins_with("ステージ %d" % (index + 1)) and button.text.contains("準備中"), "Stage numbers must increase from left to right and show availability")
		_check(button.position.x > stages.get_child(index - 1).position.x, "Stage cards must be horizontal")
		_check(button.disabled and button.focus_mode == Control.FOCUS_NONE, "Unavailable stages cannot be played or focused")
		await _click(button)
		_check(current_scene == menu, "Clicking an unavailable stage must stay in the menu")
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == stages.get_child(1), "Right must focus stage 2")
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "Enter must start stage 2 without completing the tutorial")
	await _key(KEY_ESCAPE)
	menu = current_scene
	stages = menu.get_node("Margin/Content/Stages")
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-selection.png")
	await _click(stages.get_child(0))
	_check(current_scene.scene_file_path == "res://scenes/tutorial.tscn", "A mouse click must start the tutorial")
	if failed:
		return
	var tutorial := current_scene
	_check(tutorial.room_index == 0, "Stage 1 must begin in room 1")
	# Complete the final required room to verify navigation leaves optional practice available.
	tutorial.call("_set_room", 15, false)
	tutorial.player.respawn()
	for lesson in tutorial.STEPS[15]:
		tutorial.seen[lesson] = true
	tutorial.call("_on_arrival", 15)
	await _step(3)
	_check(tutorial.completed and current_scene == tutorial, "Completion must keep the tutorial open")
	_check(tutorial.get_node("HUD/Completion").visible, "Main completion remains visible")
	tutorial.call("_transition_to", 16)
	await _step(40)
	_check(tutorial.room_index == 16 and tutorial.player.controls_enabled, "Optional room 17 must still be playable")
	await _joy_button(JOY_BUTTON_B)
	_check(current_scene == tutorial, "The dash button must not return to stage selection")
	await _joy_button(JOY_BUTTON_START)
	_check(current_scene == tutorial and tutorial.room_index == 16, "Start must still retry the current room")
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Esc must return to stage selection")
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/tutorial.tscn", "Enter must start the focused stage")
	if failed:
		return
	tutorial = current_scene
	_check(tutorial.room_index == 0 and tutorial.cleared.is_empty() and not tutorial.completed, "Re-entering a stage must reset progress")
	_check(not tutorial.player.wall_actions_enabled and not tutorial.player.dash_enabled, "Re-entering must reset learned abilities")
	_check(tutorial.get_node("HUD/ReturnToStageSelect").focus_mode == Control.FOCUS_NONE, "Jump/accept must not activate the mouse return button")
	await _click(tutorial.get_node("HUD/ReturnToStageSelect"))
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "The mouse return button must open stage selection")
	await _click(current_scene.get_node("Margin/Content/Stages/Stage2"))
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "A mouse click must start stage 2")
	_check(current_scene.room_index == 0 and current_scene.player.dash_enabled and current_scene.player.wall_actions_enabled, "Stage 2 begins in room 1 with movement abilities available")
	await _click(current_scene.get_node("HUD/ReturnToStageSelect"))
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "The stage 2 mouse return button must open stage selection")
	menu = current_scene
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	_check(stick.is_action("ui_right"), "The left stick must be mapped to UI navigation")
	Input.parse_input_event(stick)
	await _step()
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	_check(root.gui_get_focus_owner() == menu.get_node("Margin/Content/Stages/Stage2"), "The left stick must focus stage 2")
	# Return to a known focus before testing the D-pad independently of stick repeat.
	menu.get_node("Margin/Content/Stages/Stage1").grab_focus()
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	_check(root.gui_get_focus_owner() == menu.get_node("Margin/Content/Stages/Stage2"), "The D-pad must focus stage 2")
	await _joy_button(JOY_BUTTON_A)
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "Gamepad accept must start stage 2")
	if failed:
		return
	current_scene.call("_transition_to", 1)
	await _joy_button(JOY_BUTTON_BACK)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Back must return even during a room transition")
	await _joy_button(JOY_BUTTON_A)
	_check(current_scene.scene_file_path == "res://scenes/tutorial.tscn", "Gamepad accept must still start stage 1")
	current_scene.call("_transition_to", 1)
	await _joy_button(JOY_BUTTON_BACK)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Back must still return during a tutorial transition")
	print("STAGE_SELECT_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	await _press(event)


func _joy_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	if button == JOY_BUTTON_A:
		_check(event.is_action("ui_accept"), "A must be mapped to UI accept")
	await _press(event)


func _click(button: Button) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	# GUI mouse positions are in viewport coordinates, including in headless runs.
	root.push_input(motion, true)
	await _step()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.pressed = true
	root.push_input(event, true)
	await _step()
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _step(3)


func _press(event: InputEvent) -> void:
	event.set("pressed", true)
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.set("pressed", false)
	Input.parse_input_event(event)
	await _step(3)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("STAGE_SELECT: " + message)
		quit(1)
