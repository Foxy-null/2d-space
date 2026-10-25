extends "res://tests/canyon_entry_route_test.gd"


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://canyon_entry_scroll_%d.cfg" % OS.get_process_id()
	for strength in ([1.0] if OS.get_cmdline_user_args().has("--strong") or OS.get_cmdline_user_args().has("--screenshots") else [1.0, 0.8]):
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for index in [24, 26]:
			var selected := 0
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--room="): selected = int(arg.trim_prefix("--room="))
			if selected > 0 and selected != index + 1: continue
			await _entry_scroll_lifecycle(index, strength)
			if failed: return
	monitor_view = false
	_release_inputs()
	if OS.get_cmdline_user_args().has("--keep-fixture"):
		print("CANYON_ENTRY_SAVED_PATH ", progress.save_path)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_ENTRY_SCROLL_TEST_OK (", checks, " checks)")
	quit()


func _entry_scroll_lifecycle(index: int, strength: float) -> void:
	var id := "spring_loft_06" if index == 24 else "updraft_left_07"
	var before: int = progress.get_count("canyon")
	if not OS.get_cmdline_user_args().has("--screenshots") and not OS.get_cmdline_user_args().has("--branch-only"):
		for interruption in ["retry", "death", "leave"]:
			await _entry_setup(index)
			await _entry_pickup(strength, interruption == "death")
			if failed: return
			_check(_scroll()._follower == player and not progress.has_scroll("canyon", id), "The actual airborne pickup remains pending before a safe landing")
			if interruption == "retry":
				await _pulse("reset")
				await _step(6)
				_check(_scroll()._follower == null and _scroll().global_position == _scroll()._origin, "R restores the pending native scroll to its own position")
			elif interruption == "death":
				await _entry_fall()
				_check(_scroll()._follower == null and _scroll().global_position == _scroll()._origin, "A real fall restores the pending scroll")
			else:
				stage.get_node("PauseMenu").return_to_select()
				await _step(4)
			_check(progress.get_count("canyon") == before, "An interrupted pickup does not change the saved collection")
			if failed: return
	await _entry_setup(index)
	var started := Engine.get_physics_frames()
	await _entry_pickup(strength)
	if failed: return
	await _capture("room%d_scroll_touch" % (index + 1))
	await _entry_scroll_land(strength)
	_check(progress.has_scroll("canyon", id) and respawns == 0, "The actual optional shelf secures its own scroll")
	var stopped := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped) < 2 and respawns == 0, "The scroll shelf permits three seconds of safe observation")
	await _capture("room%d_scroll_rest" % (index + 1))
	if index == 24:
		await _land_at_wide_rest(strength)
	else:
		await _pulse("jump")
		var updraft: Area2D = stage.rooms.get_child(index).get_node("Winds/Updraft")
		for frame in 900:
			_entry_horizontal(320, strength)
			await _step()
			if _x() > 270 and player.position.y < 970 and player._winds.has(updraft.get_instance_id()): break
			if respawns > 0: break
		_check(_x() > 270 and player.position.y < 970 and player._winds.has(updraft.get_instance_id()) and respawns == 0 and player.get_held_object() == stage.rooms.get_child(index).get_node("Items/Parachute"), "A real jump carries the parachute back into actual contact with the original updraft")
	var branch_seconds := float(Engine.get_physics_frames() - started) / 60
	_check(branch_seconds < 30, "The entrance, optional pickup and return remain below thirty seconds")
	await _capture("room%d_scroll_return" % (index + 1))
	if index == 24:
		await _repeat_wide_third(strength, 20)
	else:
		for frame in 1200:
			if stage.next_bumper >= 3 or respawns > 0: break
			_steer(strength)
			await _step()
		_check(stage.next_bumper == 3 and respawns == 0, "The returned parachute rejoins the same real reflection sequence")
		await _land_at_wide_rest(strength)
		await _repeat_wide_third(strength, 20)
	await _entry_finish(strength)
	_release_inputs()
	_check((stage.room_index == 25 and stage.transitioning and respawns == 1) if index == 24 else (stage.completed and respawns == 0), "The detour returns naturally to the actual next checkpoint or final Goal")
	print("CANYON_ENTRY_SCROLL_", index + 1, " strength=", strength, " branch_seconds=", branch_seconds, " total_to_exit_seconds=", float(Engine.get_physics_frames() - started) / 60)
	if failed: return
	await _entry_setup(index)
	_check(_scroll().modulate.a < 1 and _scroll()._follower == null, "A secured scroll remains a faint native marker on revisit")
	await _pulse("reset")
	await _step(6)
	_check(progress.has_scroll("canyon", id), "R preserves the confirmed collection")
	await _entry_fall()
	_check(progress.has_scroll("canyon", id) and stage.room_index == index and player.is_dash_ready(), "Actual death preserves the saved scroll and restores this room checkpoint")
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage5")
	var expected := "%d / 7" % (before + 1)
	_check(card.get_node("Content/Collection/Count").text == expected and card.accessibility_name.contains("巻物 " + expected), "The selection and accessible name show the saved count out of seven")
	await _capture("room%d_scroll_selection" % (index + 1))
	progress._collected.clear()
	progress.load_progress()
	_check(progress.has_scroll("canyon", id) and progress.get_count("canyon") == before + 1, "Confirmed collection survives a real return and save reload")


