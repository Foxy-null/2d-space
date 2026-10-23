extends SceneTree

const SCENES := ["tutorial", "stage_2", "stage_3", "stage_4", "stage_5", "main", "environment_preview"]
var failed := false
var checks := 0
var display: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	display = root.get_node("DisplaySettings")
	var args := OS.get_cmdline_user_args()
	if args.has("--restart-save") or args.has("--restart-load"):
		await _step(4)
		if args.has("--restart-save"):
			root.size = Vector2i(1000, 600)
			display.toggle_fullscreen()
			_check(display.is_fullscreen(), "The first process saves fullscreen")
		else:
			_check(display.is_fullscreen() and display.windowed_size == Vector2i(1000, 600), "A fresh process restores fullscreen and the preceding dimensions")
			display.toggle_fullscreen()
			_check(root.size == Vector2i(1000, 600), "A fresh process can restore the preceding window")
		_finish()
		return
	display.save_path = "user://display_settings_test.cfg"
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(4)
	var button: Button = current_scene.get_node("Fullscreen")
	_check(button.disabled == not display.available, "Fullscreen availability follows the execution environment")
	if not display.available:
		display.toggle_fullscreen()
		_check(display.save_settings() == OK and not FileAccess.file_exists(display.save_path), "Unsupported execution never saves display preferences")
		_finish()
		return
	var launcher: Button = root.get_node("InputSettings").launcher
	_check(not button.get_global_rect().intersects(launcher.get_global_rect()), "Fullscreen does not cover input settings")
	_check(not button.get_global_rect().intersects(current_scene.get_node("ReturnTitle").get_global_rect()), "Fullscreen does not cover title return")
	_check(button.size.x >= button.get_minimum_size().x, "The fullscreen label fits its button")
	launcher.grab_focus()
	await _key(KEY_LEFT)
	_check(root.gui_get_focus_owner() == button, "Directional input reaches fullscreen from input settings")
	for size in [Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(1600, 1200)]:
		root.size = size
		await _step(24)
		_check(root.get_visible_rect().size == Vector2(1280, 720), "Resizing preserves the visible world")
		var scale := minf(size.x / 1280.0, size.y / 720.0)
		_check(root.get_final_transform().get_scale().is_equal_approx(Vector2.ONE * scale), "Resizing scales both axes uniformly")
		var saved := ConfigFile.new()
		_check(saved.load(display.save_path) == OK and saved.get_value("display", "windowed_size") == size, "Resizing automatically saves the window dimensions")
	root.size = Vector2i(960, 540)
	await _step(4)
	await _key(KEY_F11)
	_check(display.is_fullscreen() and button.text == "ウィンドウ表示 [F11]", "F11 enters fullscreen and updates the menu")
	_check(button.size.x >= button.get_minimum_size().x, "The return-to-window label fits its button")
	var echo := InputEventKey.new()
	echo.keycode = KEY_F11
	echo.pressed = true
	echo.echo = true
	Input.parse_input_event(echo)
	await _step(3)
	_check(display.is_fullscreen(), "Holding F11 cannot repeatedly toggle fullscreen")
	var saved := ConfigFile.new()
	saved.load(display.save_path)
	_check(saved.get_value("display", "fullscreen") == true and saved.get_value("display", "windowed_size") == Vector2i(960, 540), "Fullscreen preserves the preceding window size")
	button.grab_focus()
	await _pad(JOY_BUTTON_A)
	_check(not display.is_fullscreen() and root.size == Vector2i(960, 540), "The menu button restores the preceding window size")
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Accepting fullscreen does not start a stage")
	_check(saved.save(display.save_path) == OK, "Saved fullscreen fixture is available")
	display.load_settings()
	await _step(5)
	_check(display.is_fullscreen(), "Loading saved preferences restores fullscreen")
	await _key(KEY_F11)
	for scene in SCENES:
		change_scene_to_file("res://scenes/%s.tscn" % scene)
		await _step(4)
		var pause = current_scene.get_node("PauseMenu")
		pause.open()
		button = pause.menu.get_node("Fullscreen")
		var player: PlayerController = current_scene.get_node("Player")
		var before := player.position
		button.grab_focus()
		await _pad(JOY_BUTTON_A)
		_check(display.is_fullscreen() and paused and pause.overlay.visible, scene + ": fullscreen works while paused")
		_check(player.position == before and root.gui_get_focus_owner() == button, "Changing display preserves paused gameplay and menu focus")
		_check(root.get_visible_rect().encloses(pause.get_node("Overlay/Center/Panel").get_global_rect()), "The expanded pause menu fits the screen")
		await _key(KEY_F11)
		_check(not display.is_fullscreen() and paused, "F11 also exits fullscreen while paused")
		pause.resume()
	var usable := DisplayServer.screen_get_usable_rect(root.current_screen)
	saved.set_value("display", "windowed_size", Vector2i(99999, 99999))
	saved.set_value("display", "fullscreen", "invalid")
	saved.save(display.save_path)
	display.load_settings()
	await _step(4)
	_check(root.size.x <= usable.size.x and root.size.y <= usable.size.y and not display.is_fullscreen(), "Saved preferences fit the current monitor and reject invalid fullscreen values")
	for invalid in ["invalid", Vector2i(-10, 0)]:
		saved.set_value("display", "windowed_size", invalid)
		saved.save(display.save_path)
		var before: Vector2i = display.windowed_size
		display.load_settings()
		_check(display.windowed_size == before, "Invalid saved dimensions retain the last valid size")
	var before := FileAccess.get_file_as_string(display.save_path)
	var mode_before := root.mode
	display.available = false
	display.toggle_fullscreen()
	display.load_settings()
	display.save_settings()
	_check(root.mode == mode_before and FileAccess.get_file_as_string(display.save_path) == before, "Unavailable display control does not change the window or overwrite preferences")
	display.save_timer.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(display.save_path))
	_check_restart()
	_finish()


func _check_restart() -> void:
	if OS.get_name() != "Linux":
		return
	# Give child processes isolated preferences without touching the player's files.
	var had_data_dir := OS.has_environment("XDG_DATA_HOME")
	var previous_data_dir := OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("XDG_DATA_HOME", ProjectSettings.globalize_path("res://.godot/display_restart_%d" % Time.get_ticks_usec()))
	var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--audio-driver", "Dummy", "--disable-render-loop", "--disable-vsync", "--max-fps", "60", "--script", "res://tests/display_settings_test.gd", "--"])
	for phase in ["--restart-save", "--restart-load"]:
		var output: Array = []
		var result := OS.execute(OS.get_executable_path(), args + PackedStringArray([phase]), output, true)
		_check(result == 0, "Restart check " + phase + ": " + "".join(output))
	if had_data_dir:
		OS.set_environment("XDG_DATA_HOME", previous_data_dir)
	else:
		OS.unset_environment("XDG_DATA_HOME")


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	await _press(event)


func _pad(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	await _press(event)


func _press(event: InputEvent) -> void:
	event.set("pressed", true)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(3)
	event = event.duplicate()
	event.set("pressed", false)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(3)


func _step(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("DISPLAY: " + message)


func _finish() -> void:
	print("DISPLAY_SETTINGS_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)
