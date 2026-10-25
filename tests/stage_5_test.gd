extends SceneTree

var stage: Node2D
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var total_bumpers := 0
var visited_bumpers: Dictionary = {}
var ceiling_reflected_down := false
var wind_frames := 0
var dash_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_isolate_collection()
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage5").pressed.emit()
	await _step(15)
	stage = current_scene
	player = stage.player
	_check(stage.scene_file_path == "res://scenes/stage_5.tscn", "Stage 5 loads from selection")
	_check(stage.rooms.get_child_count() == 24 and stage.TITLES.size() == 24, "Twenty-four named rooms are available")
	_check(stage.get_meta("environment_theme") == 2, "Use the previously unused wild planet")
	_check(player.move_speed == 360 and player.dash_speed == 900 and player.wall_actions_enabled, "Preserve the existing movement abilities")
	_check(not paused and not stage.hints_visible, "Pause and route hints start hidden")
	_check(not stage.target_marker.visible and not stage.get_node("Rooms/Room1/Route").visible, "The first room leaves the route readable without persistent guides")
	for room in stage.rooms.get_children():
		_check(room.get_node("Winds").get_child_count() > 0, "Every room uses real wind areas")
		total_bumpers += room.get_node("Bumpers").get_child_count()
		for bumper in room.get_node("Bumpers").get_children():
			bumper.launched.connect(func(_body): visited_bumpers[bumper.get_instance_id()] = true)
	stage.get_node("Rooms/Room6/Bumpers/Bumper2").launched.connect(func(body): ceiling_reflected_down = body.velocity.y > 0)
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action):
		if action == "dash": dash_count += 1
	)
	# Reachability proof: only ordinary input, no teleports, velocity assignments or resource grants.
	for index in stage.rooms.get_child_count():
		_check(stage.room_index == index, "Traverse rooms in order")
		_check_route_feedback()
		await _screenshot(index + 1)
		var started := Engine.get_physics_frames()
		var before := respawns
		var target_count: int = stage._bumpers().get_child_count()
		var last_bumper: int = stage.next_bumper
		var rested := false
		for frame in 1800:
			if stage.transitioning or stage.completed: break
			if index >= 18 and not rested and stage.next_bumper == 3:
				await _land_at_wide_rest()
				await _step(180)
				await _repeat_wide_third(1.0, 20)
				rested = true
				if failed: return
			if not player._winds.is_empty(): wind_frames += 1
			_check(index >= 12 or not (player.is_on_floor() and _x() > 210 and _x() < 1100), "The original twelve-room route needs no intermediate rest")
			_steer()
			await _step()
			if not stage.transitioning and stage.next_bumper != last_bumper:
				_check_route_feedback()
				last_bumper = stage.next_bumper
			if respawns > before and not stage.transitioning:
				_check(false, "Room %d must be crossed without dying" % (index + 1))
				return
		_release_inputs()
		if index < stage.rooms.get_child_count() - 1:
			_check(stage.room_index == index + 1 and stage.transitioning, "The unlocked exit advances to the next checkpoint")
			_check(respawns == before + 1 and not player.controls_enabled, "Only the room transition respawns the player")
			await _step(25)
			_check(player.controls_enabled and not stage.transitioning, "Controls resume after the camera slide")
			_check(stage.camera.position.distance_to(stage._camera_position()) < 4, "Camera settles on the new room")
		else:
			_check(stage.completed and stage.next_bumper == target_count, "All final-room bumpers precede completion")
		print("STAGE_5_ROOM_%02d_OK (%.2fs)" % [index + 1, (Engine.get_physics_frames() - started) / 60.0])
	_check(total_bumpers == 128 and visited_bumpers.size() == 128 and respawns == 23, "All 128 reflections are reachable without a death")
	_check(not stage.target_marker.visible, "Completion hides the target marker")
	_check(ceiling_reflected_down, "Room 6 reflects off the underside of the ceiling bumper")
	_check(wind_frames > 100 and dash_count > 12, "Traversal uses real wind and chained dashes")
	_check(stage.goal.is_pressed() and stage.get_node("HUD/Completion").visible, "Landing on the final switch displays completion")
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Enter returns from the shared clear card")
	current_scene.get_node("Margin/Content/Stages/Stage5").pressed.emit()
	await _step(15)
	stage = current_scene
	player = stage.player
	_check(stage.room_index == 0 and stage.next_bumper == 0 and not stage.completed, "Re-entry resets the course")
	_check(not stage.get_node("Rooms/Room1").has_node("ExitLock"), "The first exit has no reflection-history lock")
	# Isolated negative checks use positioning; the reachability proof above never does.
	player.position = Vector2(820, 470)
	player.velocity = Vector2(0, 400)
	await _step(12)
	_check(stage.next_bumper == 0, "Optional route progress still records the demonstrated order")
	_check_route_feedback()
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
	_check_route_feedback()
	_check(not stage.target_marker.visible, "Retry keeps optional guides hidden")
	for outside in [Vector2(400, -100), Vector2(400, 850), Vector2(-100, 550)]:
		player.position = outside
		await _step(3)
		_check(stage.room_index == 0 and _x() < 100, "The non-exit boundaries restore the current checkpoint")
	player.position = Vector2(580, 100)
	await _step(4)
	_check(_x() < 100 and stage.next_bumper == 0, "The red obstacle resets the room")
	await _key(KEY_ESCAPE)
	var pause := stage.get_node("PauseMenu")
	var paused_position := player.position
	await _step(10)
	_check(paused and pause.overlay.visible and player.position == paused_position, "Pause freezes player motion")
	pause.menu.get_node("Hints").pressed.emit()
	_check(stage.hints_visible and stage.get_node("HUD/Hint").visible and stage.rooms.get_child(stage.rooms.get_child_count() - 1).get_node("Route").visible, "Hints reveal all room routes")
	_check_route_feedback()
	pause.menu.get_node("Hints").pressed.emit()
	_check_route_feedback()
	_check(not stage.hints_visible and not stage.get_node("Rooms/Room1/Route").visible and not stage.target_marker.visible, "Hiding hints restores the first room without route overlays")
	pause.menu.get_node("Hints").pressed.emit()
	pause.menu.get_node("Retry").pressed.emit()
	await _step(3)
	_check(not paused and not pause.overlay.visible and player.controls_enabled and stage.hints_visible, "Retry resumes and preserves hints")
	await _key(KEY_ESCAPE)
	pause.menu.get_node("Return").pressed.emit()
	_check(paused and pause.confirmation.visible and current_scene == stage, "Returning waits for confirmation")
	pause.confirmation.get_node("Return").pressed.emit()
	await _step(3)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "The menu return button works")
	print("STAGE_5_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.get_node("CollectionProgress").save_path))
	quit(1 if failed else 0)


func _check_route_feedback() -> void:
	var bumpers: Node2D = stage._bumpers()
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	var unlocked: bool = stage.next_bumper == bumpers.get_child_count()
	var target: Vector2 = room.get_node("Exit").global_position + Vector2(0, -55) if unlocked else bumpers.get_child(stage.next_bumper).global_position
	_check(stage.target_marker.global_position == target and stage.target_marker.visible == (not stage.completed and stage.hints_visible), "The route target follows optional hints in every room")
	_check(stage.target_marker.closed or stage.target_marker.points[0] == stage.target_marker.points[-1], "The target has a complete outline, not only a color change")
	for index in bumpers.get_child_count():
		var number: Label = bumpers.get_child(index).get_node("Number")
		_check(number.text == ("✓" if index < stage.next_bumper else str(index + 1)), "Only actual completed reflections receive check marks")
		_check(number.visible == stage.hints_visible, "Bumper numbers follow optional hints in every room")
	_check(room.get_node("ExitLabel").text == ("←" if room.get_meta("exit_left", false) else "→") and room.get_node("ExitLabel").visible == stage.hints_visible, "The optional exit arrow follows its physical direction without a reflection-history counter")


func _isolate_collection() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://stage_5_route_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))


func _steer(strength: float = 1.0) -> void:
	var final: bool = stage.room_index == stage.rooms.get_child_count() - 1
	var exit: Node2D = stage.rooms.get_child(stage.room_index).get_node("Exit")
	var left: bool = stage.rooms.get_child(stage.room_index).get_meta("exit_left", false)
	var target := Vector2(exit.position.x if final else exit.position.x + (-58 if left else 58), exit.position.y - 70)
	var ceiling := false
	var bumps: Node2D = stage._bumpers()
	if stage.next_bumper < bumps.get_child_count():
		var bumper: Node2D = bumps.get_child(stage.next_bumper)
		target = bumper.position + Vector2(0, -62)
		ceiling = bumper.position.y < 250
		if ceiling: target.y = bumper.position.y + 62
	_steer_to(target, ceiling, strength)


func _steer_to(target: Vector2, ceiling: bool = false, strength: float = 1.0) -> void:
	_release_inputs()
	var dx := target.x - _x()
	var stopping_distance := player.velocity.x * absf(player.velocity.x) / (2 * player.air_acceleration)
	var error := dx - stopping_distance
	if absf(error) > 3:
		Input.action_press("move_right" if error > 0 else "move_left", strength)
	if player.is_on_floor() and stage.next_bumper == 0 and absf(_x() - stage.rooms.get_child(stage.room_index).get_node("Spawn").position.x) > 45:
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
	return player.position.x - stage.rooms.get_child(stage.room_index).position.x


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


func _land_at_wide_rest(strength: float = 1.0) -> void:
	var before := respawns
	var rest: Node2D = stage.rooms.get_child(stage.room_index).get_node("Rest")
	for frame in 600:
		_steer_to(rest.position - Vector2(0, 34), false, strength)
		await _step()
		if player.is_on_floor() and not player.is_dashing() and absf(player.velocity.x) < 60 and absf(_x() - rest.position.x) < 70:
			_release_inputs()
			await _step(30)
			_check(player.is_on_floor() and respawns == before, "The detour lands and stops its actual dash on the real observation rest")
			return
	_check(false, "The real flight reaches its safe intermediate rest")


func _repeat_wide_third(strength: float, dash_delay: int) -> void:
	var bumper: Node2D = stage._bumpers().get_child(2)
	var before := respawns
	var repeated: Array[bool] = []
	bumper.launched.connect(func(_body): repeated.append(true), CONNECT_ONE_SHOT)
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")
	for frame in dash_delay:
		_steer_to(bumper.position - Vector2(0,62), false, strength)
		await _step()
	_release_inputs()
	Input.action_press("move_up")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	await _step(10)
	for frame in 300:
		if not repeated.is_empty() or respawns > before: break
		_steer_to(bumper.position - Vector2(0,62), false, strength)
		await _step()
	_check(not repeated.is_empty() and respawns == before, "A normal jump and upward dash return from the rest to the visible third reflection")
