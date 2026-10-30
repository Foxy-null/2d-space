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
	await stage.get_node("StageIntro").tree_exited
	player = stage.player
	_check(stage.scene_file_path == "res://scenes/stage_5.tscn", "Stage 5 loads from selection")
	_check(stage.rooms.get_child_count() == 34 and stage.TITLES.size() == 34, "Thirty-four named rooms are available")
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
		if index >= 30:
			await _applications_main()
			if failed: return
		elif index >= 27:
			await _inverted_main()
			if failed: return
		elif index >= 24:
			await _entry_begin()
			if failed: return
		for frame in 1800:
			if stage.transitioning or stage.completed: break
			if index >= 18 and not rested and stage.next_bumper == 3:
				await _land_at_wide_rest()
				await _step(180)
				await _repeat_wide_third(1.0, 20)
				rested = true
				if failed: return
				if index >= 24:
					await _entry_finish()
					break
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
	_check(total_bumpers == 184 and visited_bumpers.size() == 184 and respawns == 33, "All 184 reflections are reachable without a death")
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
	await stage.get_node("StageIntro").tree_exited
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
		await _step(35)
		_check(stage.room_index == 0 and _x() < 100, "The non-exit boundaries restore the current checkpoint")
	player.position = Vector2(580, 100)
	await _step(35)
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
		FullJumpInput.press(player)
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
		if action != "jump" or not FullJumpInput.is_holding():
			Input.action_release(action)
	if is_instance_valid(player) and player.get_held_object()!=null: Input.action_press("wall_grab")


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


func _land_at_wide_rest(strength: float = 1.0, rest_name: String = "Rest") -> void:
	var before := respawns
	var rest: Node2D = stage.rooms.get_child(stage.room_index).get_node(rest_name)
	for frame in 600:
		_steer_to(rest.position - Vector2(0, 34), false, strength)
		await _step()
		if player.is_on_floor() and not player.is_dashing() and absf(player.velocity.x) < 60 and absf(_x() - rest.position.x) < 70:
			_release_inputs()
			await _step(30)
			_check(player.is_on_floor() and respawns == before, "The detour lands and stops its actual dash on the real observation rest")
			return
	_check(false, "The real flight reaches its safe intermediate rest")


func _repeat_wide_third(strength: float, dash_delay: int, bumper_index: int = 2) -> void:
	var bumper: Node2D = stage._bumpers().get_child(bumper_index)
	var before := respawns
	var repeated: Array[bool] = []
	bumper.launched.connect(func(_body): repeated.append(true), CONNECT_ONE_SHOT)
	FullJumpInput.press(player)
	await _step()
	FullJumpInput.release_after_apex(player)
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
	_check(not repeated.is_empty() and respawns == before, "A normal jump and upward dash return from the rest to the visible reflection")


func _entry_begin(strength: float = 1.0) -> void:
	var before := respawns
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	if stage.room_index == 26:
		Input.action_press("wall_grab")
		await _step()
		Input.action_release("wall_grab")
		_check(player.get_held_object()==room.get_node("Items/Parachute"),"The real entrance parachute is picked up")
		if failed: return
		for frame in 900:
			_entry_horizontal(320,strength)
			await _step()
			if player.position.y<970: break
			if respawns>before: break
		_check(player.position.y<970 and respawns==before,"The held native parachute actually rises in the real wind")
	else:
		var launches: Array[bool] = []
		room.get_node("Items/Spring").launched.connect(func(_body): launches.append(true),CONNECT_ONE_SHOT)
		for frame in 120:
			_entry_horizontal(room.get_node("Items/Spring").position.x,strength)
			await _step()
			if not launches.is_empty() or respawns>before: break
		_check(not launches.is_empty() and respawns==before,"The entrance uses the real Spring")
	_release_inputs()


func _entry_horizontal(target: float, strength: float = 1.0) -> void:
	_release_inputs()
	var error := target-_x()-player.velocity.x*absf(player.velocity.x)/(2*player.air_acceleration)
	if absf(error)>4: Input.action_press("move_right" if error>0 else "move_left",strength)


