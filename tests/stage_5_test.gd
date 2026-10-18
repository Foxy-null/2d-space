extends SceneTree

var stage: Node2D
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var collected := 0
var launches := 0
var flips: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage5").pressed.emit()
	await _step(20)
	_check(current_scene.scene_file_path == "res://scenes/stage_5.tscn", "Stage 5 must load from the menu")
	if failed:
		return
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	player.gravity_changed.connect(func(up: bool): flips.append(-1 if up else 1))
	stage.get_node("Rooms/Room2/LaunchSpring").launched.connect(func(_body): launches += 1)
	stage.get_node("Rooms/Room2/Items/JumpCrystal").collected.connect(func(_body): collected += 1)
	_check(stage.rooms.get_child_count() == 3 and player.is_on_floor(), "Three rooms start at a safe entrance")
	_check(player.wall_actions_enabled and player.dash_enabled, "Existing abilities are available")
	_check(not stage.help_visible and not stage.hints_visible, "Help starts hidden")
	_check(stage.get_meta("environment_theme") == 3, "The course uses the existing lava environment")
	# Reuse the project's real-input routes; never teleport or grant abilities during traversal.
	for index in 3:
		_check(stage.room_index == index, "Rooms are traversed in order")
		await _screenshot("room_%d" % (index + 1))
		var before := respawns
		await _cross_pattern_room(index)
		_check(respawns == before, "Room %d is traversable without falling" % (index + 1))
		if index < 2:
			_drive("move_right")
			await _until(func(): return stage.room_index == index + 1, 100, "Cross the room boundary")
			_check(stage.transitioning and not player.controls_enabled, "Room slides pause controls")
			_release_inputs()
			await _step(25)
			_check(not stage.transitioning and player.controls_enabled, "Controls resume in the next room")
			_check(stage.camera.position == Vector2((index + 1) * 1280 + 640, 360), "Camera settles on the new room")
	await _until(func(): return stage.completed, 60, "An actual landing presses the final arrival switch")
	_check(stage.get_node("Rooms/Room3/Goal").is_pressed() and stage.get_node("HUD/Completion").visible, "Final arrival displays completion")
	_check(launches > 0 and collected > 0, "The Spring and jump crystal work during traversal")
	_check(flips.has(-1) and flips.has(1), "Ceiling route uses both gravity directions")
	_check(respawns == 2, "The only traversal respawns are room transitions")
	await _screenshot("completed")
	for y in [-100, 850]:
		player.position.y = y
		await _step(3)
		_check(stage.room_index == 2 and absf(player.position.x - 2650) < 2, "Falling restores the current room entrance")
		_check(player.gravity_direction == 1 and player.is_dash_ready(), "Retry restores gravity and dash")
	stage.set_help_visible(true)
	var paused_position := player.position
	await _step(15)
	_check(player.position == paused_position and not player.controls_enabled, "Help pauses player movement")
	stage.get_node("HUD/Help/Rows/Hints").button_pressed = true
	_check(stage.hints_visible and stage.get_node("HUD/Hint").visible, "Hints can be shown")
	stage.get_node("HUD/Help/Rows/Retry").pressed.emit()
	await _step(3)
	_check(player.controls_enabled and not stage.help_visible and stage.hints_visible, "Retry closes help and preserves hints")
	player.position.x += 60
	await _key(KEY_R)
	_check(absf(player.position.x - 2650) < 2 and stage.room_index == 2, "R retries the current room")
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Esc returns to selection")
	current_scene.get_node("Margin/Content/Stages/Stage5").pressed.emit()
	await _step(5)
	_check(current_scene.room_index == 0 and not current_scene.completed and not current_scene.hints_visible, "Re-entry resets progress and hints")
	current_scene.call("_transition_to_next")
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Esc also returns during a room slide")
	print("STAGE_5_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _screenshot(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):
		return
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-5")
	await _step(3)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/stage-5/%s.png" % filename)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("STAGE_5: " + message)
		quit(1)


func _cross_pattern_room(index: int) -> void:
	match index:
		0:
			for x in [290, 460, 630, 800, 970, 1170]:
				await _jump()
				await _land_at(x)
		1:
			_drive("move_right")
			await _until(func(): return player.velocity.y < -700, 60, "Launch from the entrance Spring")
			await _land_at(480)
			await _jump()
			_drive("move_right")
			await _until(func(): return player.is_air_jump_ready(), 90, "Collect the midair jump crystal")
			await _jump()
			await _land_at(860)
			await _jump()
			await _land_at(1170)
		2:
			_drive("move_right")
			await _step(8)
			await _jump()
			await _until(func(): return player.gravity_direction == -1, 70, "Enter the ceiling route")
			await _until(func(): return player.is_on_floor(), 90, "Land upside down on the long ceiling")
			_check(player.position.y < 250, "Ceiling route travels across the top of the room")
			await _until(func(): return player.gravity_direction == 1, 220, "Leave through the far Down gate")
			await _land_at(1170)
	_release_inputs()


func _land_at(x: float) -> void:
	for frame in 160:
		_release_inputs()
		if absf(_x() - x) > 8:
			Input.action_press("move_right" if _x() < x else "move_left")
		if player.is_on_floor() and absf(_x() - x) < 24:
			return
		await _step()
	_check(false, "Land on the next distinct platform at %s" % x)


func _until(condition: Callable, limit: int, message: String) -> void:
	for frame in limit:
		if condition.call():
			return
		await _step()
	_check(false, message)


func _jump() -> void:
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")


func _drive(direction: String) -> void:
	_release_inputs()
	Input.action_press(direction)


func _x() -> float:
	return player.position.x - stage.room_index * 1280


func _release_inputs() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


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
	await _step(3)
