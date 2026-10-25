extends "res://tests/tutorial_scroll_route_test.gd"

var strength := 1.0
var lift_x := 90.0
var turn_y := -410.0
var capture_route := false


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	var shared := OS.get_environment("TUTORIAL_ADVANCED_FIXTURE")
	progress.save_path = shared if not shared.is_empty() else "user://tutorial_advanced_%d.cfg" % OS.get_process_id()
	if OS.get_cmdline_user_args().has("--reload"):
		progress._collected.clear()
		progress.load_progress()
		_check(progress.get_count("tutorial") == 4, "A fresh Godot process reads all four saved tutorial scrolls")
		await _selection(4)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		print("TUTORIAL_ADVANCED_RESTART_TEST_OK (%d checks)" % checks)
		quit()
		return
	_clear_progress()
	await _new_tutorial()
	var placed := {}
	var scroll_total := 0
	for area in tutorial.find_children("*", "Area2D", true, false):
		if area.get_script() != null and area.get_script().resource_path == "res://scripts/scroll_collectible.gd":
			placed[area.scroll_id] = true
			scroll_total += 1
	_check(scroll_total == 8 and placed.size() == 8 and progress.TOTALS.tutorial == 8, "The eight unique native placements match the selection total")
	_check(tutorial.rooms.get_child_count() == 17 and tutorial.MAIN_ROOM_COUNT == 16, "The two new detours preserve sixteen main and one optional room")
	await _normal_main_routes()
	if not OS.get_cmdline_user_args().has("--routes-only"):
		for index in [3, 13]:
			await _pending_and_saved(index)
			await _without_required_action(index)
	for index in [3, 13]:
		for axis in [1.0, 0.8]:
			for takeoff in ([90.0] if index == 3 else [70.0, 90.0, 110.0]):
				for turn in ([-410.0] if index == 3 else [-380.0, -410.0, -440.0]):
					if OS.get_cmdline_user_args().has("--screenshots") and (axis != 1 or takeoff != 90 or turn != -410): continue
					_clear_progress()
					await _new_tutorial()
					await _enter(index)
					strength = axis
					lift_x = takeoff
					turn_y = turn
					capture_route = axis == 1.0 and takeoff == 90 and turn == -410
					var started := Engine.get_physics_frames()
					await _branch_touch(index)
					_check(_scroll()._follower == player and not progress.has_scroll("tutorial", _id(index)), "The branch's real touch precedes confirmation")
					await _return(index)
					var seconds := (Engine.get_physics_frames()-started)/60.0
					_check(seconds < 30, "Each optional round trip including three seconds of rest stays below thirty seconds")
					print("ADVANCED_BRANCH_%d axis=%.1f takeoff=%d turn=%d %.2fs" % [index+1, axis, takeoff, turn, seconds])
	strength = 1.0
	lift_x = 90
	turn_y = -410
	capture_route = false
	_clear_progress()
	await _new_tutorial()
	for index in [3, 13]:
		await _enter(index)
		await _branch_touch(index)
		await _return(index)
	await _enter(0)
	await _jump_branch()
	await _until(func(): return progress.has_scroll("tutorial", "jump_turn_01"), 60, "The original jump detour still saves its actual scroll")
	await _enter(1)
	await _wall_branch()
	await _until(func(): return progress.has_scroll("tutorial", "wall_loft_01"), 60, "The original wall detour still saves its actual scroll")
	_check(progress.get_count("tutorial") == 4, "All four real input routes secure separate tutorial scrolls")
	tutorial.get_node("PauseMenu").return_to_select()
	await _step(5)
	await _selection(4)
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("tutorial") == 4, "An unfinished tutorial retains all four scrolls when loaded again")
	if not OS.get_cmdline_user_args().has("--keep-save"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	_release()
	print("TUTORIAL_ADVANCED_SCROLL_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _clear_progress() -> void:
	progress._collected.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))