func _entry_finish(strength: float = 1.0, delay: int = 20) -> void:
	var before := respawns
	var late_rested := false
	for frame in 1200:
		if stage.transitioning or stage.completed or respawns > before: break
		if stage.room_index in [24,25,30] and stage.next_bumper == 3 and player.is_on_floor():
			var shelf: StaticBody2D = stage.rooms.get_child(stage.room_index).get_node("LateRest")
			var supported := false
			for index in player.get_slide_collision_count():
				var contact := player.get_slide_collision(index)
				if contact.get_collider() == shelf and contact.get_normal().dot(Vector2.UP) > 0.8: supported = true
			_check(supported,"The alternate relaunch genuinely stands on the native second shelf")
			if failed: return
			await _repeat_wide_third(strength,delay,3)
			if failed: return
			print("CANYON_ENTRY_LATE_RELAUNCH room=",stage.room_index+1)
		if stage.room_index in [24,25,30] and stage.next_bumper == 4 and not late_rested:
			await _land_at_wide_rest(strength,"LateRest")
			if failed: return
			var stopped := player.position
			await _step(180)
			_check(player.is_on_floor() and player.position.distance_to(stopped)<2 and respawns==before,"The second native shelf permits a safe three-second rest before dropping to the next reflection")
			late_rested = true
			if stage.room_index==30: _application_snapshot("room31_late_rest")
		_steer(strength)
		await _step()


func _inverted_main(strength: float = 1.0, delay: int = 20) -> void:
	await _inverted_begin(strength)
	if failed: return
	await _inverted_chain(strength,delay)


func _inverted_chain(strength: float, delay: int = 20) -> void:
	var before := respawns
	for frame in 1200:
		if stage.next_bumper >= 3 or respawns > before: break
		_inverted_steer(strength)
		await _step()
		if frame % 120 == 0 and OS.get_cmdline_user_args().has("--trace"): print("INV_FIRST p=",Vector2(_x(),player.position.y)," v=",player.velocity," next=",stage.next_bumper)
	_check(stage.next_bumper == 3 and respawns == before,"Inverted Spring reaches three actual reflections")
	if failed: return
	await _inverted_rest("Rest",strength)
	if failed: return
	await _inverted_observe("Rest")
	await _inverted_repeat(2,strength,delay)
	if failed: return
	await _inverted_finish(strength,delay)


func _inverted_finish(strength: float, delay: int = 20) -> void:
	var before := respawns
	var index: int = stage.room_index
	var late_rested := false
	var count: int = stage._bumpers().get_child_count()
	var captured_down := false
	for frame in 1800:
		if stage.completed or stage.transitioning or respawns > before: break
		if count > 4 and stage.next_bumper == 3 and player.is_on_floor():
			await _inverted_repeat(3,strength,delay)
			if failed: return
		if count > 4 and stage.next_bumper == 4 and not late_rested:
			await _inverted_rest("LateRest",strength)
			if failed: return
			await _inverted_observe("LateRest")
			late_rested = true
		if stage.next_bumper < count:
			_inverted_steer(strength)
		else:
			var room: Node2D = stage.rooms.get_child(index)
			var left: bool = room.get_meta("exit_left",false)
			var gate: Node2D = room.get_node("Gates/Down")
			var target := gate.position.x+(-70 if left else 70)
			if player.gravity_direction > 0:
				target = room.get_node("Goal").position.x if index==stage.rooms.get_child_count()-1 else room.get_node("Exit").position.x
			_entry_horizontal(target,strength)
			if index==stage.rooms.get_child_count()-1 and player.gravity_direction>0 and player.is_on_floor() and _x()>target-90 and _x()<target-70: FullJumpInput.press(player)
		await _step()
		if frame % 120 == 0 and OS.get_cmdline_user_args().has("--trace"): print("INV_LAST p=",Vector2(_x(),player.position.y)," v=",player.velocity," next=",stage.next_bumper," g=",player.gravity_direction)
		if not captured_down and player.gravity_direction==1 and not stage.transitioning and respawns==before:
			_inverted_snapshot("room%d_down" % (index+1))
			captured_down = true
	_release_inputs()