func _entry_setup(index: int) -> void:
	monitor_view = false
	await _setup(index)
	stage.set_hints_visible(OS.get_cmdline_user_args().has("--hints"))


func _entry_pickup(strength: float, from_rest := false) -> void:
	monitor_view = true
	await _entry_begin(strength)
	if failed: return
	if stage.room_index == 24:
		for frame in 1200:
			if stage.next_bumper >= 3 or respawns > 0: break
			_steer(strength)
			await _step()
		_check(stage.next_bumper == 3 and respawns == 0, "The upper branch starts after the actual Spring and three reflections")
		await _capture("room25_scroll_approach")
		if from_rest:
			await _entry_scroll_land(strength, 1030)
			_check(_scroll()._follower == null and not _scroll()._secured, "The death fixture reaches the right of the shelf before touching the scroll")
			for frame in 180:
				_entry_horizontal(950, strength)
				await _step()
				if absf(_x() - 950) < 10 and absf(player.velocity.x) < 30: break
			await _pulse("jump")
	else:
		await _capture("room27_scroll_approach")
		await _entry_scroll_land(strength, 180)
		_check(_scroll()._follower == null and not _scroll()._secured, "The parachute lands beside the scroll before the real pickup jump")
		for frame in 180:
			_entry_horizontal(90, strength)
			await _step()
			if absf(_x() - 90) < 10 and absf(player.velocity.x) < 30: break
		await _pulse("jump")
	for frame in 360:
		if _scroll()._follower == player or respawns > 0: break
		_steer_to(_scroll().position, false, strength)
		await _step()
	_release_inputs()
	_check(_scroll()._follower == player and not player.is_on_floor() and respawns == 0, "Real controls contact the optional airborne scroll without a death")


func _entry_scroll_land(strength: float, target_x := NAN) -> void:
	var rest: StaticBody2D = stage.rooms.get_child(stage.room_index).get_node("ScrollRest")
	var target := rest.position.x if is_nan(target_x) else target_x
	for frame in 700:
		_entry_horizontal(target, strength)
		await _step()
		if player.is_on_floor() and absf(player.position.y - (rest.position.y - 34)) < 2 and absf(_x() - target) < 20 and absf(player.velocity.x) < 35: break
		if respawns > 0: break
	_release_inputs()
	await _step(20)
	_check(player.is_on_floor() and absf(player.position.y - (rest.position.y - 34)) < 2 and absf(_x() - target) < 25 and respawns == 0, "Actual motion lands and stops on the native optional shelf")


func _entry_fall() -> void:
	monitor_view = false
	var before := respawns
	for frame in 600:
		_release_inputs()
		Input.action_press("move_left")
		Input.action_press("move_down")
		if player.is_dash_ready(): Input.action_press("dash")
		await _step()
		if respawns > before: break
	_release_inputs()
	await _step(6)
	_check(respawns == before + 1, "Normal movement encounters actual death without changing the player position")


func _capture(label: String) -> void:
	if not label.contains("_scroll_"): return
	if OS.get_cmdline_user_args().has("--stage-only") and label.ends_with("_selection"): return
	if OS.get_cmdline_user_args().has("--selection-only") and not label.ends_with("_selection"): return
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	if screenshots:
		await process_frame
		RenderingServer.force_draw()
	if label.ends_with("_approach"):
		var room: Node2D = stage.rooms.get_child(stage.room_index)
		var scroll: Area2D = room.get_node("Scroll")
		var mark: Node2D = room.get_node("ScrollMark")
		var scroll_bounds := Rect2(root.get_canvas_transform() * scroll.global_position - Vector2(16, 20), Vector2(32, 40))
		var mark_bounds: Rect2 = mark.get_global_transform_with_canvas() * Rect2(-16, -20, 32, 40)
		var hud: Rect2 = stage.get_node("HUD/Info").get_global_rect()
		_check(root.get_visible_rect().encloses(scroll_bounds) and not hud.intersects(scroll_bounds), "The actual optional scroll is visible outside the persistent HUD at its real approach")
		_check(root.get_visible_rect().encloses(mark_bounds) and not hud.intersects(mark_bounds), "The subtle branch entrance marker remains visible before choosing the detour")
		var hint: Control = stage.get_node("HUD/Hint")
		if hint.visible:
			_check(not hint.get_global_rect().intersects(scroll_bounds) and not hint.get_global_rect().intersects(mark_bounds), "The visible optional hint does not hide the actual scroll or its entrance marker")
		if screenshots: print("CANYON_ENTRY_BRANCH_VIEW ", label, " scroll=", scroll_bounds, " marker=", mark_bounds, " hud=", hud)
	if not screenshots: return
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/canyon-entry")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/canyon-entry/%s.png" % label) == OK, "The native optional branch image is saved")
