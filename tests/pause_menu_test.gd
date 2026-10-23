extends SceneTree

const SCENES := ["tutorial", "stage_2", "stage_3", "stage_4", "stage_5", "main", "environment_preview"]
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for scene in SCENES:
		change_scene_to_file("res://scenes/%s.tscn" % scene)
		await _step(4)
		var stage := current_scene
		var player: PlayerController = stage.get_node("Player")
		var pause := stage.get_node("PauseMenu")
		_check(not paused and not pause.overlay.visible, scene + ": starts unpaused")
		await _key(KEY_H)
		await _joy(JOY_BUTTON_Y)
		_check(not paused and not pause.overlay.visible, "H and Y do not open a menu")
		await _key(KEY_ESCAPE)
		_check(paused and pause.overlay.visible, scene + ": Esc pauses")
		_check(root.gui_get_focus_owner() == pause.menu.get_node("Resume"), "Resume initially owns focus")
		var hint_button: Button = pause.menu.get_node("Hints")
		_check(hint_button.visible == (scene in ["tutorial", "stage_2", "stage_3", "stage_4", "stage_5"]), "Hide the whole hint button when no toggle is provided")
		var before := player.position
		var velocity := player.velocity
		Input.action_press("move_right")
		Input.action_press("reset")
		await _step(20)
		Input.action_release("move_right")
		Input.action_release("reset")
		_check(player.position == before and player.velocity == velocity, "Movement and reset inputs cannot change a paused game")
		var echo := InputEventKey.new()
		echo.physical_keycode = KEY_ESCAPE
		echo.pressed = true
		echo.echo = true
		Input.parse_input_event(echo)
		await _step()
		_check(paused, "Holding Esc does not toggle the menu repeatedly")
		if hint_button.visible:
			await _click(hint_button)
			_check(paused and stage.hints_visible and hint_button.text == "ヒントを隠す", "Hints toggle while staying paused")
			await _click(hint_button)
			_check(paused and not stage.hints_visible and hint_button.text == "ヒントを表示", "Hints can be hidden again")
		player.set_gravity_direction(-1)
		await _step(2)
		var panel: Control = pause.get_node("Overlay/Center/Panel")
		_check(panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 1, "The menu stays centered under inverted gravity")
		if scene == "stage_3" and OS.get_cmdline_user_args().has("--screenshots"):
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/pause-menu.png")
		await _key(KEY_UP)
		_check(pause.overlay.is_ancestor_of(root.gui_get_focus_owner()), "Focus stays inside the modal")
		await _click(pause.menu.get_node("Return"))
		_check(current_scene == stage and paused and pause.confirmation.visible, "Returning waits for confirmation")
		_check(pause.confirmation.get_node("Message").text.replace("\n", "") == "現在の進み具合は保存されません。戻ってもよろしいですか？", "Confirmation uses the requested wording")
		_check(root.gui_get_focus_owner() == pause.confirmation.get_node("Cancel"), "Cancel is initially selected")
		if scene == "stage_3" and OS.get_cmdline_user_args().has("--screenshots"):
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/pause-return-confirmation.png")
		await _key(KEY_ENTER)
		_check(current_scene == stage and paused and pause.menu.visible, "Enter initially cancels, preserving the game")
		await _click(pause.menu.get_node("Return"))
		await _joy(JOY_BUTTON_BACK)
		_check(current_scene == stage and paused and pause.menu.visible, "Back cancels only the confirmation")
		await _joy(JOY_BUTTON_BACK)
		_check(not paused and not pause.overlay.visible, "Back resumes from the menu")
		await _click(stage.get_node("UI/Toolbar/PauseButton" if scene == "environment_preview" else "HUD/PauseButton"))
		_check(paused, "The mouse entry opens pause")
		# Retrying must also work with an established checkpoint, not only the spawn.
		if scene == "tutorial" or scene == "stage_3":
			stage._set_room(1, false)
		elif scene == "stage_2":
			stage._set_checkpoint(2)
		elif scene in ["stage_4", "stage_5"]:
			stage.room_index = 2
			stage._set_checkpoint()
		var checkpoint: Vector2 = player._spawn_position
		player.position += Vector2(160, -80)
		if hint_button.visible:
			await _click(hint_button)
		await _click(pause.menu.get_node("Retry"))
		_check(not paused and not pause.overlay.visible, "Retry resumes without a confirmation")
		_check(player.global_position.distance_to(checkpoint) < 35 and player.gravity_direction == 1, "Retry uses the current checkpoint and restores gravity")
		if hint_button.visible:
			_check(stage.hints_visible, "Retry preserves the hint preference")
		await _key(KEY_ESCAPE)
		await _click(pause.menu.get_node("Return"))
		await _click(pause.confirmation.get_node("Return"))
		_check(not paused and current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Confirming returns to an unpaused selection screen")
	await _check_world_pause()
	await _check_transitions()
	await _check_completion_input()
	print("PAUSE_MENU_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _check_world_pause() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _step(4)
	var stage := current_scene
	var pause := stage.get_node("PauseMenu")
	var crystal := stage.get_node("RefillCrystal")
	var gate: Node2D = stage.get_node("MovingGate")
	var box: RigidBody2D = stage.get_node("LightBox")
	var background := stage.get_node("Background/Starfield")
	stage.get_node("Player").global_position = crystal.global_position
	stage.get_node("Player").velocity = Vector2.ZERO
	await _step(5)
	box.linear_velocity = Vector2(90, -150)
	await _step()
	pause.open()
	var remaining: float = crystal._respawn_left
	var position_before := box.position
	var gate_before := gate.position
	var time_before: float = background.elapsed
	await _step(180)
	_check(crystal._respawn_left == remaining and not crystal.visible, "Crystal recovery time stays frozen")
	_check(box.position == position_before, "Rigid bodies stay frozen")
	_check(gate.position == gate_before, "Moving gates stay frozen")
	_check(background.elapsed == time_before, "Background animation stays frozen")
	await _key(KEY_ESCAPE)
	await _step(5)
	_check(crystal._respawn_left < remaining and gate.position != gate_before and box.position != position_before and background.elapsed > time_before, "All world simulation resumes")
	# Accepting Resume with A/Space must not become a gameplay jump.
	for joypad in [false, true]:
		stage.get_node("Player").respawn()
		await _step(30)
		pause.open()
		if joypad:
			await _joy(JOY_BUTTON_A)
		else:
			await _key(KEY_SPACE)
		_check(not paused and stage.get_node("Player").velocity.y >= 0, "Accepting Resume does not leak a jump")


func _check_transitions() -> void:
	for scene in ["tutorial", "stage_3", "stage_4", "stage_5"]:
		change_scene_to_file("res://scenes/%s.tscn" % scene)
		await _step(3)
		var stage := current_scene
		if scene in ["stage_4", "stage_5"]:
			stage._transition_to_next()
		else:
			stage._transition_to(1)
		var pause := stage.get_node("PauseMenu")
		pause.open()
		var camera_before: Vector2 = stage.camera.position
		await _step(30)
		_check(stage.transitioning and stage.camera.position == camera_before, "Pausing freezes a room transition")
		await _click(pause.menu.get_node("Retry"))
		await _step(30)
		_check(not paused and not stage.transitioning and stage.player.controls_enabled, "Retry during transition finishes at the new room")
		_check(stage.camera.position == Vector2(1920, 360), "The resumed camera reaches the checkpoint's room")


func _check_completion_input() -> void:
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(3)
	var stage := current_scene
	var pause := stage.get_node("PauseMenu")
	stage.get_node("HUD/Completion").show()
	await _key(KEY_ESCAPE)
	await _joy(JOY_BUTTON_Y)
	_check(current_scene == stage and paused, "Completion does not intercept Y while paused")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(current_scene == stage and paused and stage.hints_visible, "Completion does not intercept Enter in pause")
	await _click(pause.menu.get_node("Return"))
	await _joy(JOY_BUTTON_A)
	_check(current_scene == stage and paused and pause.menu.visible, "Completion does not intercept A in confirmation")
	await _key(KEY_ESCAPE)
	await _key(KEY_ENTER)
	_check(not paused and current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Completion still returns immediately during gameplay")


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


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("PAUSE: " + message)
