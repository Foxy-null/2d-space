extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/environment_preview.tscn")
	await _step(3)
	var preview := current_scene
	_check(preview.player.controls_enabled and preview.player.dash_enabled, "Preview uses the playable character")
	for i in 5:
		preview.set_environment(i)
		await _step(2)
		_check(preview.backdrop.environment_theme == i, "Backdrop follows the selected environment")
		_check(preview.backdrop.get_node("AmbientMotion").get_parent() == preview.backdrop, "Ambient particles stay in the background layer")
		for art in preview.find_children("*", "Polygon2D", true, false):
			if art is TerrainArt:
				_check(art.environment_theme == i, "All terrain follows the environment")
		var cap_y: float = preview.get_node("Goal/Cap/Collision").position.y
		_check(is_equal_approx(cap_y, -58.765957), "Changing scenery preserves the goal collider")
	preview.backdrop.motion_enabled = false
	var time: float = preview.backdrop.elapsed
	await _step(3)
	_check(preview.backdrop.elapsed == time, "The motion toggle actually pauses the background")
	preview.backdrop.motion_enabled = true
	await _step(3)
	_check(preview.backdrop.elapsed > time, "Animation resumes from its paused time")
	preview.backdrop.elapsed = StageBackdrop.LOOP_TIME - 0.001
	preview.backdrop._process(0.002)
	_check(absf(preview.backdrop.elapsed - 0.001) < 0.0001, "Loop time wraps without accumulating indefinitely")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_4
	preview._unhandled_input(key)
	_check(preview.environment_theme == 3, "Keyboard can select the lava environment")
	var shoulder := InputEventJoypadButton.new()
	shoulder.pressed = true
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	preview._unhandled_input(shoulder)
	_check(preview.environment_theme == 4, "Controller can switch environments")
	key.physical_keycode = KEY_M
	preview._unhandled_input(key)
	_check(not preview.backdrop.motion_enabled, "Keyboard can pause background motion")
	shoulder.button_index = JOY_BUTTON_Y
	preview._unhandled_input(shoulder)
	_check(preview.backdrop.motion_enabled, "Controller can resume background motion")
	preview.get_node("PauseMenu").open()
	preview.get_node("PauseMenu").confirm_return()
	_check(current_scene == preview and paused, "Preview waits for return confirmation")
	preview.get_node("PauseMenu").return_to_select()
	await _step(3)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Preview returns to stage selection")
	current_scene._preview_environments()
	await _step(3)
	_check(current_scene.scene_file_path == "res://scenes/environment_preview.tscn", "Menu opens the preview")
	print("ENVIRONMENT_ART_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _step(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error(message)