func _selection(count: int) -> void:
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(5)
	var card := current_scene.get_node("Margin/Content/Stages/Stage1") as Button
	_check(card.get_node("Content/Collection/Count").text == "%d / 8" % count, "Selection shows the collected tutorial total")
	_check(card.accessibility_name.contains("巻物 %d / 8" % count), "Selection exposes the same total through its accessible name")


func _normal_main_routes() -> void:
	for index in [3, 13]:
		await _enter(index)
		if index == 13:
			await _move_to(110)
			Input.action_press("wall_grab")
			await _step(3)
			await _held_move(220)
			Input.action_press("move_right")
			await _pulse("jump")
			await _step(48)
			await _pulse("dash")
		for frame in 600:
			Input.action_release("jump")
			if index == 13: Input.action_press("wall_grab")
			Input.action_press("move_right")
			if player.is_on_floor() and player.is_on_wall(): Input.action_press("jump")
			if tutorial.cleared.has(index): break
			await _step()
		_release()
		_check(tutorial.cleared.has(index) and respawns == 0, "The original mandatory lesson remains traversable without death")
		_check(progress.get_count("tutorial") == 0, "The original main route leaves all optional scrolls untouched")


func _pending_and_saved(index: int) -> void:
	_clear_progress()
	await _new_tutorial()
	for mode in ["R", "spike", "leave"]:
		await _enter(index)
		await _branch_touch(index)
		_check(_scroll()._follower == player and not progress.has_scroll("tutorial", _id(index)), "Each cancellation starts with a genuinely pending scroll")
		if mode == "R":
			await _retry()
		elif mode == "spike":
			await _hit_spike(index)
		else:
			tutorial.get_node("PauseMenu").return_to_select()
			await _step(5)
			await _new_tutorial()
		_check(not progress.has_scroll("tutorial", _id(index)), "A pending scroll is not saved after %s" % mode)
	await _enter(index)
	await _branch_touch(index)
	await _rest(index)
	await _hit_spike(index)
	_check(progress.has_scroll("tutorial", _id(index)) and _scroll().modulate.a < 1, "A real spike death retains a confirmed scroll and its faint position")
	await _retry()
	_check(progress.get_count("tutorial") == 1, "R after confirmation does not remove or duplicate the saved scroll")
	tutorial.get_node("PauseMenu").return_to_select()
	await _step(5)
	await _selection(1)
	progress._collected.clear()
	progress.load_progress()
	_check(progress.has_scroll("tutorial", _id(index)), "Returning before lesson completion preserves the confirmed record")


func _hit_spike(index: int) -> void:
	var hits := [0]
	var spike: SpikeBlock = tutorial.rooms.get_child(index).get_node("ScrollDetour/BranchSpikes")
	spike.player_hit.connect(func(): hits[0] += 1, CONNECT_ONE_SHOT)
	var before := respawns
	_release()
	if index == 13: Input.action_press("wall_grab")
	Input.action_press("move_right")
	await _pulse("dash")
	for frame in 40:
		if respawns != before: break
		await _step()
	_release()
	await _step(6)
	_check(hits[0] == 1 and respawns == before+1 and player.gravity_direction == 1 and player.is_on_floor(), "Actual Dash contact with the branch spike restores the original safe entrance once")
	_check(player.position.distance_to(player._spawn_position) < 3 and player.is_dash_ready() and tutorial.camera.position.distance_to(tutorial._camera_position()) < 2, "Spike recovery restores the actual checkpoint, Dash and room camera")
	if index == 13:
		_check(player.get_held_object() == null and tutorial.rooms.get_child(13).get_node("Parachute").position.distance_to(Vector2(170, 223.4)) < 3, "Spike recovery restores the original free umbrella beside the entrance")