func _inverted_begin(strength: float) -> void:
	var before := respawns
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	if stage.room_index == 29:
		Input.action_press("wall_grab")
		await _step()
		_check(player.get_held_object()==room.get_node("Items/Parachute"),"The actual entrance parachute is grabbed")
		var captured_wind := false
		for frame in 900:
			_entry_horizontal(room.get_node("Gates/Up").position.x,strength)
			await _step()
			if not captured_wind and player.position.y<1240 and player.gravity_direction==1:
				_inverted_snapshot("room30_wind")
				captured_wind = true
			if player.gravity_direction < 0 or respawns > before: break
		_check(player.gravity_direction<0 and player.get_held_object()==room.get_node("Items/Parachute") and respawns==before,"The real held parachute and wind reach the upper gate")
		if failed: return
		await _inverted_throw(strength)
	for frame in 180:
		if player.gravity_direction < 0: break
		Input.action_press("move_left" if room.get_meta("exit_left",false) else "move_right",strength)
		await _step()
		if player.gravity_direction < 0: break
	_release_inputs()
	_check(player.gravity_direction == -1 and respawns == before,"The real entrance Up gate flips gravity")
	await _inverted_launch(strength)


func _inverted_throw(strength: float) -> void:
	Input.action_press("move_left",strength)
	await _step(2)
	Input.action_release("wall_grab")
	await _step()
	_release_inputs()
	_check(player.get_held_object()==null,"The actual parachute is thrown before the inverted reflections")


func _inverted_launch(strength: float) -> void:
	var before := respawns
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	for frame in 240:
		if stage.room_index == 29: _entry_horizontal(220 if player.position.y>=980 else 110,strength)
		await _step()
		if player.is_on_floor(): break
	_check(player.is_on_floor() and absf(player.position.y-326)<2 and respawns==before,"The native entry reaches the actual inverted ceiling")
	if failed: return
	if OS.get_cmdline_user_args().has("--screenshots"):
		_release_inputs()
		await _step(30)
		_inverted_snapshot("room%d_ceiling" % (stage.room_index+1))
	var launched: Array[bool] = []
	room.get_node("Items/Spring").launched.connect(func(_body): launched.append(true),CONNECT_ONE_SHOT)
	for frame in 180:
		_entry_horizontal(room.get_node("Items/Spring").position.x,strength)
		await _step()
		if not launched.is_empty() or respawns > before: break
	_release_inputs()
	_check(not launched.is_empty() and player.velocity.y > 0 and respawns==before,"The real upside-down Spring launches downward")


func _inverted_steer(strength: float) -> void:
	var bumper: Node2D = stage._bumpers().get_child(stage.next_bumper)
	_inverted_to(bumper.position+Vector2(0,62),strength)


func _inverted_to(target: Vector2, strength: float, allow_dash := true) -> void:
	_entry_horizontal(target.x,strength)
	var dx := target.x-_x()
	var needs_dash := (player.position.y-target.y)*player.gravity_direction > -70 and player.velocity.y*player.gravity_direction > 0 and absf(dx)>75
	if allow_dash and needs_dash and player.is_dash_ready() and not player.is_dashing() and not player.is_on_floor():
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx)>40: Input.action_press("move_right" if dx>0 else "move_left",strength)
		Input.action_press("move_down" if player.gravity_direction<0 else "move_up")
		Input.action_press("dash")


