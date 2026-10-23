extends SceneTree

var failed := false
var checks := 0
var settings: Node
var original_bindings := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	settings = root.get_node("InputSettings")
	settings.save_path = "res://.godot/input_settings_navigation_test.cfg"
	for action in settings.ACTIONS:
		original_bindings[action] = InputMap.action_get_events(action)
	await _select()
	var launcher: Button = settings.launcher
	var bounds := launcher.get_global_rect()
	_check(root.get_visible_rect().encloses(bounds) and launcher.size.x >= launcher.get_minimum_size().x, "Settings entry and its full label fit the viewport")
	var existing: Array = current_scene.get_node("Margin/Content/Stages").get_children()
	existing.append(current_scene.get_node("ReturnTitle"))
	existing.append(current_scene.get_node("Margin/Content/Preview"))
	for button in existing:
		_check(not bounds.intersects(button.get_global_rect()), "Settings does not cover " + button.name)
	await _capture("selection-layout")
	await _pad(JOY_BUTTON_DPAD_UP)
	_check(_focus() == current_scene.get_node("ReturnTitle"), "Existing card-up path still reaches title return")
	await _pad(JOY_BUTTON_DPAD_LEFT)
	_check(_focus() == launcher, "D-pad reaches settings from title return")
	await _capture("pad-entry")
	if _focus() == launcher:
		await _pad(JOY_BUTTON_A)
		_check(settings.panel.visible and paused, "UI accept opens the focused settings entry")
		await _close_with_pad()
		_check(not settings.panel.visible and not paused and _focus() == launcher, "Pad close restores its entry focus and pause state")
		await _pad(JOY_BUTTON_DPAD_RIGHT)
		_check(_focus() == current_scene.get_node("ReturnTitle"), "Pad returns from settings to title return")
		await _pad(JOY_BUTTON_DPAD_DOWN)
		await _pad(JOY_BUTTON_DPAD_RIGHT)
		await _pad(JOY_BUTTON_A)
		_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "Pad can start an existing stage after closing settings")
	await _select()
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	var selected := _focus()
	await _key(KEY_F10)
	_check(settings.panel.visible and paused, "Reserved keyboard shortcut opens settings")
	await _key(KEY_F10)
	_check(not settings.panel.visible and not paused and _focus() == selected, "Keyboard close restores the exact previously selected stage")
	await _capture("keyboard-restored")
	await _select()
	await _key(KEY_UP)
	await _key(KEY_TAB)
	_check(_focus() == launcher, "Tab reaches settings from title return")
	await _key(KEY_TAB, true)
	_check(_focus() == current_scene.get_node("ReturnTitle"), "Shift+Tab returns from settings to title return")
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	_check(_focus() == current_scene.get_node("Margin/Content/Stages/Stage1"), "Tab leaves settings for the existing stage list")
	await _key(KEY_TAB, true)
	_check(_focus() == launcher, "Shift+Tab reaches settings from the first stage")
	if _focus() == launcher:
		await _key(KEY_ENTER)
		_check(settings.panel.visible and paused, "Enter opens the keyboard-focused settings entry")
		await _key(KEY_F10)
		_check(_focus() == launcher and not paused, "Keyboard button activation restores entry focus")
	await _select()
	await _click(launcher.get_global_rect().get_center())
	_check(settings.panel.visible and paused, "Mouse opens settings")
	for button in settings.body.find_children("*", "Button", true, false):
		if button.text == "閉じる":
			await _click(button.get_global_rect().get_center())
			break
	_check(not settings.panel.visible and not paused and _focus() == launcher, "Mouse close restores entry focus and pause state")
	await _click(launcher.get_global_rect().get_center())
	await _close_with_pad()
	_check(not settings.panel.visible and not paused and _focus() == launcher, "Mouse entry also restores launcher focus on close")
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_check(_focus() == current_scene.get_node("ReturnTitle"), "Closing settings does not strand focus in its Autoload")
	await _capture("pad-return")
	await _click(current_scene.get_node("ReturnTitle").get_global_rect().get_center())
	_check(current_scene.scene_file_path == "res://scenes/start_screen.tscn", "Mouse can still activate title return")
	await _select()
	await _stick(JOY_AXIS_LEFT_Y, -1.0)
	await _stick(JOY_AXIS_LEFT_X, -1.0)
	_check(_focus() == launcher, "The left stick reaches settings through the same UI actions")
	await _stick(JOY_AXIS_LEFT_X, 1.0)
	await _stick(JOY_AXIS_LEFT_Y, 1.0)
	_check(_focus() == current_scene.get_node("Margin/Content/Stages/Stage1"), "The left stick returns to the existing stage list")
	await _check_pad_graph()
	for action in settings.ACTIONS:
		_check(InputMap.action_get_events(action) == original_bindings[action], "Navigation preserves bindings: " + action)
	_check(not FileAccess.file_exists(settings.save_path), "Navigation does not write settings")
	print("INPUT_SETTINGS_NAVIGATION_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _check_pad_graph() -> void:
	var queue: Array = [[]]
	var reached := {}
	var edges := {}
	while not queue.is_empty() and reached.size() < 20:
		var path: Array = queue.pop_front()
		await _select()
		for button in path:
			await _pad(button)
		var source := str(_focus().get_path())
		if reached.has(source):
			continue
		reached[source] = path
		edges[source] = {}
		for button in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			await _select()
			for move in path:
				await _pad(move)
			await _pad(button)
			var target := str(_focus().get_path())
			edges[source][str(button)] = target
			if not reached.has(target):
				queue.append(path + [button])
	_check(reached.has(str(settings.launcher.get_path())) and reached.size() == 8, "The complete D-pad graph includes settings and all seven existing entries")
	print("INPUT_SETTINGS_PAD_GRAPH ", JSON.stringify(edges))


func _close_with_pad() -> void:
	for move in 20:
		var owner := _focus()
		if owner is Button and owner.text == "閉じる":
			await _pad(JOY_BUTTON_A)
			return
		if owner is Button and owner.text == "このタブを初期設定に戻す":
			await _pad(JOY_BUTTON_DPAD_RIGHT)
		else:
			await _pad(JOY_BUTTON_DPAD_DOWN)
	_check(false, "Pad reaches the settings close button")


func _select() -> void:
	if settings.panel.visible:
		await _key(KEY_F10)
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(4)
	current_scene.get_node("Starfield").motion_enabled = false
	current_scene.get_node("Starfield").elapsed = 0.0


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _key(code: Key, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = shift
	await _press(event)


func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	await _press(event)


func _press(event: InputEvent) -> void:
	event.set("pressed", true)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(2)
	event = event.duplicate()
	event.set("pressed", false)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(2)


func _stick(axis: JoyAxis, amount: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = amount
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(2)
	event = event.duplicate()
	event.axis_value = 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(2)


func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	await _step(1)
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await _step(2)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _step(2)


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):
		return
	DirAccess.make_dir_recursive_absolute("/tmp/input-settings-navigation")
	RenderingServer.force_draw()
	_check(root.get_texture().get_image().save_png("/tmp/input-settings-navigation/%s.png" % name) == OK, "Native screenshot saved")


func _step(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("INPUT_SETTINGS_NAVIGATION: " + message)
