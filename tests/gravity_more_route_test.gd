extends "res://tests/stage_3_test.gd"

var stick := 1.0
var progress: Node
var negatives := 0
var captured: Dictionary = {}
var checked_strengths: Dictionary = {}
const CAPTURES := ["room_10_entrance", "room_11_entrance", "room_12_entrance", "room_13_entrance", "room_14_entrance", "room_15_arrival", "room_10_scroll_descent", "room_14_scroll_descent", "room_14_return", "room_7_scroll_after_arrival", "room_14_scroll_after_arrival"]


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_more_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	if OS.get_cmdline_user_args().has("--post-arrival-only"):
		await _post_arrival_branches()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--negative-adjusted"):
		await _negative_routes([12, 14])
		_finish()
		return
	if OS.get_cmdline_user_args().has("--negative-only"):
		await _negative_routes()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--recovery-only"):
		await _weak_scroll_branches()
		if not failed: await _recoveries()
		if not failed: await _seam()
		_finish()
		return
	if not OS.get_cmdline_user_args().has("--scroll-only"):
		for strength in ([1.0] if screenshots else [1.0, 0.8]):
			stick = strength
			for index in range(9, 15):
				await _fresh(index)
				await _capture("room_%d_entrance" % (index + 1))
				var started := Engine.get_physics_frames()
				await _composite_course(index)
				if failed: break
				await _reach_goal()
				await _capture("room_%d_arrival" % (index + 1))
				_reset_course()
				if index in [10, 13]:
					await _return_more_to_exit()
					await _capture("room_%d_return" % (index + 1))
				var seconds := float(Engine.get_physics_frames() - started) / 60.0
				print("GRAVITY_MORE_ROOM_%d_SECONDS %.2f strength=%.2f" % [index + 1, seconds, stick])
				_check(respawns == 0 and stage.cleared.has(index) and seconds < 30, "The two challenges, three-second rest and actual return take less than thirty seconds")
				_check(progress.get_count("gravity") == 0, "The main route never collects an optional scroll")
				await _retry()
				_check(stage.room_index == index and stage.cleared.has(index), "R keeps the current cleared checkpoint")
				await _check_return_state(index, true)
				if failed: break
			if failed: break
	stick = 1.0
	if not failed and not OS.get_cmdline_user_args().has("--routes-only"):
		for index in [9, 13]:
			await _scroll_branch(index)
			if failed: break
	if not failed and not OS.get_cmdline_user_args().has("--routes-only"):
		# Existing branches have their own real-input suites; seed them only for this total-display fixture.
		for id in ["wall_loft_01", "inverted_return_02"]:
			_check(progress.collect_scroll("gravity", id) == OK, "Existing confirmed IDs combine with the two actually collected new branches")
		change_scene_to_file("res://scenes/stage_select.tscn")
		await _step(4)
		var card: Button = current_scene.get_node("Margin/Content/Stages/Stage3")
		_check(card.get_node("Content/Collection/Count").text == "4 / 4" and card.accessibility_name.contains("巻物 4 / 4") and not card.disabled, "All four persisted scrolls appear in visible and accessible selection text")
		progress._collected.clear()
		progress.load_progress()
		_check(progress.get_count("gravity") == 4, "All four IDs survive reloading the save file")
	if not failed and not screenshots and not OS.get_cmdline_user_args().has("--scroll-only") and not OS.get_cmdline_user_args().has("--routes-only"):
		await _weak_scroll_branches()
		if not failed: await _recoveries()
		if not failed: await _seam()
		for delay in [16, 24]:
			if failed: break
			jump_spacing = delay
			for index in [9, 10, 12, 13]:
				await _fresh(index)
				await _composite_course(index, 30)
				await _reach_goal()
				_check(respawns == 0 and stage.cleared.has(index), "Crystal transfers accept sixteen- and twenty-four-frame jump spacing")
				if failed: break
			if failed: break
		jump_spacing = 20
	if not failed and not OS.get_cmdline_user_args().has("--routes-only") and not OS.get_cmdline_user_args().has("--scroll-only"):
		await _post_arrival_branches()
	if not failed and not screenshots and not OS.get_cmdline_user_args().has("--positive-only") and not OS.get_cmdline_user_args().has("--scroll-only") and not OS.get_cmdline_user_args().has("--routes-only"):
		await _negative_routes()
	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	_release_inputs()
	print("GRAVITY_MORE_ROUTE_TEST_%s (%d checks, %d negative trials)" % ["FAILED" if failed else "OK", checks, negatives])
	quit(1 if failed else 0)