func _inverted_rest(name: String, strength: float) -> void:
	var before := respawns
	var rest: StaticBody2D = stage.rooms.get_child(stage.room_index).get_node(name)
	for frame in 600:
		_inverted_to(rest.position+Vector2(0,34),strength,false)
		await _step()
		if respawns > before: break
		if player.is_on_floor() and absf(_x()-rest.position.x)<70 and absf(player.velocity.x)<60:
			_release_inputs()
			await _step(30)
			break
	print("INV_REST ",name," p=",Vector2(_x(),player.position.y)," v=",player.velocity)
	_check(player.is_on_floor() and absf(player.position.y-rest.position.y-34)<2 and respawns==before,"Actual native inputs reach the inverted "+name)


func _inverted_repeat(index: int, strength: float, delay: int) -> void:
	var before := respawns
	var bumper: Node2D = stage._bumpers().get_child(index)
	var repeated: Array[bool] = []
	bumper.launched.connect(func(_body): repeated.append(true),CONNECT_ONE_SHOT)
	await _pulse("jump")
	for frame in delay:
		_inverted_to(bumper.position+Vector2(0,62),strength)
		await _step()
	_release_inputs()
	Input.action_press("move_down")
	await _pulse("dash")
	await _step(10)
	for frame in 300:
		if not repeated.is_empty() or respawns > before: break
		_inverted_to(bumper.position+Vector2(0,62),strength)
		await _step()
	_check(not repeated.is_empty() and respawns==before,"Actual Jump and downward Dash repeat the visible reflection")


func _inverted_observe(name: String) -> void:
	var stopped := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped)<2,"The native inverted rest stays safe for three seconds")
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	var rest: StaticBody2D = room.get_node(name)
	var supported := false
	for index in player.get_slide_collision_count():
		var contact := player.get_slide_collision(index)
		if contact.get_collider()==rest and contact.get_normal().dot(Vector2.DOWN)>0.8: supported = true
	_check(supported and player.gravity_direction==-1,"The actual intended ceiling supports the inverted player")
	for shape in [rest.get_node("Collision"),stage._bumpers().get_child(stage.next_bumper).get_node("CollisionShape2D")]:
		var bounds: Rect2 = shape.get_global_transform_with_canvas()*shape.shape.get_rect()
		_check(root.get_visible_rect().encloses(bounds),"The rest and next actual reflection are fully visible: "+str(bounds))
		for path in ["HUD/Info","HUD/Hint","HUD/PauseButton"]:
			var panel: Control = stage.get_node(path)
			_check(not panel.visible or not panel.get_global_rect().intersects(bounds),"The rest and next reflection are outside "+path+" "+str(bounds))
	_inverted_snapshot("room%d_%s" % [stage.room_index+1,name.to_snake_case()])


func _inverted_snapshot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	RenderingServer.force_draw()
	var directory := "res://docs/screenshots/canyon-inverted/"+("hints" if OS.get_cmdline_user_args().has("--hints") else "default")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"The actual native inverted-course image is saved")


func _pulse(action: String) -> void:
	FullJumpInput.press_action(action, player)
	await _step()
	FullJumpInput.release_action(action, player)


func _applications_boots_begin(strength: float, delay: int) -> void:
	await _pulse("jump")
	for frame in 20:
		_entry_horizontal(150,strength)
		await _step()
	_check(player.is_air_jump_ready(),"The real airborne boots grant the extra jump")
	if failed: return
	_application_snapshot("room31_boots_pickup")
	await _pulse("jump")
	for frame in delay:
		_entry_horizontal(200,strength)
		await _step()
	_release_inputs()
	Input.action_press("move_up")
	await _pulse("dash")
	await _step(10)
	_application_snapshot("room31_boots_launch")