func _without_required_action(index: int) -> void:
	_clear_progress()
	await _new_tutorial()
	await _enter(index)
	if index == 3: tutorial.rooms.get_child(3).get_node("GateUp").collision_mask = 0
	var routes := 0
	for launch in ([72, 180, 235, 300] if index == 3 else [60, 90, 110, 170, 225]):
		for delay in [0, 12, 24, 36]:
			for direction in [Vector2.RIGHT, Vector2(1,-1), Vector2.UP, Vector2(-1,-1), Vector2.LEFT, Vector2(-1,1), Vector2.DOWN, Vector2(1,1)]:
				await _enter(index)
				await _move_to(launch)
				var before := respawns
				var scroll := _scroll()
				var reached := false
				var received_mechanic := false
				await _pulse("jump")
				for frame in 180:
					_release()
					Input.action_press("move_left" if _local().x > 300 else "move_right")
					if frame == delay:
						Input.action_release("move_left")
						Input.action_release("move_right")
						if direction.x != 0: Input.action_press("move_left" if direction.x < 0 else "move_right")
						if direction.y != 0: Input.action_press("move_up" if direction.y < 0 else "move_down")
						await _pulse("dash")
					# Holding Grab would acquire the umbrella, so only bare wall approaches use it away from that object.
					if index == 3 or (_local().x > 280 and player.global_position.distance_to(tutorial.rooms.get_child(13).get_node("Parachute").global_position) > 240):
						Input.action_press("wall_grab")
						Input.action_press("move_up")
						if player.is_on_wall() and frame % 12 == 0: await _pulse("jump")
					await _step()
					reached = reached or scroll._follower == player or progress.has_scroll("tutorial", _id(index))
					received_mechanic = received_mechanic or player.gravity_direction != 1 or (index == 13 and player.get_held_object() != null)
					if respawns != before or tutorial.room_index != index: break
				_check(not reached, "Jump, eight-way Dash and attempted wall routes cannot collect without the required mechanic")
				_check(not received_mechanic, "The comparison never received gravity inversion or the umbrella: launch=%s delay=%s direction=%s" % [launch, delay, direction])
				routes += 1
	print("ADVANCED_NO_ACTION_ROOM_%d %d routes" % [index+1, routes])
	if index == 13:
		await _bare_wall_attempts()


func _bare_wall_attempts() -> void:
	for delay in [0, 12, 24]:
		for direction in [Vector2.UP, Vector2(-1,-1), Vector2(1,-1)]:
			await _enter(13)
			await _move_to(225)
			Input.action_press("move_right")
			await _pulse("jump")
			for frame in 100:
				if _local().x > 280: break
				await _step()
			_release()
			for frame in 100:
				if _local().y > 450: break
				await _step()
			Input.action_press("move_left")
			Input.action_press("wall_grab")
			Input.action_press("move_up")
			await _until(func(): return player.is_wall_grabbing(), 50, "The bare bypass starts with an actual entrance-wall hold")
			_check(player.get_held_object() == null and respawns == 0, "The wall approach physically holds the wall without acquiring the umbrella")
			_release()
			Input.action_press("move_right")
			await _pulse("jump")
			await _step(delay)
			_release()
			if direction.x != 0: Input.action_press("move_left" if direction.x < 0 else "move_right")
			Input.action_press("move_up")
			await _pulse("dash")
			var reached := false
			for frame in 180:
				if respawns > 0 or tutorial.room_index != 13: break
				reached = reached or _scroll()._follower == player
				await _step()
			_check(not reached and not progress.has_scroll("tutorial", _id(13)), "An actual wall kick and upward Dash cannot replace the umbrella updraft")
	print("ADVANCED_BARE_WALL_OK (9 actual wall approaches)")


func _new_tutorial() -> void:
	await super._new_tutorial()
	# Stop an attempt at death before a held Grab can acquire the reset umbrella.
	player.respawned.connect(_release)


func _enter(index: int) -> void:
	_release()
	tutorial._set_room(index, false)
	player.respawn()
	await _step(6)
	respawns = 0


