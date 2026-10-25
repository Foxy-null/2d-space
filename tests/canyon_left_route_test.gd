extends "res://tests/canyon_expansion_route_test.gd"


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	for strength in [1.0, 0.8]:
		for index in [15, 16, 17]:
			await _setup(index)
			var started := Engine.get_physics_frames()
			var saw_vertical_camera := false
			for frame in 1800:
				if stage.transitioning or stage.completed or respawns > 0: break
				_steer(strength)
				await _step()
				if not stage.transitioning and stage.room_index == index:
					if index == 16 and player.position.y < 900 and stage.camera.position.y < 1000: saw_vertical_camera = true
					if index == 17 and player.position.y > 800 and stage.camera.position.y > 700: saw_vertical_camera = true
			_release_inputs()
			var seconds := float(Engine.get_physics_frames() - started) / 60
			print("CANYON_LEFT_ROOM_%d strength=%.1f %.2fs position=%s bumper=%d" % [index + 1, strength, seconds, player.position - Vector2(index * 1280, 0), stage.next_bumper])
			_check((stage.room_index == index + 1 and stage.transitioning and respawns == 1) if index < stage.rooms.get_child_count() - 1 else (stage.completed and respawns == 0), "New rooms are reached by actual reflection inputs without a death")
			_check(seconds < 30, "A retry never repeats more than thirty seconds of successful traversal")
			_check(index == 15 or saw_vertical_camera, "The vertical camera reveals the actual upper or lower course")
			_check(progress.get_count("canyon") == 0, "The main course leaves its optional scrolls untouched")
			if failed: return
	for delay in [16, 24]:
		await _middle_rest(delay)
		if failed: return
	for strength in [1.0, 0.8]:
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for index in [15, 17]:
			await _scroll_branch(index, strength)
			if failed: return
	if not OS.get_cmdline_user_args().has("--screenshots"):
		await _rest_bypasses()
		if failed: return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_LEFT_ROUTE_TEST_OK (%d checks)" % checks)
	quit()


func _scroll_branch(index: int, strength: float) -> void:
	var scroll_id := "left_sky_02" if index == 15 else "deep_return_03"
	var before_count: int = progress.get_count("canyon")
	await _setup(index)
	if strength == 1.0:
		for interruption in ["retry", "death", "leave"]:
			await _take_branch(strength)
			_check(_scroll()._follower == player and not progress.has_scroll("canyon", scroll_id), "A real airborne pickup waits for a safe landing")
			if interruption == "retry":
				await _pulse("reset")
				await _step(6)
				_check(_scroll()._follower == null and _scroll().global_position == _scroll()._origin, "R restores the pending scroll")
			elif interruption == "death":
				await _fall_from_branch()
				_check(_scroll()._follower == null, "A real fall cancels the pending scroll")
			else:
				stage.get_node("PauseMenu").return_to_select()
				await _step(4)
			_check(progress.get_count("canyon") == before_count, "Interrupted pickups preserve only previously confirmed scrolls")
			await _setup(index)
	var started := Engine.get_physics_frames()
	await _take_branch(strength)
	await _capture("room%d_scroll" % (index + 1))
	await _land_at_rest(strength)
	var seconds := float(Engine.get_physics_frames() - started) / 60
	_check(progress.has_scroll("canyon", scroll_id) and respawns == 0 and player.is_on_floor(), "The collection route returns to its real safe rest")
	_check(seconds < 30, "The collection trip keeps a short retry interval")
	var stopped := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped) < 2 and respawns == 0, "The observation rest is safe for three seconds without input")
	await _capture("room%d_rest" % (index + 1))
	await _pulse("jump")
	for frame in 1200:
		if stage.transitioning or stage.completed or respawns > 0: break
		_steer(strength)
		await _step()
	_release_inputs()
	_check((stage.transitioning and respawns == 1) if index < stage.rooms.get_child_count() - 1 else (stage.completed and respawns == 0), "A normal jump and the remaining reflections rejoin the main route after resting")
	if failed:
		print("REJOIN_FAILED room=", index + 1, " position=", Vector2(_x(), player.position.y), " next=", stage.next_bumper, " respawns=", respawns)
		return
	print("CANYON_LEFT_SCROLL_%d strength=%.1f %.2fs" % [index + 1, strength, seconds])
	await _setup(index)
	_check(_scroll().modulate.a < 1, "A confirmed scroll remains a faint revisit marker")
	await _pulse("reset")
	await _step(6)
	_check(progress.has_scroll("canyon", scroll_id), "R preserves the confirmed scroll")
	await _fall_from_branch()
	_check(progress.has_scroll("canyon", scroll_id) and stage.room_index == index and player.is_dash_ready(), "A confirmed scroll survives a real death and the room restores its own checkpoint")
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	var expected := "%d / 11" % (before_count + 1)
	var card := current_scene.get_node("Margin/Content/Stages/Stage5")
	_check(card.get_node("Content/Collection/Count").text == expected and card.accessibility_name.contains("巻物 " + expected), "Selection and its accessible name use the saved count and actual total")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("canyon") == before_count + 1 and progress.has_scroll("canyon", scroll_id), "Saved collection survives leaving the unfinished stage and reloading")


