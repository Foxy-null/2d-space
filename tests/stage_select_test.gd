extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/start_screen.tscn", "F5 must start at the title screen")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _step(3)
	_check(current_scene.scene_file_path == "res://scenes/start_screen.tscn", "Show the title screen on launch")
	_check(current_scene.get_node("Center/Content/Logo").texture != null, "The title logo must load")
	_check(root.gui_get_focus_owner() == current_scene.get_node("Center/Content/Start"), "START must initially have keyboard/gamepad focus")
	var logo: TextureRect = current_scene.get_node("Center/Content/Logo")
	var start_button: Button = current_scene.get_node("Center/Content/Start")
	if DisplayServer.accessibility_should_reduce_animation() == 1:
		_check(not current_scene.is_processing() and not current_scene.get_node("Backdrop").motion_enabled, "Reduced motion disables title and background animation")
	else:
		_check(logo.modulate.a < 1.0 and is_zero_approx(start_button.modulate.a), "The logo enters before START appears")
		_check(start_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The hidden START button must not capture mouse clicks")
		await _step(35)
		_check(logo.modulate.a > 0.95 and is_zero_approx(start_button.modulate.a), "The logo is readable before the button enters")
		await _step(50)
		_check(is_equal_approx(start_button.modulate.a, 1.0) and is_equal_approx(current_scene.get_node("Center/Content/Controls").modulate.a, 1.0), "START and its controls finish fading in")
		_check(start_button.mouse_filter == Control.MOUSE_FILTER_STOP, "The revealed START button accepts mouse clicks")
		_check(logo.scale.x >= 1.0 and logo.scale.x <= 1.012, "Idle motion keeps the logo within its gentle scale range")
		await _step(15)
		var ninja: AnimatedSprite2D = current_scene.get_node("Mascot/Ninja")
		_check(ninja.animation == &"idle" and ninja.position.is_zero_approx(), "The ninja lands beside START after its entrance")
	_check(logo.get_global_rect().end.y + 16.0 <= start_button.get_global_rect().position.y, "The portrait logo leaves a clear gap before START")
	_check(absf(current_scene.get_node("Mascot/Ninja").global_position.y - start_button.get_global_rect().get_center().y) < 8.0, "The ninja lands at the height of the START button")
	_check(current_scene.get_node("Center/Content/Controls").get_global_rect().end.y <= root.get_visible_rect().size.y - 16.0, "The control hint remains inside the screen")
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/start-screen.png")
	if DisplayServer.accessibility_should_reduce_animation() != 1:
		var title := current_scene
		start_button.pressed.emit()
		start_button.pressed.emit()
		_check(start_button.disabled, "Starting locks the button against repeated activation")
		await _step(3)
		_check(current_scene == title, "The launch effect plays before changing scenes")
		await _step(20)
		_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Repeated activation completes one launch into stage selection")
		await _key(KEY_ESCAPE)
	for key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		await _key(key)
		_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Keyboard accept opens stage selection")
		await _key(KEY_ESCAPE)
		_check(current_scene.scene_file_path == "res://scenes/start_screen.tscn", "Esc returns from stage selection to the title")
		_check(root.gui_get_focus_owner() == current_scene.get_node("Center/Content/Start"), "Returning to the title restores START focus")
	await _step(80)
	await _click(current_scene.get_node("Center/Content/Start"))
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Clicking START opens stage selection")
	await _click(current_scene.get_node("ReturnTitle"))
	_check(current_scene.scene_file_path == "res://scenes/start_screen.tscn", "The title return button opens the title screen")
	await _joy_button(JOY_BUTTON_A)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Gamepad accept opens stage selection from the title")
	await _joy_button(JOY_BUTTON_BACK)
	_check(current_scene.scene_file_path == "res://scenes/start_screen.tscn", "Back returns from stage selection to the title")
	await _key(KEY_ENTER)
	await _key(KEY_UP)
	_check(root.gui_get_focus_owner() == current_scene.get_node("ReturnTitle"), "The title return button is reachable with directional input")
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/start_screen.tscn", "The focused title return button works with Enter")
	await _key(KEY_ENTER)
	var menu := current_scene
	var stages: HBoxContainer = menu.get_node("Margin/Content/Stages")
	_check(stages.get_child_count() == 6, "Show six playable stages")
	_check(root.gui_get_focus_owner() == stages.get_child(0), "Stage 1 must initially have keyboard/gamepad focus")
	_check(not stages.get_child(0).disabled, "Tutorial must be playable")
	_check(not stages.get_child(1).disabled and stages.get_child(1).text.contains("星のぼりの塔"), "Stage 2 must be the tower")
	_check(stages.get_child(1).position.x > stages.get_child(0).position.x, "Stage 2 follows stage 1")
	_check(not stages.get_child(2).disabled and stages.get_child(2).text.contains("壁キックと重力"), "Stage 3 must be the gravity course")
	_check(not stages.get_child(3).disabled and stages.get_child(3).text.contains("星渡りの回廊"), "Stage 4 must be playable")
	_check(not stages.get_child(4).disabled and stages.get_child(4).text.contains("暴風バンパー峡谷"), "Stage 5 must be playable")
	_check(stages.get_child(4).position.x > stages.get_child(3).position.x, "Stage cards must be horizontal")
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == stages.get_child(1), "Right selects stage 2")
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == stages.get_child(2), "Right selects stage 3")
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == stages.get_child(3), "Right selects stage 4")
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == stages.get_child(4), "Right selects stage 5")
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == stages.get_child(5), "Right selects stage 6")
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == stages.get_child(5), "Navigation stays within the stage list")
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_6.tscn", "Enter starts stage 6")
	await _key(KEY_ESCAPE)
	await _confirm_return()
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Stage 6 returns to selection")
	for index in 4:
		await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_5.tscn", "Enter starts stage 5")
	await _key(KEY_ESCAPE)
	await _confirm_return()
	menu = current_scene
	stages = menu.get_node("Margin/Content/Stages")
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	await _key(KEY_LEFT)
	await _key(KEY_LEFT)
	_check(root.gui_get_focus_owner() == stages.get_child(0), "Left returns to stage 1")
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
	await _confirm_return()
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Esc must return to stage selection")
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/tutorial.tscn", "Enter must start the focused stage")
	if failed:
		return
	tutorial = current_scene
	_check(tutorial.room_index == 0 and tutorial.cleared.is_empty() and not tutorial.completed, "Re-entering a stage must reset progress")
	_check(not tutorial.player.wall_actions_enabled and not tutorial.player.dash_enabled, "Re-entering must reset learned abilities")
	_check(tutorial.get_node("HUD/PauseButton").focus_mode == Control.FOCUS_NONE, "Jump/accept must not activate the mouse return button")
	await _click(tutorial.get_node("HUD/PauseButton"))
	await _confirm_return()
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "The mouse return button must open stage selection")
	menu = current_scene
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	_check(stick.is_action("ui_right"), "The left stick must be mapped to UI navigation")
	Input.parse_input_event(stick)
	await _step()
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	_check(root.gui_get_focus_owner() == menu.get_node("Margin/Content/Stages/Stage3"), "Stick/D-pad navigation reaches stage 3")
	await _joy_button(JOY_BUTTON_A)
	_check(current_scene.scene_file_path == "res://scenes/stage_3.tscn", "Gamepad accept starts stage 3")
	_check(current_scene.get_node("HUD/Margin/Panel/Rows/Title").text.begins_with("ステージ3"), "Stage 3 HUD matches its card")
	current_scene.call("_transition_to", 1)
	await _joy_button(JOY_BUTTON_BACK)
	await _confirm_return()
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Back returns during a room transition")
	await _click(current_scene.get_node("Margin/Content/Stages/Stage3"))
	_check(current_scene.scene_file_path == "res://scenes/stage_3.tscn", "Mouse starts stage 3")
	await _click(current_scene.get_node("HUD/PauseButton"))
	await _confirm_return()
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Stage 3 mouse return opens selection")
	menu = current_scene
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	_check(root.gui_get_focus_owner() == menu.get_node("Margin/Content/Stages/Stage2"), "Stick/D-pad navigation must select stage 2")
	await _joy_button(JOY_BUTTON_A)
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "Gamepad accept must start stage 2")
	if failed:
		return
	await _joy_button(JOY_BUTTON_BACK)
	await _confirm_return()
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Back returns from the tower")
	await _click(current_scene.get_node("Margin/Content/Stages/Stage2"))
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "A mouse click must start stage 2")
	await _click(current_scene.get_node("HUD/PauseButton"))
	await _confirm_return()
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "The stage 2 mouse return button must open stage selection")
	await _click(current_scene.get_node("Margin/Content/Stages/Stage4"))
	_check(current_scene.scene_file_path == "res://scenes/stage_4.tscn", "Mouse starts stage 4")
	await _joy_button(JOY_BUTTON_BACK)
	await _confirm_return()
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Back returns from stage 4")
	await _click(current_scene.get_node("Margin/Content/Stages/Stage5"))
	_check(current_scene.scene_file_path == "res://scenes/stage_5.tscn", "Mouse starts stage 5")
	await _click(current_scene.get_node("HUD/PauseButton"))
	await _confirm_return()
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Mouse returns from stage 5")
	for index in 4:
		await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	_check(root.gui_get_focus_owner() == current_scene.get_node("Margin/Content/Stages/Stage5"), "Gamepad selects stage 5")
	await _joy_button(JOY_BUTTON_A)
	_check(current_scene.scene_file_path == "res://scenes/stage_5.tscn", "Gamepad starts stage 5")
	await _joy_button(JOY_BUTTON_BACK)
	await _confirm_return()
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Back returns from stage 5")
	print("STAGE_SELECT_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _confirm_return() -> void:
	var stage := current_scene
	var pause := stage.get_node("PauseMenu")
	_check(paused and pause.overlay.visible, "Leaving starts in the pause menu")
	await _click(pause.menu.get_node("Return"))
	_check(current_scene == stage and paused, "Requesting a return waits for confirmation")
	await _click(pause.confirmation.get_node("Return"))
	_check(not paused, "Stage selection is not paused")


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
	var from_title := current_scene.scene_file_path == "res://scenes/start_screen.tscn"
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
	await _step(23 if from_title else 3)


func _press(event: InputEvent) -> void:
	var from_title := current_scene.scene_file_path == "res://scenes/start_screen.tscn"
	event.set("pressed", true)
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.set("pressed", false)
	Input.parse_input_event(event)
	await _step(23 if from_title else 3)


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