func _id(index: int) -> String:
	return "gravity_return_01" if index == 3 else "glide_updraft_01"


func _branch_touch(index: int) -> void:
	if index == 3:
		await _move_to(280)
		await _until(func(): return player.gravity_direction == -1 and player.is_on_floor(), 120, "The existing UpGate reaches the main inverted rest")
		if capture_route: await _advanced_capture("gravity_main_rest")
		for frame in 180:
			_steer(100)
			await _step()
			if _scroll()._follower == player:
				_release()
				return
	else:
		await _move_to(110)
		if capture_route: await _advanced_capture("glide_entry")
		Input.action_press("wall_grab")
		await _step(3)
		_check(player.get_held_object() == tutorial.rooms.get_child(13).get_node("Parachute"), "The detour holds the actual entrance umbrella")
		await _held_move(lift_x)
		await _pulse("jump")
		for frame in 360:
			_held_steer(lift_x)
			await _step()
			if _local().y < turn_y: break
		_check(_local().y < turn_y and not player._winds.is_empty(), "Holding the umbrella actually rises in the branch's updraft")
		if capture_route: await _advanced_capture("glide_ascent")
		for frame in 300:
			_held_steer(200)
			await _step()
			if _scroll()._follower == player:
				return
	_check(false, "The optional route physically touches its scroll")


func _return(index: int) -> void:
	await _rest(index)
	if index == 3:
		await _move_to(195)
		await _until(func(): return player.gravity_direction == 1, 80, "The return DownGate restores ordinary gravity")
		await _move_to(100)
	else:
		await _held_move(300)
		await _until(func(): return _local().y > -170, 150, "The return falls outside the updraft")
		await _held_move(200)
	await _until(func(): return player.is_on_floor() and _local().y > (580 if index == 3 else 220), 300, "The detour returns to the same original entrance floor")
	_check(respawns == 0 and tutorial.room_index == index and not tutorial.cleared.has(index), "The optional return neither dies nor clears its mandatory lesson")
	if index == 13:
		_check(player.get_held_object() == tutorial.rooms.get_child(13).get_node("Parachute"), "The return keeps the umbrella for the main glide lesson")
	if capture_route: await _advanced_capture("gravity_return" if index == 3 else "glide_return")


func _rest(index: int) -> void:
	if index == 3:
		_release()
		await _until(func(): return progress.has_scroll("tutorial", _id(index)), 90, "The inverted observation rest safely confirms the scroll")
	else:
		for frame in 180:
			_held_steer(200)
			await _step()
			if progress.has_scroll("tutorial", _id(index)): break
		_release()
		Input.action_press("wall_grab")
		_check(progress.has_scroll("tutorial", _id(index)), "The wind's upper observation shelf safely confirms the scroll")
	var resting := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(resting) < 2 and player.is_dash_ready(), "The observation place remains safe for three seconds")
	if capture_route: await _advanced_capture("gravity_loft" if index == 3 else "glide_loft")


func _advanced_capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial_advanced_scrolls")
	root.get_texture().get_image().save_png("res://docs/screenshots/tutorial_advanced_scrolls/%s.png" % label)


func _held_steer(target: float) -> void:
	Input.action_press("wall_grab")
	_steer(target)


func _held_move(target: float) -> void:
	for frame in 240:
		_held_steer(target)
		await _step()
		if absf(target-_local().x) < 2 and absf(player.velocity.x) < 10:
			Input.action_release("move_left")
			Input.action_release("move_right")
			return
	_check(false, "Held movement reaches x=%s" % target)


func _steer(target: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	var offset := target-_local().x
	Input.action_press("move_right" if offset > 0 else "move_left", minf(absf(offset)/45.0, strength))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_ADVANCED: %s pos=%s respawns=%d" % [message, _local() if is_instance_valid(tutorial) else Vector2.ZERO, respawns])
		quit(1)