func _fresh(index: int) -> void:
	_release_inputs()
	_reset_course()
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	stage._set_room(index, false)
	player.respawn()
	await _step(4)
	actions.clear()
	flips.clear()
	respawns = 0
	player.movement_action.connect(func(action): actions[action] = actions.get(action, 0) + 1)
	player.gravity_changed.connect(func(inverted): flips.append(-1 if inverted else 1))
	player.respawned.connect(func(): respawns += 1)
	_connect_composite_signals()
	var total := 0
	for room in stage.rooms.get_children():
		for node in room.find_children("*", "Area2D", true, false):
			if node.get_script() != null and node.get_script().resource_path == "res://scripts/scroll_collectible.gd": total += 1
	_check(total == 4 and progress.TOTALS["gravity"] == total, "All four native scrolls match the stage-selection total")
	await _check_return_state(index, false)


func _check_return_state(index: int, done: bool) -> void:
	var room: Node2D = stage.rooms.get_child(index)
	for name in room.get_meta("return_retract", PackedStringArray()):
		var node: Node2D = room.get_node(name)
		_check(node.visible != done, "Only actual arrival retracts return obstacles")
		if node is StaticBody2D:
			_check(node.get_node("Collision").disabled == done, "Return walls agree with their visible state")


func _drive(direction: String, grab := false, inverted := false) -> void:
	super._drive(direction, grab, inverted)
	if _mirrored(): direction = "move_left" if direction == "move_right" else "move_right"
	Input.action_press(direction, stick)
	if not checked_strengths.has(stick):
		_check(is_equal_approx(absf(Input.get_axis("move_left", "move_right")), stick), "The actual horizontal input axis equals the reported strength")
		checked_strengths[stick] = true


func _cross_ceiling_pit(edge_x: int, end_x: int) -> void:
	if stick == 1.0 or course_model != 4:
		await super._cross_ceiling_pit(edge_x, end_x)
		return
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() >= edge_x, 200, "Reach the late takeoff against the headwind")
	await _jump()
	await _step(16)
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() > end_x, 150, "A horizontal Dash assists the weaker ceiling crossing")


func _cross_floating_spring() -> void:
	if stick == 1.0:
		await super._cross_floating_spring()
		return
	_drive("move_right")
	await _until(func(): return _x() >= 930, 200, "Reach the later Spring takeoff with weaker horizontal input")
	await _jump()
	await _step(20)
	_release_inputs()
	Input.action_press("move_down")
	Input.action_press("dash")
	await _step()
	_release_inputs()
	await _until(func(): return actions.has("exit_spring"), 180, "The weaker inverted descent still fires the actual Spring")
	_drive("move_right")
	await _until(func(): return player.gravity_direction == 1, 120, "The Spring reaches the actual Down gate")


func _part_course() -> void:
	if course_model != 1 or stick == 1.0:
		await super._part_course()
		return
	await _room_two_wall_course()
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() > 940.0 - 360.0 * stick * 0.95, 120, "Reach the weaker-input underside takeoff")
	await _jump()
	await _until(func(): return actions.has("bumper"), 180, "An ordinary inverted jump enters the real bumper with weaker input")
	await _kick_gate(1060, 1, "", true)


func _branch_launch(index: int) -> void:
	_set_part(index, 0)
	if index == 9:
		await _kick_gate(240, -1)
		await _cross_ceiling_pit(330, 470)
		_drive("move_right")
		await _until(func(): return _x() >= 575 and player.is_on_floor(), 100, "Reach the upper branch's actual quiet takeoff")
		_release_inputs()
		await _step(20)
	else:
		await _room_two_wall_course()
	var rest: Vector2 = player.position
	await _step(180)
	_check(player.position.distance_to(rest) < 2 and player.is_on_floor(), "The scroll takeoff allows an input-free three-second break")
	await _capture("room_%d_scroll_takeoff" % (index + 1))


func _pickup() -> void:
	await _jump()
	await _step(12)
	Input.action_press("move_down")
	Input.action_press("dash")
	await _step()
	_release_inputs()
	var scroll: Area2D = stage.rooms.get_child(stage.room_index).get_node("DetourScroll")
	await _until(func(): return is_instance_valid(scroll._follower), 90, "A real inverted descent collects the optional scroll")