func _applications_relay_begin(strength: float, delay: int) -> void:
	var before := respawns
	await _inverted_begin(strength)
	if failed: return
	for frame in 1200:
		if stage.next_bumper>=3 or respawns>before: break
		_inverted_steer(strength)
		await _step()
	_check(stage.next_bumper==3 and respawns==before,"The inverted entrance reaches the first three real reflections")
	if failed: return
	await _inverted_rest("Rest",strength)
	if failed: return
	await _inverted_observe("Rest")
	var room: Node2D = stage.rooms.get_child(31)
	for shape in [room.get_node("Gates/Down/CollisionShape2D"),room.get_node("RelayFloor/Collision")]:
		var bounds: Rect2 = shape.get_global_transform_with_canvas()*shape.shape.get_rect()
		_check(root.get_visible_rect().encloses(bounds),"The next actual Down and normal landing are fully visible from the ceiling rest: "+str(bounds))
		for path in ["HUD/Info","HUD/Hint","HUD/PauseButton"]:
			var panel: Control = stage.get_node(path)
			_check(not panel.visible or not panel.get_global_rect().intersects(bounds),"The next Down and normal landing remain outside "+path)
	if failed: return
	await _pulse("jump")
	for frame in delay:
		_entry_horizontal(1720,strength)
		await _step()
	_release_inputs()
	Input.action_press("move_down")
	await _pulse("dash")
	for frame in 600:
		_entry_horizontal(1740,strength)
		await _step()
		if player.gravity_direction==1 and player.is_on_floor(): break
		if respawns>before: break
	_release_inputs()
	print("RELAY_FLOOR p=",Vector2(_x(),player.position.y)," g=",player.gravity_direction," n=",stage.next_bumper)
	_check(player.gravity_direction==1 and player.is_on_floor() and respawns==before,"The real middle Down returns to the actual normal floor")
	if failed: return
	await _step(180)
	_application_snapshot("room32_normal_rest")


func _applications_relay_refill(strength: float, delay: int) -> void:
	var before := respawns
	var refill: Area2D = stage.rooms.get_child(31).get_node("Items/Refill")
	var refilled: Array[bool] = []
	refill.collected.connect(func(_body): refilled.append(true),CONNECT_ONE_SHOT)
	await _pulse("jump")
	for frame in delay:
		_entry_horizontal(1740,strength)
		await _step()
	_release_inputs()
	Input.action_press("move_up")
	await _pulse("dash")
	for frame in 180:
		_entry_horizontal(1740,strength)
		await _step()
		if not refilled.is_empty() and not player.is_dashing(): break
		if respawns>before: break
	print("RELAY_REFILL p=",Vector2(_x(),player.position.y)," v=",player.velocity," ready=",player.is_dash_ready())
	_check(not refilled.is_empty() and player.is_dash_ready() and respawns==before,"The actual upward Dash contacts the middle refill")
	if failed: return
	_application_snapshot("room32_refill")


func _applications_relay_finish(strength: float, delay: int) -> void:
	var before := respawns
	await _applications_relay_refill(strength,delay)
	if failed: return
	_release_inputs()
	Input.action_press("move_right",strength)
	Input.action_press("move_up")
	await _pulse("dash")
	for frame in 1200:
		if stage.transitioning or stage.completed or respawns>before: break
		_steer(strength)
		await _step()
	_release_inputs()


func _applications_wall_begin(strength: float, delay: int) -> void:
	var before := respawns
	await _entry_begin(strength)
	if failed: return
	for frame in 1200:
		if stage.next_bumper>=3 or respawns>before: break
		_steer(strength)
		await _step()
	_check(stage.next_bumper==3 and respawns==before,"The actual Spring reaches the three lower reflections")
	if failed: return
	await _land_at_wide_rest(strength)
	await _step(180)
	_application_snapshot("room33_lower_rest")
	await _pulse("jump")
	for frame in delay:
		_entry_horizontal(1702,strength)
		await _step()
	_release_inputs()
	Input.action_press("move_right",strength)
	Input.action_press("move_up")
	await _pulse("dash")
	var climbed := 0
	for frame in 600:
		_release_inputs()
		Input.action_press("move_right",strength)
		Input.action_press("wall_grab")
		Input.action_press("move_up")
		await _step()
		if player.is_wall_grabbing(): climbed+=1
		if player.is_on_floor() and player.position.y<800: break
		if respawns>before: break
	_release_inputs()
	print("WALL_TOP p=",Vector2(_x(),player.position.y)," stamina=",player.get_wall_stamina()," climbed=",climbed)
	_check(player.is_on_floor() and player.position.y<800 and climbed>30 and respawns==before,"The real wall climb reaches the solid rock top")
	if failed: return
	await _step(180)
	_application_snapshot("room33_wall_top")


