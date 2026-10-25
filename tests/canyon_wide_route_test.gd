extends "res://tests/canyon_left_route_test.gd"

func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	if not screenshots: await _spike_retry()
	if failed: return
	for profile in ([[1.0, 20]] if screenshots else [[1.0, 20], [0.8, 16], [0.8, 20], [0.8, 24]]):
		for index in range(18, 24):
			await _wide_course(index, profile[0], profile[1])
			if failed: return
	for strength in ([1.0] if screenshots else [1.0, 0.8]):
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for index in [18, 22]:
			await _scroll_branch(index, strength)
			if failed: return
	_release_inputs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_WIDE_ROUTE_TEST_OK (%d checks)" % checks)
	quit()


func _wide_course(index: int, strength: float, dash_delay: int) -> void:
	await _setup(index)
	var room: Node2D = stage.rooms.get_child(index)
	await _capture("room%d_entrance" % (index + 1))
	var started := Engine.get_physics_frames()
	for frame in 1200:
		if stage.next_bumper >= 3 or respawns > 0: break
		_steer(strength)
		if frame == 0: _check(is_equal_approx(absf(Input.get_axis("move_left", "move_right")), strength), "The horizontal action axis matches the reported input strength")
		await _step()
		_check_live_view()
	_check(stage.next_bumper == 3 and respawns == 0, "The first challenge reaches three real reflections")
	if failed: return
	await _land_at_wide_rest(strength)
	if failed: return
	var stopped := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped) < 2 and respawns == 0, "Each wide room has a real safe three-second observation rest")
	await _capture("room%d_rest" % (index + 1))
	await _repeat_wide_third(strength, dash_delay)
	if failed: return
	var saw_horizontal := false
	var captured_late := false
	for frame in 1200:
		if stage.transitioning or stage.completed or respawns > 0: break
		_steer(strength)
		await _step()
		if not stage.transitioning:
			_check_live_view()
			if not captured_late and stage.next_bumper >= stage._bumpers().get_child_count() - 2:
				captured_late = true
				await _capture("room%d_late" % (index + 1))
			_check(absf(stage.camera.position.x - player.position.x) < 700, "The horizontal camera keeps the live player visible")
			_check(stage.camera.position.x >= room.position.x + 639 and stage.camera.position.x <= room.position.x + float(room.get_meta("room_width")) - 639, "The camera stays inside the wide room")
			saw_horizontal = saw_horizontal or absf(stage.camera.position.x - (room.position.x + 640)) > 700
	_release_inputs()
	var seconds := float(Engine.get_physics_frames() - started) / 60
	print("CANYON_WIDE_ROOM_%d strength=%.1f delay=%d %.2fs p=%s next=%d respawns=%d" % [index + 1, strength, dash_delay, seconds, Vector2(_x(),player.position.y),stage.next_bumper,respawns])
	_check((stage.transitioning and stage.room_index == index + 1 and respawns == 1) if index < 23 else (stage.completed and respawns == 0), "The three challenges and rest reach the actual room exit without a death")
	_check(seconds < 30 and saw_horizontal, "A full retry stays below thirty seconds and really crosses the scrolling room")
	_check(progress.get_count("canyon") == 0, "Main routes leave their optional scrolls untouched")