func _scroll_branch(index: int) -> void:
	var id := "upper_current_03" if index == 9 else "left_depth_04"
	var before: int = progress.get_count("gravity")
	for attempt in ["retry", "death", "leave", "secure"]:
		await _fresh(index)
		await _branch_launch(index)
		var scroll: Area2D = stage.rooms.get_child(index).get_node("DetourScroll")
		await _pickup()
		await _capture("room_%d_scroll_descent" % (index + 1))
		if attempt == "leave":
			stage.get_node("PauseMenu").return_to_select()
			await _step(4)
			_check(progress.get_count("gravity") == before and not progress.has_scroll("gravity", id), "Leaving before a safe landing discards the pending scroll")
			progress.load_progress()
			_check(not progress.has_scroll("gravity", id), "Reloading cannot recover an unconfirmed pickup")
			continue
		if attempt == "retry":
			await _retry()
		elif attempt == "death":
			_drive("move_right" if index == 9 else "move_left")
			await _until(func(): return respawns > 0, 200, "Leaving the branch before landing hits the real pit or spikes")
			_release_inputs()
			await _step(4)
		else:
			await _until(func(): return progress.has_scroll("gravity", id), 130, "A safe return to the same underside confirms the optional scroll")
			_check(respawns == 0 and player.is_on_floor() and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "The optional round trip ends safely with resources restored")
			await _capture("room_%d_scroll_return" % (index + 1))
			await _retry()
			_check(progress.get_count("gravity") == before + 1, "R preserves a confirmed scroll")
			_drive("move_right", true)
			await _until(func(): return respawns > 0, 600, "A real retry-route pit death preserves the secured collection")
			_release_inputs()
			_check(progress.has_scroll("gravity", id), "Actual death after confirmation preserves the scroll")
		if attempt != "secure":
			_check(progress.get_count("gravity") == before and scroll.global_position == scroll._origin, "R or actual death before safe landing restores the unconfirmed scroll")
		if failed: return
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	_check(current_scene.get_node("Margin/Content/Stages/Stage3/Content/Collection/Count").text == "%d / 4" % (before + 1), "Selection displays the persisted native total")
	_check(current_scene.get_node("Margin/Content/Stages/Stage3").is_visible_in_tree(), "The stage remains accessible before completion")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.has_scroll("gravity", id), "Leaving an unfinished stage and reloading preserves the confirmed branch")


func _weak_scroll_branches() -> void:
	stick = 0.8
	for index in [9, 13]:
		var id := "upper_current_03" if index == 9 else "left_depth_04"
		if progress._collected.has("gravity"): progress._collected["gravity"].erase(id)
		await _fresh(index)
		await _branch_launch(index)
		await _pickup()
		await _until(func(): return progress.has_scroll("gravity", id), 130, "The optional round trip also confirms with actual horizontal input strength 0.8")
		_check(respawns == 0 and player.is_on_floor() and player.is_dash_ready(), "Both weaker-input branches return safely to their original rests")
		if failed: break
	stick = 1.0


func _recoveries() -> void:
	for index in range(9, 15):
		await _fresh(index)
		_set_part(index, 0)
		_drive("move_right", true)
		await _until(func(): return respawns > 0, 600, "Omitting the transfers hits the actual pit")
		_release_inputs()
		await _step(4)
		_check(stage.room_index == index and player.position.distance_to(stage.rooms.get_child(index).get_node("Spawn").global_position) < 5, "Death returns to the correct new-room checkpoint")
		_check(player.gravity_direction == 1 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "Death restores gravity, Dash and stamina")
		await _check_return_state(index, false)
		if failed: return


