extends SceneTree

const SCENES := ["tutorial", "stage_2", "stage_3", "stage_4", "stage_5", "main", "environment_preview"]
var checks := 0
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var settings = root.get_node("InputSettings")
	# Never depend on, or overwrite, a player's saved bindings.
	for action in settings.ACTIONS:
		InputMap.action_erase_events(action)
		for event in settings.defaults[action]:
			InputMap.action_add_event(action, event)
	for scene in SCENES:
		change_scene_to_file("res://scenes/%s.tscn" % scene)
		await _step(5)
		var stage := current_scene
		if stage.has_node("StageIntro"): await stage.get_node("StageIntro").tree_exited
		var player: PlayerController = stage.get_node("Player")
		var pause_menu = stage.get_node("PauseMenu")
		await _key(KEY_F10, 12)
		_check(settings.panel.visible and paused and not pause_menu.overlay.visible, scene + ": F10 pauses only settings")
		var position_before := player.position
		var velocity_before := player.velocity
		await _key(KEY_RIGHT, 10)
		_check(player.position == position_before and player.velocity == velocity_before, "Settings freeze gameplay input")
		await _key(KEY_ESCAPE)
		_check(not settings.panel.visible and not paused and not pause_menu.overlay.visible, scene + ": Esc closes settings without opening pause")
		if failed:
			_finish()
			return
		await _key(KEY_ESCAPE)
		_check(paused and pause_menu.overlay.visible, "A separate Esc opens pause normally")
		await _joy(JOY_BUTTON_DPAD_DOWN)
		var previous_focus := root.gui_get_focus_owner()
		_check(pause_menu.menu.is_ancestor_of(previous_focus) and previous_focus != pause_menu.menu.get_node("Resume"), "Pad moves the pause focus before settings")
		await _key(KEY_F10)
		_check(settings.panel.visible and paused and pause_menu.overlay.visible, "Settings preserve the existing pause menu")
		await _joy(JOY_BUTTON_BACK)
		_check(settings.panel.visible and paused and pause_menu.overlay.visible, "Back cannot operate the underlying pause menu")
		await _echo(KEY_ESCAPE, 3)
		_check(settings.panel.visible and paused and pause_menu.overlay.visible, "Held Esc cannot operate the underlying pause menu")
		await _key(KEY_ESCAPE)
		_check(not settings.panel.visible and paused and pause_menu.overlay.visible, "Closing settings restores an existing pause")
		_check(root.gui_get_focus_owner() == previous_focus, "Closing settings restores the previous pause focus")
		await _key(KEY_F10)
		await _echo(KEY_F10, 3)
		_check(settings.panel.visible and paused, "Held F10 does not toggle repeatedly")
		await _key(KEY_F10)
		_check(not settings.panel.visible and paused and root.gui_get_focus_owner() == previous_focus, "A second F10 restores the same pause focus")
		await _joy(JOY_BUTTON_BACK)
		_check(not paused and not pause_menu.overlay.visible and root.gui_get_focus_owner() == null, "Back resumes with no hidden pause focus")
		position_before = player.position
		await _key(KEY_RIGHT, 6)
		_check(player.position.x > position_before.x + 5, "Gameplay movement works after closing both menus")
		if failed:
			_finish()
			return
	await _capture_and_pad_close(settings)
	_finish()


func _capture_and_pad_close(settings: Node) -> void:
	change_scene_to_file("res://scenes/tutorial.tscn")
	await _step(5)
	await current_scene.get_node("StageIntro").tree_exited
	var pause_menu = current_scene.get_node("PauseMenu")
	await _key(KEY_F10)
	var grid: GridContainer = settings.body.find_children("*", "GridContainer", true, false)[0]
	var original: Array = InputMap.action_get_events("move_left").duplicate(true)
	await _click(grid.get_child(4))
	_check(settings.waiting_action == "move_left", "A real binding click enters capture")
	await _key(KEY_ESCAPE)
	_check(settings.waiting_action == "" and settings.panel.visible and paused and not pause_menu.overlay.visible, "Esc cancels capture without opening pause or closing settings")
	_check(InputMap.action_get_events("move_left") == original, "Cancel keeps every binding unchanged")
	await _key(KEY_ESCAPE)
	_check(not settings.panel.visible and not paused, "The next Esc closes settings normally")
	await _joy(JOY_BUTTON_BACK)
	await _key(KEY_UP)
	await _joy(JOY_BUTTON_A)
	_check(pause_menu.confirmation.visible and paused, "Pad opens the return confirmation")
	var previous_focus := root.gui_get_focus_owner()
	await _key(KEY_F10)
	await _joy(JOY_BUTTON_BACK)
	_check(settings.panel.visible and pause_menu.confirmation.visible and paused, "Back cannot cancel the hidden confirmation")
	# Reach the existing Close button using menu inputs, without calling settings methods.
	var close: Button = settings.body.get_child(settings.body.get_child_count() - 1).get_child(1)
	for step in 40:
		if root.gui_get_focus_owner() == close:
			break
		await _key(KEY_TAB)
	_check(root.gui_get_focus_owner() == close, "The existing Close button is reachable")
	await _joy(JOY_BUTTON_A)
	_check(not settings.panel.visible and paused and pause_menu.confirmation.visible, "Pad A closes settings into the original confirmation")
	_check(root.gui_get_focus_owner() == previous_focus, "The confirmation focus is restored")
	await _joy(JOY_BUTTON_BACK)
	_check(paused and pause_menu.menu.visible, "Back cancels confirmation after settings close")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_A)
	_check(not pause_menu.overlay.visible and not paused, "Pad A resumes from the original pause menu")


func _key(code: Key, hold: int = 1) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	await _press(event, hold)


func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	await _press(event)


func _press(event: InputEvent, hold: int = 1) -> void:
	event.set("pressed", true)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(hold)
	event = event.duplicate()
	event.set("pressed", false)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(3)


func _echo(code: Key, count: int) -> void:
	for repeat in count:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = true
		event.echo = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _step(2)


func _click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
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


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("INPUT_SETTINGS_PAUSE: " + message)


func _finish() -> void:
	print("INPUT_SETTINGS_PAUSE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)
