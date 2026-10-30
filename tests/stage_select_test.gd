extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/start_screen.tscn")
	await _step(4)
	var title := current_scene
	_check(title.get_node("Center/Content/Start").text == "はじめから", "Title offers New Game")
	_check(title.get_node("Center/Content/Continue").disabled, "A clean profile cannot Continue")
	_check(root.gui_get_focus_owner() == title.get_node("Center/Content/Start"), "Initial keyboard focus is New Game")
	await _key(KEY_ENTER)
	await _step(25)
	_check(current_scene.scene_file_path == "res://scenes/tutorial.tscn", "First New Game enters Stage 1 directly")
	await _return_from_stage()
	for index in 6:
		var menu := current_scene
		var cards := menu.get_node("Margin/Content/Stages")
		_check(cards.get_child_count() == 6, "All six stages remain selectable")
		for card in cards.get_children():
			_check(not card.disabled and root.get_visible_rect().encloses(card.get_global_rect()), "Every unlocked stage card fits the screen")
			for child in card.get_node("Content").get_children():
				_check(card.get_global_rect().encloses(child.get_global_rect()), "Card contains " + child.name)
		for move in index:
			await _key(KEY_RIGHT)
		_check(root.gui_get_focus_owner() == cards.get_child(index), "Keyboard reaches stage %d" % (index + 1))
		await _key(KEY_ENTER)
		await _step(4)
		var expected := "res://scenes/tutorial.tscn" if index == 0 else "res://scenes/stage_%d.tscn" % (index + 1)
		_check(current_scene.scene_file_path == expected, "Keyboard starts stage %d" % (index + 1))
		await _return_from_stage()
	current_scene._return_to_title()
	await _step(100)
	title = current_scene
	_check(not title.get_node("Center/Content/Continue").disabled, "A started run enables Continue even before a clear")
	_check(root.gui_get_focus_owner() == title.get_node("Center/Content/Continue"), "Returning title focuses Continue")
	await _key(KEY_ENTER)
	await _step(25)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Continue opens stage selection")
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_check(root.gui_get_focus_owner() == current_scene.get_node("Margin/Content/Stages/Stage2"), "Gamepad reaches Stage 2")
	await _joy(JOY_BUTTON_A)
	await _step(4)
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "Gamepad accept starts the selected stage")
	await _return_from_stage()
	await _click(current_scene.get_node("Margin/Content/Stages/Stage1"))
	_check(current_scene.scene_file_path == "res://scenes/tutorial.tscn" and current_scene.room_index == 0, "Mouse entry starts the new tutorial at its first room")
	_check(current_scene.player.wall_actions_enabled and not current_scene.player.dash_enabled, "Reentry retains the intended starting abilities")
	await _return_from_stage()
	print("STAGE_SELECT_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _return_from_stage() -> void:
	await _key(KEY_ESCAPE)
	var pause := current_scene.get_node("PauseMenu")
	_check(paused and pause.overlay.visible, "Esc opens the common pause menu")
	await _click(pause.menu.get_node("Return"))
	_check(pause.confirmation.visible, "Leaving asks for confirmation")
	await _click(pause.confirmation.get_node("Return"))
	_check(not paused and current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Return reaches unpaused selection")


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	await _press(event)


func _joy(button: JoyButton) -> void:
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
	root.push_input(motion, true)
	await _step()
	var event := InputEventMouseButton.new()
	event.position = motion.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await _step()
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _step(4)


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("STAGE_SELECT: " + message)
