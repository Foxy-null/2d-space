extends SceneTree

var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for number in range(1, 6):
		var path := "res://scenes/tutorial.tscn" if number == 1 else "res://scenes/stage_%d.tscn" % number
		change_scene_to_file(path)
		await _step(4)
		var stage := current_scene
		var completion: Label = stage.get_node("HUD/Completion")
		_check(not completion.visible and not completion.card.visible, "No clear card before completion")
		await _key(KEY_ENTER)
		await _joy(JOY_BUTTON_Y)
		_check(current_scene == stage, "Return shortcuts before completion do not leave the stage")
		# Isolate completion UI from traversal; stage traversal has separate real-input tests.
		stage.set_physics_process(false)
		stage.player.set_physics_process(false)
		if number == 1:
			stage._set_room(15, false)
			for key in stage.STEPS[15]:
				stage.seen[key] = true
			stage._on_arrival(15)
		elif number == 4:
			stage.room_index = 5
			stage.player.position = Vector2(6510, 594)
			_check(stage.player.try_begin_grab(stage.rooms.get_child(5).get_node("Items/JumpCreature")), "Stage 4 completion fixture carries the final companion")
			stage._on_completed()
		elif number == 2:
			stage._on_completed()
		elif number == 5:
			stage.room_index = 11
			stage.next_bumper = stage._bumpers().get_child_count()
			stage._on_completed()
		else:
			stage.room_index = stage.rooms.get_child_count() - 1
			stage._on_arrival(stage.room_index)
		_check(stage.completed and completion.visible and completion.card.visible, "Every stage shows the clear card")
		_check(completion.card.get_child(0).get_child(0).text == "ステージクリア！", "Consistent Japanese clear title")
		_check(completion.return_button.text.contains("Enter") and completion.return_button.text.contains("Y・△"), "Keyboard and gamepad return instructions are visible")
		var notice: Rect2 = completion.card.get_global_rect()
		_check(not notice.has_point(root.get_visible_rect().get_center()) and notice.size.x <= 320 and notice.size.y <= 120, "The small notice leaves the center of practice visible")
		_check(root.get_visible_rect().encloses(notice) and completion.return_button.size.y >= 40, "The notice stays on screen with a usable button")
		# Jump/accept inputs must never activate the return button.
		await _key(KEY_SPACE)
		_check(current_scene == stage, "Space after completion remains a jump")
		await _joy(JOY_BUTTON_A)
		_check(current_scene == stage, "A/× after completion remains a jump")
		var pause := stage.get_node("PauseMenu")
		pause.open()
		await _joy(JOY_BUTTON_Y)
		await _click(completion.return_button)
		_check(current_scene == stage and paused, "Y and the notice's button cannot bypass pause")
		await _key(KEY_ENTER)
		_check(current_scene == stage and not paused, "Enter resumes the paused game without leaving")
		if OS.get_cmdline_user_args().has("--screenshots"):
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://.godot/clear_stage_%d.png" % number)
		await _key(KEY_KP_ENTER if number == 3 else KEY_ENTER)
		_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Enter returns to stage selection")
		# Also exercise the actual Button's click route on each stage.
		change_scene_to_file(path)
		await _step(3)
		current_scene.set_physics_process(false)
		completion = current_scene.get_node("HUD/Completion")
		completion.show()
		await _step(2)
		await _click(completion.return_button)
		_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Return button works in stage %d" % number)
		change_scene_to_file(path)
		await _step(3)
		current_scene.set_physics_process(false)
		current_scene.get_node("HUD/Completion").show()
		await _step(2)
		await _joy(JOY_BUTTON_Y)
		_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Y/△ returns to selection in stage %d" % number)
	current_scene.queue_free()
	await _step(3)
	print("STAGE_CLEAR_TEST_OK (%d checks)" % checks)
	quit()


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
	await _step(2)


func _click(button: Button) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button.get_global_rect().get_center()
	click.global_position = click.position
	var motion := InputEventMouseMotion.new()
	motion.position = click.position
	motion.global_position = click.position
	root.push_input(motion, true)
	await _step()
	click.pressed = true
	root.push_input(click, true)
	await _step()
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await _step(3)


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("STAGE_CLEAR: " + message)
		quit(1)
