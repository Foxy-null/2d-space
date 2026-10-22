extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	await process_frame
	var settings = root.get_node("InputSettings")
	settings.save_path = "res://.godot/input_settings_test.cfg"
	check(settings.ACTIONS.has("pause_game"), "Pause menu action is configurable")
	check(not settings.ACTIONS.has("toggle_stage_hints"), "Legacy hint action is not exposed")
	check(not settings.ACTIONS.has("return_to_stage_select"), "Legacy return action is not exposed")
	# Use project defaults rather than a developer's personal saved configuration.
	for action in settings.ACTIONS:
		InputMap.action_erase_events(action)
		for event in settings.defaults[action]:
			InputMap.action_add_event(action, event)
	var legacy_config := ConfigFile.new()
	legacy_config.set_value("bindings", "move_left", settings.defaults["move_left"])
	check(legacy_config.save(settings.save_path) == OK, "Legacy configuration fixture is saved")
	var pause_defaults: Array = InputMap.action_get_events("pause_game").duplicate(true)
	settings.load_settings()
	check(InputMap.action_get_events("pause_game").size() == pause_defaults.size(), "Missing pause setting keeps its project default count")
	for event in pause_defaults:
		check(InputMap.action_has_event("pause_game", event), "Missing pause setting keeps its project default event")
	var pad_before: Array = []
	for event in InputMap.action_get_events("move_left"):
		if not event is InputEventKey:
			pad_before.append(event)
	settings.open_settings()
	check(paused and settings.panel.visible, "Settings pause gameplay")
	settings._wait("move_left", 0)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	settings._input(escape)
	check(settings.waiting_action == "" and settings.panel.visible, "Esc cancels capture without closing")
	check(settings.keyboard_events("move_left")[0].physical_keycode == KEY_A, "Cancel preserves binding")
	settings._wait("move_left", 0)
	var key := InputEventKey.new()
	key.keycode = KEY_J
	key.physical_keycode = KEY_J
	key.pressed = true
	settings._input(key)
	check(settings.keyboard_events("move_left")[0].physical_keycode == KEY_J, "Captured key replaces primary slot")
	check(settings.keyboard_events("move_left")[1].physical_keycode == KEY_LEFT, "Secondary slot remains")
	for event in pad_before:
		check(InputMap.action_has_event("move_left", event), "Keyboard change preserves controller input")
	InputMap.action_erase_events("move_left")
	settings.load_settings()
	check(settings.keyboard_events("move_left")[0].physical_keycode == KEY_J, "Saved configuration reloads")
	settings.keyboard = false
	settings._refresh()
	check(settings.body.find_children("PadBinding*", "OptionButton", true, false).size() == 15, "Controller diagram exposes all 15 button bindings")
	settings._assign_pad(settings.ACTIONS.find("dash") + 1, JOY_BUTTON_A)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	check(InputMap.action_has_event("dash", pad) and not InputMap.action_has_event("jump", pad), "Controller button moves to chosen action")
	settings.reset_current_device()
	check(InputMap.action_has_event("jump", pad), "Controller reset restores default")
	check(settings.keyboard_events("move_left")[0].physical_keycode == KEY_J, "Controller reset preserves keyboard")
	settings.keyboard = true
	for button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_WHEEL_UP]:
		settings._wait("jump", 0)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = button_index
		mouse.pressed = true
		settings._input(mouse)
		check(settings.waiting_action == "", "Mouse capture completes")
		check(settings.keyboard_events("jump")[0] is InputEventMouseButton, "Mouse replaces keyboard slot")
		check(settings.keyboard_events("jump")[0].button_index == button_index, "Correct mouse button captured")
		check(InputMap.event_is_action(mouse, "jump"), "Mouse event triggers gameplay action")
		InputMap.action_erase_events("jump")
		settings.load_settings()
		check(settings.keyboard_events("jump")[0].button_index == button_index, "Mouse binding reloads")
	settings.keyboard = false
	settings.reset_current_device()
	check(settings.keyboard_events("jump")[0] is InputEventMouseButton, "Controller reset preserves mouse")
	settings._key_cell_input(_right_click(), "jump", 0)
	check(settings.keyboard_events("jump").is_empty(), "Right-click removes mouse binding")
	var side_button := InputEventMouseButton.new()
	side_button.button_index = MOUSE_BUTTON_XBUTTON2
	settings.set_keyboard_binding("jump", 0, side_button)
	settings.keyboard = true
	settings.reset_current_device()
	check(settings.keyboard_events("jump")[0] is InputEventKey, "Keyboard reset removes mouse binding")
	check(settings.keyboard_events("move_left")[0].physical_keycode == KEY_A, "Keyboard reset restores default")
	settings.apply_keyboard_sample(true)
	check(settings.keyboard_events("dash").size() == 1 and settings.keyboard_events("dash")[0] is InputEventMouseButton, "Sample 2 replaces dash keys with mouse")
	check(InputMap.event_is_action(_right_click(), "dash"), "Sample 2 assigns right-click dash")
	for action in settings.ACTIONS:
		var expected: Array = []
		for event in settings.defaults[action]:
			if action != "dash" or not (event is InputEventKey or event is InputEventMouseButton):
				expected.append(event)
		if action == "dash":
			expected.append(settings.keyboard_events("dash")[0])
		var actual: Array = InputMap.action_get_events(action)
		check(actual.size() == expected.size(), "Sample 2 preserves other bindings: " + action)
		for event in expected:
			check(InputMap.action_has_event(action, event), "Sample 2 preserves expected binding: " + action)
	InputMap.action_erase_events("dash")
	settings.load_settings()
	check(InputMap.event_is_action(_right_click(), "dash"), "Sample 2 persists")
	settings.apply_keyboard_sample(false)
	for action in settings.ACTIONS:
		check(InputMap.action_get_events(action).size() == settings.defaults[action].size(), "Sample 1 restores defaults: " + action)
		for event in settings.defaults[action]:
			check(InputMap.action_has_event(action, event), "Sample 1 restores default binding: " + action)
	settings.close_settings()
	check(not paused and not settings.panel.visible, "Closing resumes gameplay")
	paused = true
	settings.open_settings()
	settings.close_settings()
	check(paused, "Pre-existing pause is preserved")
	paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.save_path))
	print("Input settings tests: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _right_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	return event
