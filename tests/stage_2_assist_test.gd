extends SceneTree

var failed := false
var respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)


func _click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.pressed = true
	root.push_input(event, true)
	await _step()
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _step(3)


func _joy_button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):
		return
	DirAccess.make_dir_recursive_absolute("res://deliverables/assist")
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://deliverables/assist/%s.png" % name) == OK, "Save assist preview")


func _jump_to(player: PlayerController, target: Vector2) -> void:
	Input.action_press("jump")
	for frame in 90:
		var dx := target.x - player.position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 8:
			Input.action_press("move_right" if dx > 0 else "move_left")
		await _step()
		Input.action_release("jump")
		if player.is_on_floor() and absf(player.position.y - (target.y - 26)) < 1:
			break
	Input.action_release("move_left")
	Input.action_release("move_right")
	_check(player.is_on_floor() and absf(player.position.y - (target.y - 26)) < 1, "Assistance splits the initial climb into ordinary jumps")


func _run() -> void:
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(4)
	var stage := current_scene
	var button: Button = stage.get_node("HUD/AssistBlockButton")
	var blocks: Node2D = stage.get_node("AssistBlocks")
	stage.player.respawned.connect(func(): respawns += 1)
	var expected_counts := [2, 2, 1, 2, 3, 1]
	var added_positions := {1: Vector2(860, -880), 3: Vector2(880, -2280), 4: Vector2(410, -3020)}
	var removed_positions := {1: Vector2(770, -530), 2: Vector2(490, -1250), 3: Vector2(770, -1970), 5: Vector2(770, -3410)}
	_check(stage.section_deaths == 0, "Initial spawn is not a death")
	_check(not button.visible, "Assistance stays hidden before five deaths")
	stage._toggle_assist()
	_check(blocks.get_child_count() == 0, "Assistance cannot be enabled before unlocking")
	for section in 6:
		var expected_count: int = expected_counts[section]
		stage._set_checkpoint(section)
		stage.player.respawn()
		await _step(3)
		_check(stage.section_deaths == 0, "Each checkpoint starts a new death count")
		_check(not button.visible, "New checkpoints hide assistance")
		_check(not stage.assist_enabled and blocks.get_child_count() == 0, "New checkpoints remove the previous assistance")
		for death in 5:
			stage.player.position.y = stage.checkpoints.get_child(section).position.y + 200
			await _step(3)
			_check(stage.section_deaths == death + 1, "Each fall counts exactly once")
			_check(button.visible == (death == 4), "Assistance appears on the fifth death")
		if section == 0:
			await _capture("assist-unlocked")
			await _click(button)
		elif section == 1:
			await _key(KEY_H)
			await _key(KEY_UP)
			_check(root.gui_get_focus_owner() == button, "Help menu navigation reaches the assist button")
			await _capture("assist-focus")
			await _key(KEY_ENTER)
		elif section == 2:
			await _joy_button(JOY_BUTTON_Y)
			await _joy_button(JOY_BUTTON_DPAD_UP)
			_check(root.gui_get_focus_owner() == button, "Gamepad navigation reaches assistance")
			await _joy_button(JOY_BUTTON_A)
		else:
			button.pressed.emit()
			await _step(3)
		_check(stage.assist_enabled and blocks.get_child_count() == expected_count, "Each section uses the requested number of platforms")
		_check(not button.disabled and button.text.contains("解除"), "Installed assistance can be removed with the same button")
		_check(not stage.help_visible and stage.player.controls_enabled, "Installing resumes play at the checkpoint")
		_check(root.gui_get_focus_owner() == null, "A later jump cannot activate the assist button")
		var positions: Array[Vector2] = []
		for block in blocks.get_children():
			positions.append(block.position)
			var hit := KinematicCollision2D.new()
			stage.player.position = block.position + Vector2(0, 60)
			_check(stage.player.test_move(stage.player.transform, Vector2(0, -100), hit) and hit.get_collider() == block and hit.get_normal().y > 0.9, "Platforms stop the player from passing through from below")
			stage.player.position = block.position - Vector2(0, 80)
			_check(stage.player.test_move(stage.player.transform, Vector2(0, 100), hit) and hit.get_collider() == block and hit.get_normal().y < -0.9, "Platforms support landing from above")
		if added_positions.has(section):
			_check(positions.has(added_positions[section]), "An empty red-circled location receives a platform")
		if removed_positions.has(section):
			_check(not positions.has(removed_positions[section]), "An occupied red-circled location is cleared")
		stage.player.respawn()
		await _step(3)
		if section == 0:
			await _capture("assist-enabled")
			stage.player.wall_actions_enabled = false
			await _jump_to(stage.player, blocks.get_child(0).position)
			await _jump_to(stage.player, Vector2(620, 460))
			stage.player.wall_actions_enabled = true
		else:
			stage.player.position = blocks.get_child(-1).position + Vector2(0, -26.1)
			await _step(3)
			_check(stage.player.is_on_floor(), "Removal is tested while standing on an assist platform")
		var removed_position: Vector2 = blocks.get_child(0).global_position
		var removal_position: Vector2 = stage.player.global_position
		var removal_camera: Vector2 = stage.camera.position
		var respawns_before_removal := respawns
		if section == 0:
			await _click(button)
			_check(stage.player.position.y < stage.checkpoints.get_child(section).position.y - 80, "Removing assistance preserves climbing progress")
			await _capture("assist-removed")
		elif section == 1:
			await _key(KEY_H)
			await _key(KEY_UP)
			_check(root.gui_get_focus_owner() == button, "Keyboard navigation can select removal after installation")
			await _key(KEY_ENTER)
		elif section == 2:
			await _joy_button(JOY_BUTTON_Y)
			await _joy_button(JOY_BUTTON_DPAD_UP)
			_check(root.gui_get_focus_owner() == button, "Gamepad navigation can select removal after installation")
			await _joy_button(JOY_BUTTON_A)
		else:
			button.pressed.emit()
			_check(stage.player.global_position == removal_position and stage.camera.position == removal_camera, "Removal preserves the exact position and camera")
			await _step(3)
		_check(not stage.assist_enabled and blocks.get_child_count() == 0, "Removing assistance clears all extra platforms")
		_check(respawns == respawns_before_removal, "Removing assistance never respawns the player")
		_check(stage.player.global_position.distance_to(removal_position) < 80, "Removing assistance leaves the player at the current location")
		var probe: Transform2D = stage.player.global_transform
		probe.origin = removed_position + Vector2(0, 60)
		_check(not stage.player.test_move(probe, Vector2(0, -60)), "Removed platforms no longer block movement")
		_check(stage.section_deaths == 5 and button.visible and not button.disabled, "Removal keeps assistance unlocked")
		_check(not stage.help_visible and stage.player.controls_enabled and root.gui_get_focus_owner() == null, "Removal resumes play without retaining button focus")
		button.pressed.emit()
		await _step(3)
		_check(stage.assist_enabled and blocks.get_child_count() == expected_count, "Assistance can be reinstalled without more deaths")
		for toggle in 4:
			button.pressed.emit()
			_check(blocks.get_child_count() == (0 if toggle % 2 == 0 else expected_count), "Rapid toggling never leaves duplicate platforms")
		await _step(3)
		stage.player.position.y = stage.checkpoints.get_child(section).position.y + 200
		await _step(3)
		_check(stage.section_deaths == 6 and blocks.get_child_count() == expected_count, "A further death preserves the installed platforms")
		stage._retry()
		await _step(3)
		Input.action_press("reset")
		await _step()
		Input.action_release("reset")
		await _step(3)
		_check(stage.section_deaths == 6, "Manual retries preserve the count without adding deaths")
		_check(button.visible, "Retries preserve unlocked assistance")
		_check(blocks.get_child_count() == expected_count, "Manual retries preserve installed platforms")
	stage._on_completed()
	await _step(2)
	_check(not button.visible, "Completion hides assistance")
	stage._return_to_select()
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage2").pressed.emit()
	await _step(4)
	_check(current_scene.section_deaths == 0, "Re-entering starts a new death count")
	_check(not current_scene.get_node("HUD/AssistBlockButton").visible, "Re-entering hides assistance")
	_check(current_scene.get_node("AssistBlocks").get_child_count() == 0, "Re-entering starts without extra platforms")
	current_scene.queue_free()
	await _step(3)
	OS.delay_msec(100)
	print("STAGE_2_ASSIST_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)
