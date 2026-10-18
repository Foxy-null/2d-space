extends SceneTree

var stage: Node2D
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var total_bumpers := 0
var ceiling_reflected_down := false
var wind_frames := 0
var dash_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage5").pressed.emit()
	await _step(15)
	stage = current_scene
	player = stage.player
	_check(stage.scene_file_path == "res://scenes/stage_5.tscn", "Stage 5 loads from selection")
	_check(stage.rooms.get_child_count() == 12 and stage.TITLES.size() == 12, "Twelve named rooms are available")
	_check(stage.get_meta("environment_theme") == 2, "Use the previously unused wild planet")
	_check(player.move_speed == 360 and player.dash_speed == 900 and player.wall_actions_enabled, "Preserve the existing movement abilities")
	_check(not stage.help_visible and not stage.hints_visible, "Help and route hints start hidden")
	for room in stage.rooms.get_children():
		_check(room.get_node("Winds").get_child_count() > 0, "Every room uses real wind areas")
		total_bumpers += room.get_node("Bumpers").get_child_count()
	stage.get_node("Rooms/Room6/Bumpers/Bumper2").launched.connect(func(body): ceiling_reflected_down = body.velocity.y > 0)
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action):
		if action == "dash": dash_count += 1
	)
	# Reachability proof: only ordinary input, no teleports, velocity assignments or resource grants.
	for index in 12:
		_check(stage.room_index == index, "Traverse rooms in order")
		await _screenshot(index + 1)
		var before := respawns
		var target_count: int = stage._bumpers().get_child_count()
		for frame in 1000:
			if stage.transitioning or stage.completed: break
			if not player._winds.is_empty(): wind_frames += 1
			_check(not (player.is_on_floor() and _x() > 210 and _x() < 1100), "No intermediate resting platform is used")
			_steer()
			await _step()
			if respawns > before and not stage.transitioning:
				_check(false, "Room %d must be crossed without dying" % (index + 1))
				return
		_release_inputs()
		if index < 11:
			_check(stage.room_index == index + 1 and stage.transitioning, "The unlocked exit advances to the next checkpoint")
			_check(respawns == before + 1 and not player.controls_enabled, "Only the room transition respawns the player")
			await _step(25)
			_check(player.controls_enabled and not stage.transitioning, "Controls resume after the camera slide")
			_check(stage.camera.position == Vector2((index + 1) * 1280 + 640, 360), "Camera settles on the new room")
		else:
			_check(stage.completed and stage.next_bumper == target_count, "All final-room bumpers precede completion")
		print("STAGE_5_ROOM_%02d_OK" % (index + 1))
	_check(total_bumpers == 43 and respawns == 11, "All 43 reflections are reachable without a death")
	_check(ceiling_reflected_down, "Room 6 reflects off the underside of the ceiling bumper")
	_check(wind_frames > 100 and dash_count > 12, "Traversal uses real wind and chained dashes")
	_check(stage.get_node("Rooms/Room12/Goal").is_pressed() and stage.get_node("HUD/Completion").visible, "Landing on the final switch displays completion")
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Esc returns to selection")
	current_scene.get_node("Margin/Content/Stages/Stage5").pressed.emit()
	await _step(15)
	stage = current_scene
	player = stage.player
	_check(stage.room_index == 0 and stage.next_bumper == 0 and not stage.completed, "Re-entry resets the course")
	_check(not stage.get_node("Rooms/Room1/ExitLock/Collision").disabled, "The exit starts locked")
	# Isolated negative checks use positioning; the reachability proof above never does.
	player.position = Vector2(820, 470)
	player.velocity = Vector2(0, 400)
	await _step(12)
	_check(stage.next_bumper == 0, "An out-of-order bumper cannot unlock the room")
	player.respawn()
	await _step(15)
	for frame in 150:
		if stage.next_bumper > 0: break
		_steer()
		await _step()
	_release_inputs()
	_check(stage.next_bumper == 1, "Make actual reflection progress before retrying")
	await _key(KEY_R)
	_check(stage.next_bumper == 0 and _x() < 100 and player.is_dash_ready(), "R resets reflection progress and abilities")
	for outside in [Vector2(400, -100), Vector2(400, 850), Vector2(1400, 550), Vector2(-100, 550)]:
		player.position = outside
		await _step(3)
		_check(stage.room_index == 0 and _x() < 100, "All boundaries restore the current checkpoint")
	player.position = Vector2(580, 100)
	await _step(4)
	_check(_x() < 100 and stage.next_bumper == 0, "The red obstacle resets the room")
	await _key(KEY_H)
	var paused_position := player.position
	await _step(10)
	_check(stage.help_visible and not player.controls_enabled and player.position == paused_position, "Help pauses player motion")
	stage.get_node("HUD/Help/Rows/Hints").button_pressed = true
	_check(stage.hints_visible and stage.get_node("HUD/Hint").visible and stage.get_node("Rooms/Room12/Route").visible, "Hints reveal all room routes")
	stage.get_node("HUD/Help/Rows/Retry").pressed.emit()
	await _step(3)
	_check(not stage.help_visible and player.controls_enabled and stage.hints_visible, "Retry closes help and preserves hints")
	await _key(KEY_H)
	stage.get_node("HUD/Help/Rows/Return").pressed.emit()
	await _step(3)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "The menu return button works")
	print("STAGE_5_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _steer() -> void:
	_release_inputs()
	var target := Vector2(1268 if stage.room_index < 11 else 1210, 550)
	var ceiling := false
	var bumps: Node2D = stage._bumpers()
	if stage.next_bumper < bumps.get_child_count():
		var bumper: Node2D = bumps.get_child(stage.next_bumper)
		target = bumper.position + Vector2(0, -62)
		ceiling = bumper.position.y < 250
		if ceiling: target.y = bumper.position.y + 62
	var dx := target.x - _x()
	var stopping_distance := player.velocity.x * absf(player.velocity.x) / (2 * player.air_acceleration)
	var error := dx - stopping_distance
	if absf(error) > 3:
		Input.action_press("move_right" if error > 0 else "move_left")
	if player.is_on_floor() and stage.next_bumper == 0 and _x() > 135:
		Input.action_press("jump")
	var needs_dash := player.position.y > target.y - 70 and player.velocity.y > 0 and absf(dx) > 75
	if ceiling:
		needs_dash = target.y < player.position.y and absf(dx) < 30
	if needs_dash and player.is_dash_ready() and not player.is_dashing() and not player.is_on_floor():
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 40: Input.action_press("move_right" if dx > 0 else "move_left")
		Input.action_press("move_up")
		Input.action_press("dash")


func _screenshot(room: int) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	DirAccess.make_dir_recursive_absolute("res://deliverables")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://deliverables/stage5-room-%02d.png" % room)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("STAGE_5: " + message)
		quit(1)


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