func _scroll_branch(index: int, strength: float) -> void:
	var scroll_id := "wide_sky_04" if index == 18 else "wind_fold_05"
	var before_count: int = progress.get_count("canyon")
	await _setup(index)
	if strength == 1.0 and not OS.get_cmdline_user_args().has("--screenshots"):
		for interruption in ["retry", "death", "leave"]:
			await _take_branch(strength)
			_check(_scroll()._follower == player and not progress.has_scroll("canyon", scroll_id), "An optional airborne scroll waits for a safe landing")
			if interruption == "retry":
				await _pulse("reset")
				await _step(6)
			elif interruption == "death":
				await _fall_from_branch()
			else:
				stage.get_node("PauseMenu").return_to_select()
				await _step(4)
			_check(progress.get_count("canyon") == before_count, "Interrupting a pending pickup preserves only confirmed scrolls")
			await _setup(index)
	var started := Engine.get_physics_frames()
	await _take_branch(strength)
	await _capture("room%d_scroll" % (index + 1))
	await _land_at_wide_rest(strength)
	_check(progress.has_scroll("canyon", scroll_id) and respawns == 0, "The optional detour reaches its real confirmation floor")
	await _capture("room%d_scroll_rest" % (index + 1))
	_check(float(Engine.get_physics_frames() - started) / 60 < 30, "The collection detour has a short retry interval")
	await _step(180)
	await _repeat_wide_third(strength, 20)
	for frame in 1200:
		if stage.transitioning or respawns > 0: break
		_steer(strength)
		await _step()
	_release_inputs()
	_check(stage.transitioning and respawns == 1, "The confirmed optional branch rejoins the main exit")
	if failed: return
	await _setup(index)
	_check(_scroll().modulate.a < 1, "A confirmed scroll has a faint revisit mark")
	await _pulse("reset")
	await _step(6)
	_check(progress.has_scroll("canyon", scroll_id), "Retry preserves a confirmed scroll")
	await _fall_from_branch()
	_check(progress.has_scroll("canyon", scroll_id), "A real death preserves a confirmed scroll")
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	var expected := "%d / 5" % (before_count + 1)
	var card := current_scene.get_node("Margin/Content/Stages/Stage5")
	_check(card.get_node("Content/Collection/Count").text == expected and card.accessibility_name.contains("巻物 " + expected), "Selection and its accessible name use the actual five-scroll total")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("canyon") == before_count + 1 and progress.has_scroll("canyon", scroll_id), "Leaving and reloading retain the unfinished stage's confirmed collection")


func _take_branch(strength: float = 1.0) -> void:
	for frame in 600:
		if stage.next_bumper >= 3 or respawns > 0: break
		_steer(strength)
		await _step()
	_check(stage.next_bumper == 3 and respawns == 0, "The optional turn starts after three real reflections")
	for frame in 240:
		if _scroll()._follower == player or respawns > 0: break
		if frame == 20:
			_release_inputs()
			Input.action_press("move_right" if _scroll().position.x > _x() else "move_left")
			Input.action_press("move_up")
			await _pulse("dash")
		else:
			_steer_to(_scroll().position, false, strength)
		await _step()
	_release_inputs()
	_check(_scroll()._follower == player and respawns == 0, "A deliberate sideways dash contacts the optional airborne scroll")


func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/canyon-wide")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/canyon-wide/%s.png" % label)


func _spike_retry() -> void:
	await _setup(20)
	var hits: Array[bool] = []
	stage.rooms.get_child(20).get_node("Hazards/Gate1Lower").player_hit.connect(func(): hits.append(true))
	for frame in 600:
		if stage.next_bumper >= 2 or respawns > 0: break
		_steer()
		await _step()
	_check(stage.next_bumper == 2 and respawns == 0, "The spike approach starts from two actual reflections")
	for frame in 300:
		if respawns > 0: break
		_steer_to(Vector2(900, 1600))
		await _step()
	_release_inputs()
	await _step(10)
	_check(hits.size() == 1 and respawns == 1 and stage.room_index == 20 and player.position.distance_to(stage.rooms.get_child(20).get_node("Spawn").global_position) < 8, "Entering the closed spike column restores exactly one safe checkpoint")
	await _pulse("jump")
	await _step(12)
	await _pulse("reset")
	await _step(10)
	_check(respawns == 2 and player.is_on_floor() and player.is_dash_ready() and stage.next_bumper == 0, "An actual R after the spike death restores the same room and movement resources")


func _fall_from_branch() -> void:
	var before := respawns
	var left: bool = stage.rooms.get_child(stage.room_index).get_meta("exit_left", false)
	for frame in 240:
		_release_inputs()
		Input.action_press("move_right" if left else "move_left")
		Input.action_press("move_down")
		if player.is_dash_ready(): Input.action_press("dash")
		await _step()
		if respawns > before: break
	_release_inputs()
	await _step(6)
	_check(respawns == before + 1, "The airborne pickup encounters a real death before reaching a safe floor")


func _check_live_view() -> void:
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var body := shape.shape.get_rect()
	body.position += player.position - stage.camera.position + root.get_visible_rect().size * 0.5
	_check(root.get_visible_rect().encloses(body) and not stage.get_node("HUD/Info").get_global_rect().intersects(body), "The whole live player stays on screen outside the persistent HUD: body=%s HUD=%s room=%d next=%d" % [body, stage.get_node("HUD/Info").get_global_rect(), stage.room_index + 1, stage.next_bumper])