func _seam() -> void:
	await _fresh(9)
	await _composite_course(9, 30)
	await _reach_goal()
	_reset_course()
	stage._set_room(8, true)
	stage._on_arrival(8)
	stage._set_room(9, false)
	player.respawn()
	await _step(2)
	Input.action_press("move_left")
	await _until(func(): return stage.room_index == 8, 90, "Old ninth and new tenth rooms allow real leftward backtracking")
	_release_inputs()
	await _step(25)
	_check(player.position.distance_to(stage.rooms.get_child(8).get_node("Return").global_position) < 12, "The old final room retains its safe return entrance")
	Input.action_press("move_right")
	await _until(func(): return stage.room_index == 9, 90, "The former final-room boundary opens forward again")
	_release_inputs()
	await _step(25)
	_check(stage.cleared.has(9) and not stage.completed, "The former final room and new tenth remain intermediate after both transfers")
	for index in [10, 13]:
		await _fresh(index)
		await _composite_course(index, 30)
		await _reach_goal()
		_reset_course()
		await _return_more_to_exit()
		stage._set_room(index - 1, true)
		stage._on_arrival(index - 1)
		stage._set_room(index, false)
		player.respawn()
		await _step(2)
		await _check_return_state(index, true)
		Input.action_press("move_left")
		Input.action_press("wall_grab")
		Input.action_press("move_up")
		for frame in 850:
			if stage.room_index == index - 1 or failed: break
			if player.is_on_wall() and player.is_on_floor(): await _jump()
			await _step()
		_check(stage.room_index == index - 1, "Walk the opened lane and pass the real arrival pedestal into the preceding room")
		_release_inputs()
		await _step(25)
		Input.action_press("move_right")
		await _until(func(): return stage.room_index == index, 90, "Walk back into the left-facing room from the prior checkpoint")
		_release_inputs()
		await _step(25)
		await _check_return_state(index, true)
		await _retry()
		await _check_return_state(index, true)
		_check(stage.cleared.has(index), "Returning from the prior room and R retain the opened physical return lane")


func _post_arrival_branches() -> void:
	for index in [6, 13]:
		var id := "inverted_return_02" if index == 6 else "left_depth_04"
		if progress._collected.has("gravity"): progress._collected["gravity"].erase(id)
		await _fresh(index)
		if index == 6:
			stage.rooms.get_child(index).get_node("CeilingBumper").launched.connect(func(_body): actions["bumper"] = actions.get("bumper", 0) + 1)
			await _room_seven_course()
		else:
			await _composite_course(index, 30)
		await _reach_goal()
		_reset_course()
		var offset := 0.0 if index == 6 else 1280.0
		Input.action_press("move_right")
		await _until(func(): return player.position.x - stage.rooms.get_child(index).global_position.x >= offset + 500, 450, "Walk the opened main bridge toward its optional alcove")
		_release_inputs()
		await _step(20)
		# Slow down before the opening so braking finishes on the lower rest, not a step.
		Input.action_press("move_right", 0.4)
		await _until(func(): return player.position.x - stage.rooms.get_child(index).global_position.x >= offset + 600, 450, "After actual arrival, walk into the scroll alcove instead of jumping over it")
		_release_inputs()
		await _until(func(): return progress.has_scroll("gravity", id), 150, "The scroll remains physically reachable and confirms on its permanent lower rest after arrival")
		_check(player.is_on_floor() and player.position.y > 730 and player.gravity_direction == 1 and respawns == 0, "The open lower branch is a safe normal-gravity rest below both steps")
		await _capture("room_%d_scroll_after_arrival" % (index + 1))
		Input.action_press("move_right")
		await _jump()
		await _until(func(): return player.is_on_floor() and player.position.y > 650 and player.position.y < 700, 100, "An ordinary jump climbs from the lower rest to its intermediate step")
		_release_inputs()
		await _step(15)
		Input.action_press("move_right")
		await _jump()
		await _until(func(): return player.is_on_floor() and player.position.y < 630 and player.position.x - stage.rooms.get_child(index).global_position.x > offset + 690, 120, "A second ordinary jump returns to the original main bridge")
		_release_inputs()
		_check(respawns == 0 and stage.cleared.has(index) and progress.has_scroll("gravity", id), "The post-arrival collection returns to the main route without resetting progress")
		await _retry()
		_check(stage.cleared.has(index) and progress.has_scroll("gravity", id), "R keeps both the opened return and post-arrival collection")
		if failed: return


func _approach_part(index: int, part: int) -> void:
	await _fresh(index)
	_set_part(index, 0)
	if part == 1:
		await _part_course()
		_drive("move_right")
		await _until(func(): return _x() >= 1140 and player.is_on_floor() and player.gravity_direction == 1, 220, "Reach the real first-challenge rest before a second-challenge probe")
		_release_inputs()
		await _step(30)
		_drive("move_right")
		await _until(func(): return _x() > 1352, 100, "Walk into the second probe from the real rest")
		_release_inputs()
		_set_part(index, 1)
	actions.clear()
	flips.clear()
	respawns = 0


func _directions() -> Array[Vector2]:
	return [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]


func _direction(direction: Vector2) -> void:
	_release_inputs()
	if direction.x != 0:
		var right := direction.x > 0
		if _mirrored(): right = not right
		Input.action_press("move_right" if right else "move_left")
	if direction.y != 0: Input.action_press("move_down" if direction.y > 0 else "move_up")


