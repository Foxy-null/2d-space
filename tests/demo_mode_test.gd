extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var demo = root.get_node("DemoMode")
	_check(not demo.enabled, "Demo mode defaults to OFF")
	_check(is_equal_approx(demo.idle_timeout, 30.0), "Idle timeout is 30 seconds")
	_check(is_equal_approx(demo.warning_duration, 20.0), "Warning countdown is 20 seconds")

	# 1. Title screen toggle button check
	change_scene_to_file("res://scenes/start_screen.tscn")
	await _step(60)
	var title := current_scene
	var title_demo_btn: Button = title.get_node("DemoMode")
	_check(title_demo_btn.text == "体験モード: OFF", "Title button shows OFF initially")
	_check(root.get_visible_rect().encloses(title_demo_btn.get_global_rect()), "Title demo button fits viewport")
	_check(not title_demo_btn.get_global_rect().intersects(title.get_node("Center/Content/Start").get_global_rect()), "Title demo button does not overlap Start")
	await _click(title_demo_btn)
	_check(demo.enabled and title_demo_btn.text == "体験モード: ON", "Clicking title button enables demo mode")

	# Use accelerated timers for fast frame-accurate simulation while also verifying default values
	demo.idle_timeout = 1.0
	demo.warning_duration = 0.5

	# Idle on the title screen itself should not trigger the warning
	await _step(90)
	_check(not demo.warning_active and current_scene.scene_file_path == "res://scenes/start_screen.tscn", "Title screen does not warn while idle")

	# 2. Stage select toggle button check
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(6)
	var select := current_scene
	_check(demo.get_signal_connection_list("mode_changed").size() == 1, "Scene changes disconnect freed demo buttons")
	var select_demo_btn: Button = select.get_node("DemoMode")
	_check(select_demo_btn.text == "体験モード: ON", "Stage select button reflects current ON state")
	_check(root.get_visible_rect().encloses(select_demo_btn.get_global_rect()), "Stage select demo button fits viewport")
	_check(select_demo_btn.size.x >= select_demo_btn.get_minimum_size().x, "Stage select demo button fits its label")
	for node in [
		select.get_node("ReturnTitle"),
		select.get_node("Fullscreen"),
		root.get_node("InputSettings").launcher,
		select.get_node("Margin/Content/Stages/Stage5"),
	]:
		_check(not select_demo_btn.get_global_rect().intersects(node.get_global_rect()), "Demo button does not overlap " + node.name)

	await _click(select_demo_btn)
	_check(not demo.enabled and select_demo_btn.text == "体験モード: OFF", "Stage select button can turn demo mode OFF")

	# 3. While OFF, idling in a stage never warns or returns to title
	change_scene_to_file("res://scenes/tutorial.tscn")
	await _step(90)
	_check(not demo.warning_active and current_scene.scene_file_path == "res://scenes/tutorial.tscn", "Inactive demo mode never interrupts gameplay")

	# Turn ON from stage select and enter Stage 1
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(6)
	await _click(current_scene.get_node("DemoMode"))
	_check(demo.enabled, "Re-enabled demo mode from stage select")
	change_scene_to_file("res://scenes/tutorial.tscn")
	await _step(6)

	# 4. Input before timeout resets idle timer
	await _step(40)
	_check(not demo.warning_active and demo.idle_elapsed > 0.3, "Idle timer accumulates when no input occurs")
	await _key(KEY_RIGHT)
	_check(demo.idle_elapsed < 0.1 and not demo.warning_active, "Gameplay input resets idle timer")

	# 5. Reaching idle timeout shows 20-second warning, and key or slight mouse movement dismisses it
	await _until(func(): return demo.warning_active, 90, "Idle timeout triggers warning overlay")
	_check(demo.overlay.visible and paused, "Warning overlay is visible and pauses the stage")
	_check(demo.title_label.text == "まだ操作していますか？", "Warning asks if player is still operating")
	await _key(KEY_SPACE)
	_check(not demo.warning_active and not demo.overlay.visible and not paused, "Pressing a key during warning dismisses it and resumes gameplay")
	_check(current_scene.scene_file_path == "res://scenes/tutorial.tscn", "Player remains in the stage after responding to warning")

	await _until(func(): return demo.warning_active, 90, "Warning appears before Escape response")
	await _key(KEY_ESCAPE)
	_check(not demo.warning_active and not paused and not current_scene.get_node("PauseMenu").overlay.visible, "Escape dismisses the warning without opening the pause menu")

	await _until(func(): return demo.warning_active, 90, "Idle timeout triggers warning overlay again")
	var slight_motion := InputEventMouseMotion.new()
	slight_motion.relative = Vector2(1, 0)
	Input.parse_input_event(slight_motion)
	await _step(2)
	_check(not demo.warning_active and not demo.overlay.visible and not paused, "Even a 1px mouse movement during warning immediately dismisses it")

	# 6. Ignoring the warning for the full duration forces return to title screen (even while paused/in settings)
	current_scene.get_node("PauseMenu").open()
	root.get_node("InputSettings").open_settings()
	_check(paused and root.get_node("InputSettings").panel.visible, "Pause and input settings are open before timeout")
	await _until(func(): return demo.warning_active, 90, "Warning still triggers while paused in settings")
	await _key(KEY_ESCAPE)
	_check(not demo.warning_active and paused and root.get_node("InputSettings").panel.visible, "Escape dismisses only the warning and preserves paused settings")
	await _until(func(): return demo.warning_active, 90, "Warning returns after dismissing it over settings")
	await _until(func(): return current_scene != null and current_scene.scene_file_path == "res://scenes/start_screen.tscn", 60, "Ignoring warning forces return to title screen")
	_check(not demo.warning_active and not demo.overlay.visible, "Warning overlay closes upon returning to title")
	_check(not paused and is_equal_approx(Engine.time_scale, 1.0), "Forced title return unpauses tree and restores time scale")
	_check(not root.get_node("InputSettings").panel.visible, "Forced title return closes open settings panel")
	_check(demo.enabled, "Demo mode remains ON after forced return to title")

	# Restore defaults
	demo.idle_timeout = demo.DEFAULT_IDLE_TIMEOUT
	demo.warning_duration = demo.DEFAULT_WARNING_DURATION
	demo.set_enabled(false)

	print("DEMO_MODE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


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
	await _step(2)


func _click(button: Button) -> void:
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	await _step()
	var event := InputEventMouseButton.new()
	event.position = center
	event.global_position = center
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await _step()
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _step(3)


func _until(predicate: Callable, frames: int, message: String) -> void:
	for i in frames:
		if predicate.call():
			_check(true, message)
			return
		await _step()
	_check(false, message)


func _step(count := 1) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("DEMO_MODE: " + message)