func _middle_rest(dash_delay: int) -> void:
	await _setup(16)
	for frame in 600:
		if stage.next_bumper >= 2 or respawns > 0: break
		_steer(0.8)
		await _step()
	_check(stage.next_bumper == 2 and respawns == 0, "The tall room's middle rest is reached from its actual first two reflections")
	await _land_at_rest(0.8)
	var stopped := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped) < 2 and respawns == 0, "The tall room also permits a safe three-second observation")
	await _capture("room17_rest")
	var bumper: Node2D = stage._bumpers().get_child(1)
	var repeated: Array[bool] = []
	bumper.launched.connect(func(_body): repeated.append(true))
	await _pulse("jump")
	await _step(dash_delay)
	_release_inputs()
	Input.action_press("move_up")
	await _pulse("dash")
	await _step(10)
	for frame in 180:
		if not repeated.is_empty() or respawns > 0: break
		_steer_to(bumper.position - Vector2(0, 62), false, 0.8)
		await _step()
	_check(not repeated.is_empty() and respawns == 0, "Jump and upward Dash reuse the visible second reflection after resting")
	for frame in 1200:
		if stage.transitioning or respawns > 0: break
		_steer(0.8)
		await _step()
	_release_inputs()
	_check(stage.room_index == 17 and stage.transitioning and respawns == 1, "The middle rest rejoins the upper reflections using normal controls")


func _land_at_rest(strength: float = 1.0) -> void:
	var rest: Node2D = stage.rooms.get_child(stage.room_index).get_node("Rest")
	for frame in 600:
		if player.is_on_floor() and absf(_x() - rest.position.x) < 40: break
		_steer_to(rest.position - Vector2(0, 34), false, strength)
		await _step()
	_release_inputs()
	await _step(15)
	_check(player.is_on_floor() and player.position.distance_to(rest.global_position - Vector2(0, 34)) < 40 and respawns == 0, "Normal inputs land at the real intermediate rest")


func _take_branch(strength: float = 1.0) -> void:
	for frame in 600:
		if stage.next_bumper >= 3 or respawns > 0: break
		_steer(strength)
		await _step()
	_check(stage.next_bumper == 3 and respawns == 0, "The optional route begins after three real reflections")
	for frame in 240:
		if _scroll()._follower == player or respawns > 0: break
		_steer_to(_scroll().position, false, strength)
		await _step()
	_release_inputs()
	_check(_scroll()._follower == player and respawns == 0, "Steering away from the main route contacts the optional scroll")


func _fall_from_branch() -> void:
	var before := respawns
	for frame in 240:
		_release_inputs()
		Input.action_press("move_left" if stage.room_index == 15 else "move_right")
		Input.action_press("move_down")
		if player.is_dash_ready(): Input.action_press("dash")
		await _step()
		if respawns > before: break
	_release_inputs()
	await _step(6)
	_check(respawns == before + 1, "The pending pickup encounters a real death without position changes")


func _scroll() -> Area2D:
	return stage.rooms.get_child(stage.room_index).get_node("Scroll")


func _rest_bypasses() -> void:
	var trials := 0
	for index in [15, 17]:
		for delay in [12, 20, 28]:
			for direction in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				await _setup(index)
				for bumper in stage._bumpers().get_children(): bumper.monitoring = false
				await _step(2)
				var rest: Node2D = stage.rooms.get_child(index).get_node("Rest")
				var landed := false
				for frame in 600:
					if respawns > 0: break
					landed = player.is_on_floor() and player.position.distance_to(rest.global_position - Vector2(0, 34)) < 60
					if landed: break
					_steer_to(rest.position - Vector2(0, 34))
					await _step()
				_release_inputs()
				_check(landed and respawns == 0 and bounces == 0, "The shortcut fixture reaches the real rest from the actual entrance without reflection")
				if failed: return
				await _step(20)
				Input.action_press("move_left")
				await _pulse("jump")
				await _step(delay)
				_release_inputs()
				if direction.x != 0: Input.action_press("move_right" if direction.x > 0 else "move_left")
				if direction.y != 0: Input.action_press("move_down" if direction.y > 0 else "move_up")
				if direction != Vector2.ZERO: await _pulse("dash")
				var reached := false
				for frame in 360:
					if respawns > 0 or stage.transitioning or stage.completed: break
					reached = reached or (player.is_on_floor() and _x() < 180)
					_release_inputs()
					Input.action_press("move_left")
					Input.action_press("wall_grab")
					Input.action_press("move_up")
					await _step()
				_release_inputs()
				_check(not reached and not stage.transitioning and not stage.completed and stage.room_index == index and bounces == 0, "Re-launching from the rest cannot replace reflection: room=%d delay=%d direction=%s" % [index + 1, delay, direction])
				trials += 1
				if failed: return
	print("CANYON_REST_BYPASS_TEST_OK (%d routes)" % trials)


func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/canyon-left")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/canyon-left/%s.png" % label)