func _mandatory_used() -> bool:
	var kicks: int = actions.get("wall_jump", 0)
	match course_model:
		0: return actions.has("launch_spring") and actions.has("return_spring") and kicks >= 2
		1: return actions.has("bumper") and kicks >= 3
		2: return actions.get("air_jump", 0) >= 1 and flips.size() >= 2
		3, 8: return flips.size() >= 4 and kicks >= 4
		4: return actions.has("exit_spring") and flips.size() >= 2
		5: return actions.has("spring") and flips.size() >= 4 and kicks >= 5
		7: return actions.get("air_jump", 0) >= 2 and flips.size() >= 2
	return false


func _negative_routes(indices: Array = [9, 10, 11, 12, 13, 14]) -> void:
	if 13 in indices:
		# The deeper lower alcove must not reopen the old underside refill route.
		await _approach_part(13, 0)
		_drive("move_right")
		await _until(func(): return player.is_on_floor() and player.gravity_direction == -1 and _x() > 430, 260, "Reach the real inverted outer-ceiling launch")
		await _jump()
		await _until(func(): return _x() > 515, 60, "Jump beyond the old step before probing its underside")
		_release_inputs()
		Input.action_press("move_down")
		Input.action_press("dash")
		await _step()
		_release_inputs()
		await _until(func(): return not player.is_dashing() and player.position.y > 300, 40, "A real downward Dash passes below the step")
		_drive("move_left", true, true)
		await _until(func(): return player.is_wall_grabbing() and _x() < 470, 80, "Catch the actual outer wall below its step")
		await _until(func(): return respawns > 0, 220, "The extended native wall cannot be mantled below the room")
		_check(respawns == 1 and not stage.cleared.has(13), "The lower refill bypass returns safely without reaching the exit")
		negatives += 1
		if failed: return
	# Finite real-input roof, floor and wall attempts; no mechanic is disabled.
	for index in indices:
		for part in 2:
			for direction in _directions():
				await _approach_part(index, part)
				_drive("move_right", true)
				await _step(32)
				await _jump()
				await _step(20)
				_direction(direction)
				Input.action_press("dash")
				await _step()
				Input.action_release("dash")
				_drive("move_right", true)
				var reached := false
				for frame in 300:
					await _step()
					reached = _x() > 1100 and player.is_on_floor() and player.gravity_direction == 1 and player.position.y > 500
					if respawns > 0 or reached or stage.cleared.has(index): break
					if frame % 24 == 0 and player.is_on_wall(): await _jump()
				_check(not reached or _mandatory_used(), "Eight-direction Dash, wall climbs and outer roofs cannot replace a challenge's actual mechanics")
				negatives += 1
				if failed: return
			print("GRAVITY_MORE_ENTRANCE_PROBES room=%d part=%d trials=%d" % [index + 1, part + 1, negatives])
	# New upper chambers still require both independent crystal jumps.
	for index in [9, 12]:
		if index not in indices: continue
		for extras in [0, 1]:
			for direction in _directions():
				await _approach_part(index, 0 if index == 9 else 1)
				await _kick_gate(240, -1)
				await _cross_ceiling_pit(330, 470)
				_drive("move_right")
				await _until(func(): return player.is_on_floor() and _x() >= 760, 180, "Reach the upper takeoff by its real entrance route")
				_release_inputs()
				await _step(20)
				for jump in extras + 1:
					await _jump()
					await _step(20)
				_direction(direction)
				Input.action_press("dash")
				await _step()
				Input.action_release("dash")
				_drive("move_right", true)
				var reached := false
				for frame in 200:
					await _step()
					reached = _x() > 900 and player.is_on_floor() and player.gravity_direction == 1 and player.position.y > 550
					if respawns > 0 or reached or stage.cleared.has(index): break
				_check(not reached and not stage.cleared.has(index) and actions.get("air_jump", 0) < 2, "No sampled roof, underside or diagonal Dash replaces either required extra jump")
				negatives += 1
				if failed: return



func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots") or captured.has(label) or label not in CAPTURES: return
	captured[label] = true
	await _step(2)
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/gravity-more")
	root.get_texture().get_image().save_png("res://docs/screenshots/gravity-more/%s.png" % label)


func _check(condition: bool, message: String) -> void:
	super._check(condition, message)
	if failed:
		_release_inputs()
		quit(1)
