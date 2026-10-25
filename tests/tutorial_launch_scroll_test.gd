extends "res://tests/tutorial_advanced_scroll_test.gd"

var launch_counts := {6: 0, 7: 0}
var launch_capture := false
var monitor_launch := false


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	var fixture := OS.get_environment("TUTORIAL_LAUNCH_FIXTURE")
	progress.save_path = fixture if not fixture.is_empty() else "user://tutorial_launch_%d.cfg" % OS.get_process_id()
	if OS.get_cmdline_user_args().has("--reload"):
		progress._collected.clear()
		progress.load_progress()
		_check(progress.get_count("tutorial") == 6, "A separate process reads the six actual collected scrolls")
		for id in ["jump_turn_01", "wall_loft_01", "gravity_return_01", "glide_updraft_01", "spring_loft_05", "reflection_loft_06"]:
			_check(progress.has_scroll("tutorial", id), "A separate process preserves the original identity: "+id)
		await _selection(6)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		print("TUTORIAL_LAUNCH_RELOAD_TEST_OK (%d checks)" % checks)
		quit(1 if failed else 0)
		return
	_clear_progress()
	await _new_tutorial()
	var ids := {}
	var placements := 0
	for area in tutorial.find_children("*", "Area2D", true, false):
		if area.get_script() != null and area.get_script().resource_path == "res://scripts/scroll_collectible.gd":
			placements += 1
			ids[area.scroll_id] = true
	_check(placements == 6 and ids.size() == 6 and progress.TOTALS.tutorial == 6, "The six unique native placements match the actual selection total")
	_check(tutorial.rooms.get_child_count() == 17 and tutorial.MAIN_ROOM_COUNT == 16, "The main sixteen and optional seventeenth lesson remain unchanged")
	if OS.get_cmdline_user_args().has("--lifecycle-only"):
		await _launch_lifecycle()
		_clear_progress()
		print("TUTORIAL_LAUNCH_LIFECYCLE_TEST_OK (%d checks)" % checks)
		quit(1 if failed else 0)
		return
	for index in [6, 7]:
		for axis in [1.0, 0.8]:
			for gap in [16, 20, 24]:
				if OS.get_cmdline_user_args().has("--screenshots") and (axis != 1 or gap != 20): continue
				_clear_progress()
				await _new_tutorial()
				await _enter(index)
				strength = axis
				launch_capture = axis == 1 and gap == 20
				monitor_launch = true
				var start := Engine.get_physics_frames()
				await _launch_touch(index, gap)
				await _launch_rest(index)
				await _launch_return(index)
				var seconds := (Engine.get_physics_frames()-start)/60.0
				_check(seconds < 30, "The optional round trip including three seconds of rest stays below thirty seconds")
				print("LAUNCH_BRANCH room=%d axis=%.1f gap=%d %.2fs" % [index+1, axis, gap, seconds])
				await _launch_main_goal(index)
				if launch_capture: await _launch_shot("goal")
				monitor_launch = false
				await _launch_seam(index)
	if OS.get_cmdline_user_args().has("--screenshots"):
		for index in [6, 7]:
			_clear_progress()
			await _new_tutorial()
			await _enter(index)
			tutorial.set_hints_visible(true)
			strength = 0.8
			launch_capture = true
			monitor_launch = true
			await _launch_touch(index, 20)
			await _launch_rest(index)
			await _launch_return(index)
			await _launch_main_goal(index)
			await _launch_shot("goal")
			monitor_launch = false
			await _launch_seam(index)
		await _launch_left_return()
	elif not OS.get_cmdline_user_args().has("--routes-only"):
		await _launch_normal_routes()
		await _launch_lifecycle()
		await _all_six()
	_release()
	if OS.get_cmdline_user_args().has("--keep-save"):
		print("TUTORIAL_LAUNCH_SAVED_PATH="+progress.save_path)
	else:
		_clear_progress()
	print("TUTORIAL_LAUNCH_SCROLL_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _new_tutorial() -> void:
	await super._new_tutorial()
	for index in [6, 7]:
		tutorial.rooms.get_child(index).get_node("FloorSpring" if index == 6 else "Pinball").launched.connect(func(_body): launch_counts[index] += 1)


func _enter(index: int) -> void:
	if tutorial.transitioning:
		_release()
		await _until(func(): return not tutorial.transitioning, 60, "A prior real room transfer completes before the next explicit checkpoint fixture")
	tutorial.cleared[index-1] = true
	tutorial.cleared.erase(index)
	await super._enter(index)
	launch_counts[index] = 0
	if index in [6, 7]:
		var barrier: CollisionShape2D = tutorial.rooms.get_child(index).get_node("ExitBarrier/Collision")
		var barrier_top := barrier.global_position.y+barrier.shape.get_rect().position.y
		_check(not barrier.disabled and barrier_top < tutorial._room_top(tutorial.rooms.get_child(index))-52-player.get_node("CollisionShape2D").shape.get_rect().size.y/2, "The closed barrier extends beyond the full body's permitted upper bound")


func _launch_id(index: int) -> String:
	return "spring_loft_05" if index == 6 else "reflection_loft_06"


func _floor_named(path: String) -> bool:
	if not player.is_on_floor(): return false
	for collision in player.get_slide_collision_count():
		if player.get_slide_collision(collision).get_collider() == tutorial.rooms.get_child(tutorial.room_index).get_node(path): return true
	return false


func _launch_touch(index: int, gap: int) -> void:
	_release()
	if launch_capture: await _launch_shot("entry")
	Input.action_press("move_right", strength)
	_check(is_equal_approx(Input.get_axis("move_left", "move_right"), strength), "The real direction action has the requested analog strength")
	await _until(func(): return launch_counts[index] > 0, 240, "The branch begins with the actual Spring or bumper launch")
	await _step(gap)
	if launch_capture: await _launch_shot("turn")
	_release()
	Input.action_press("move_up")
	await _pulse("dash")
	_check(player.is_dashing(), "The upward branch uses the player's real Dash")
	_release()
	for frame in 240:
		_steer(950 if index == 6 else 140)
		await _step()
		if _floor_named("ScrollDetour/Loft"): break
	_check(_floor_named("ScrollDetour/Loft") and respawns == 0, "The real launch and upward Dash land on the native optional loft")
	await _move_to(950 if index == 6 else 140)
	_release()
	await _pulse("jump")
	if index == 6:
		await _step(16)
		Input.action_press("move_up")
		await _pulse("dash")
		_release()
	await _until(func(): return _scroll()._follower == player, 30, "A real jump from the loft touches its scroll")
	_check(not progress.has_scroll("tutorial", _launch_id(index)), "Actual scroll contact remains pending in the air")
	if launch_capture: await _launch_shot("pending")


func _launch_rest(index: int) -> void:
	_release()
	await _until(func(): return progress.has_scroll("tutorial", _launch_id(index)), 120, "Safe landing on the native loft confirms the pending scroll")
	var position_before := player.position
	await _step(180)
	_check(_floor_named("ScrollDetour/Loft") and player.position.distance_to(position_before) < 2 and player.is_dash_ready(), "The loft allows a genuine three-second rest with a ready Dash")
	if launch_capture: await _launch_shot("rest")


func _launch_return(index: int, left_return: bool = false) -> void:
	await _move_to(1080 if index == 6 else (72 if left_return else 800))
	await _until(func(): return player.is_on_floor() and _local().y > (480 if index == 6 else (470 if left_return else 270)), 180, "Walking off the loft returns to an original safe floor")
	_check(respawns == 0 and tutorial.room_index == index, "The branch returns naturally inside the same lesson without dying")
	if launch_capture: await _launch_shot("return")
	if index == 7:
		_check(_floor_named("EntryFloor" if left_return else "Landing") and not tutorial.cleared.has(index), "The upper branch physically returns to its original entrance or main landing before Goal arrival")


func _launch_lifecycle() -> void:
	launch_capture = false
	strength = 1
	await _launch_left_return()
	for index in [6, 7]:
		for cancellation in ["R", "void", "leave"]:
			_clear_progress()
			await _new_tutorial()
			await _enter(index)
			await _launch_touch(index, 20)
			_check(_scroll()._follower == player and not progress.has_scroll("tutorial", _launch_id(index)), "Cancellation begins with a genuinely pending scroll")
			if cancellation == "R":
				await _retry()
			elif cancellation == "void":
				await _launch_void(index, true)
			else:
				tutorial.get_node("PauseMenu").return_to_select()
				await _step(5)
				await _new_tutorial()
				await _enter(index)
			_check(not progress.has_scroll("tutorial", _launch_id(index)) and _scroll()._follower == null and not _scroll()._secured, "Pending %s cancellation does not save or hide the original scroll" % cancellation)
		_clear_progress()
		await _new_tutorial()
		await _enter(index)
		await _launch_touch(index, 20)
		await _launch_rest(index)
		await _launch_void(index, false)
		_check(progress.has_scroll("tutorial", _launch_id(index)) and _scroll().modulate.a < 1, "A real void death preserves the confirmed scroll and its faint native position")
		await _retry()
		_check(progress.get_count("tutorial") == 1, "R preserves the confirmed record without duplicating it")
		await _selection(1)
		progress._collected.clear()
		progress.load_progress()
		_check(progress.has_scroll("tutorial", _launch_id(index)), "Leaving before tutorial completion keeps the confirmed record on disk")
		await _new_tutorial()
		await _enter(index)
		await _launch_main_goal(index)
		_check(progress.get_count("tutorial") == 1, "Actual main Goal arrival preserves the separately confirmed optional scroll")
		await _launch_seam(index)


func _launch_left_return() -> void:
	_clear_progress()
	await _new_tutorial()
	await _enter(7)
	strength = 1
	launch_capture = false
	await _launch_touch(7, 20)
	await _launch_rest(7)
	await _launch_return(7, true)
	_check(_floor_named("EntryFloor") and not tutorial.cleared.has(7) and respawns == 0, "The optional left exit also returns physically to the original entrance without clearing the room")
	await _launch_shot("left_return")


func _launch_normal_routes() -> void:
	launch_capture = false
	for index in [6, 7]:
		for axis in [1.0, 0.8]:
			_clear_progress()
			await _new_tutorial()
			await _enter(index)
			strength = axis
			monitor_launch = true
			await _launch_main_goal(index)
			monitor_launch = false
			_check(launch_counts[index] == 1 and progress.get_count("tutorial") == 0 and _scroll()._follower == null, "The original rightward main route uses its actual launch and leaves the optional scroll untouched")


func _launch_void(index: int, pending: bool) -> void:
	var before := respawns
	var reached_void := false
	for frame in 360:
		if respawns != before: break
		_steer(700)
		if pending and index == 7 and player.is_on_floor() and _local().x < 660:
			await _pulse("jump")
			_check(not progress.has_scroll("tutorial", _launch_id(index)), "Immediate real takeoff keeps the carried scroll pending across the upper shelf")
		reached_void = reached_void or _local().y > 735
		await _step()
	_release()
	await _step(6)
	_check(reached_void and respawns == before+1, "Real movement into the original open gap causes exactly one actual void death")
	_check(player.position.distance_to(player._spawn_position) < 3 and player.is_on_floor() and player.is_dash_ready() and player.controls_enabled, "The real death restores the native entrance, resources and input")


func _launch_main_goal(index: int) -> void:
	_release()
	for frame in 600:
		if tutorial.cleared.has(index): break
		Input.action_release("move_right")
		if _local().x < tutorial.rooms.get_child(index).get_node("Goal").position.x-55:
			Input.action_press("move_right", strength)
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall(): Input.action_press("jump")
		await _step()
	_release()
	_check(tutorial.cleared.has(index) and tutorial.rooms.get_child(index).get_node("Goal").is_pressed() and respawns == 0, "The unchanged main terrain still opens its real Goal without action-history requirements")


func _launch_seam(index: int) -> void:
	Input.action_press("move_right")
	await _until(func(): return tutorial.room_index == index+1 and not tutorial.transitioning, 200, "The actual cleared right edge enters the following old room")
	_release()
	_check(player.controls_enabled and player.is_dash_ready(), "The old forward connection restores control and Dash")
	Input.action_press("move_left")
	await _until(func(): return tutorial.room_index == index and not tutorial.transitioning, 160, "The following old room physically returns across the left edge")
	_release()
	await _retry()
	_check(progress.has_scroll("tutorial", _launch_id(index)) and player.position.distance_to(player._spawn_position) < 3, "Backtracking and retry retain the new scroll at the original checkpoint")


func _all_six() -> void:
	_clear_progress()
	await _new_tutorial()
	strength = 1
	for index in [6, 7]:
		await _enter(index)
		await _launch_touch(index, 20)
		await _launch_rest(index)
		await _launch_return(index)
	for index in [3, 13]:
		await _enter(index)
		await _branch_touch(index)
		await _return(index)
	await _enter(0)
	await _jump_branch()
	await _until(func(): return progress.has_scroll("tutorial", "jump_turn_01"), 60, "The original jump branch still confirms its actual scroll")
	await _enter(1)
	await _wall_branch()
	await _until(func(): return progress.has_scroll("tutorial", "wall_loft_01"), 60, "The original wall branch still confirms its actual scroll")
	_check(progress.get_count("tutorial") == 6, "All six actual input routes save six distinct original and new IDs")
	await _selection(6)
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("tutorial") == 6, "The saved six-scroll collection reloads before tutorial completion")


