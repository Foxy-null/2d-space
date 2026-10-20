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
	# Use project defaults rather than a developer's personal saved configuration.
	for action in settings.ACTIONS:
		InputMap.action_erase_events(action)
		for event in settings.defaults[action]:
			InputMap.action_add_event(action, event)
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
	settings._assign_pad(settings.ACTIONS.find("dash") + 1, JOY_BUTTON_A)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	check(InputMap.action_has_event("dash", pad) and not InputMap.action_has_event("jump", pad), "Controller button moves to chosen action")
	settings.reset_current_device()
	check(InputMap.action_has_event("jump", pad), "Controller reset restores default")
	check(settings.keyboard_events("move_left")[0].physical_keycode == KEY_J, "Controller reset preserves keyboard")
	settings.keyboard = true
	settings.reset_current_device()
	check(settings.keyboard_events("move_left")[0].physical_keycode == KEY_A, "Keyboard reset restores default")
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