func _applications_wall_finish(strength: float, delay: int) -> void:
	var before := respawns
	await _pulse("jump")
	for frame in delay:
		_entry_horizontal(2000,strength)
		await _step()
	_release_inputs()
	Input.action_press("move_right",strength)
	Input.action_press("move_up")
	await _pulse("dash")
	for frame in 1200:
		if stage.transitioning or stage.completed or respawns>before: break
		_steer(strength)
		await _step()
	_release_inputs()

func _applications_main(strength: float = 1.0, delay: int = 20) -> void:
	var before := respawns
	match stage.room_index:
		30:
			await _applications_boots_begin(strength,delay)
			if failed: return
			for frame in 1200:
				if stage.next_bumper>=3 or respawns>before: break
				_steer(strength)
				await _step()
			_check(stage.next_bumper==3 and respawns==before,"The real boots and jumps reach three reflections")
			if failed: return
			await _land_at_wide_rest(strength)
			await _step(180)
			_application_snapshot("room31_main_rest")
			await _repeat_wide_third(strength,delay)
			if failed: return
			await _entry_finish(strength,delay)
		31:
			await _applications_relay_begin(strength,delay)
			if failed: return
			await _applications_relay_finish(strength,delay)
		33:
			await _moving_main(strength,delay)
		32:
			await _applications_wall_begin(strength,delay)
			if failed: return
			await _applications_wall_finish(strength,delay)

func _application_snapshot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	stage._update_hud()
	RenderingServer.force_draw()
	var directory := "res://docs/screenshots/canyon-applications/"+("hints" if stage.hints_visible else "default")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"The actual native application image is saved")


func _moving_first(strength: float) -> void:
	var before:=respawns
	await _entry_begin(strength)
	for frame in 1200:
		if stage.next_bumper>=3 or respawns>before:break
		_steer(strength)
		await _step()
	_check(stage.next_bumper==3 and respawns==before,"The real Spring and moving third reflection launch the actual player")
	_moving_snapshot("room34_moving_reflection")


func _moving_relaunch(strength: float, delay: int) -> void:
	var before:=respawns
	var boots: Area2D=stage.rooms.get_child(stage.room_index).get_node("Items/Boots")
	for frame in 240:
		_entry_horizontal(1840,strength)
		await _step()
		if absf(_x()-1840)<5 and absf(player.velocity.x)<15:break
	_release_inputs()
	_check(player.is_on_floor(),"The real rest supplies a grounded Boot launch")
	await _pulse("jump")
	for frame in delay:
		_entry_horizontal(1840,strength)
		await _step()
	_check(not boots.visible and player.is_air_jump_ready(),"The live jump collects the actual middle Boot")
	_moving_snapshot("room34_boots")
	await _pulse("jump")
	_check(not player.is_air_jump_ready(),"The actual Boot jump is consumed in the middle ascent")
	for frame in delay:
		_entry_horizontal(1840,strength)
		await _step()
	_release_inputs()
	Input.action_press("move_up")
	await _pulse("dash")
	await _step(10)
	for frame in 600:
		if stage.next_bumper>=4 or respawns>before:break
		_steer(strength)
		await _step()
	_check(stage.next_bumper>=4 and respawns==before,"The actual middle Boot and Dash reach the upper fourth reflection")


func _moving_main(strength: float, delay: int) -> void:
	await _moving_first(strength)
	if failed:return
	await _land_at_wide_rest(strength)
	await _step(180)
	_moving_snapshot("room34_rest")
	await _moving_relaunch(strength,delay)
	if failed:return
	await _entry_finish(strength,delay)


func _moving_snapshot(_label: String) -> void:
	pass