func _step(count: int = 1) -> void:
	for frame in count:
		await super._step()
		if not monitor_launch or not is_instance_valid(tutorial) or not player.controls_enabled or tutorial.transitioning: continue
		var shape: CollisionShape2D = player.get_node("CollisionShape2D")
		var body := Rect2(shape.get_global_transform_with_canvas()*shape.shape.get_rect().position, shape.shape.get_rect().size)
		_check(root.get_visible_rect().encloses(body), "The full native player stays inside the scrolling viewport")
		for path in ["HUD/Margin/Panel", "HUD/PauseButton"]:
			var panel: Control = tutorial.get_node(path)
			_check(not panel.is_visible_in_tree() or not panel.get_global_rect().intersects(body), "The full native player stays outside visible tutorial HUD: "+path)


func _launch_shot(phase: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await process_frame
	RenderingServer.force_draw()
	if phase in ["turn", "pending", "rest"]:
		var collision: CollisionShape2D = tutorial.rooms.get_child(tutorial.room_index).get_node("ScrollDetour/Loft/Collision")
		var surface := Rect2(collision.get_global_transform_with_canvas()*collision.shape.get_rect().position, collision.shape.get_rect().size)
		_check(root.get_visible_rect().encloses(surface), "The actual next optional rest surface is fully visible during the branch")
	if phase == "rest":
		var collision: CollisionShape2D = tutorial.rooms.get_child(tutorial.room_index).get_node("SpringLanding/Collision" if tutorial.room_index == 6 else "Landing/Collision")
		var surface := Rect2(collision.get_global_transform_with_canvas()*collision.shape.get_rect().position, Vector2(collision.shape.get_rect().size.x, 24))
		_check(root.get_visible_rect().encloses(surface), "The original return landing's full top surface is visible from the safe upper rest")
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial_launch_scrolls")
	root.get_texture().get_image().save_png("res://docs/screenshots/tutorial_launch_scrolls/room_%d_%s%s.png" % [tutorial.room_index+1, phase, "_hints" if tutorial.hints_visible else ""])
