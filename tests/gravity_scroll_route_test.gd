extends "res://tests/stage_3_test.gd"


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_scroll_route_test_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	var started := Engine.get_physics_frames()
	_drive("move_left", true)
	await _until(func(): return player.position.y < 380, 150, "Climb from the actual entrance into the indicated upper branch")
	_release_inputs()
	await _until(func(): return player.is_on_floor(), 90, "The first one-way ledge allows a safe rest")
	_check(player.position.y < 420 and player.is_dash_ready(), "The first ledge restores the Dash")
	_drive("move_left", true)
	await _until(func(): return player.position.y < -65, 180, "Climb above the original screen using real wall controls")
	_release_inputs()
	await _until(func(): return player.is_on_floor(), 90, "The upper left ledge restores stamina")
	_check(stage.camera.position.y < 0, "The camera scrolls upward into the annex")
	await _move_to(104)
	_drive("move_right")
	await _jump()
	await _until(func(): return player.position.x >= 220, 60, "Jump toward the upper right shelf")
	_release_inputs()
	Input.action_press("move_up")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	await _until(func(): return player.position.y < -290, 50, "An upward Dash reaches the real airborne scroll")
	await _until(func(): return not player.is_dashing(), 20, "Finish the upward Dash before steering")
	_drive("move_right")
	await _step(8)
	_release_inputs()
	await _until(func(): return progress.has_scroll("gravity", "wall_loft_01"), 120, "Land safely to secure and save the following scroll")
	_check(respawns == 0 and not stage.cleared.has(0), "The optional branch collects a scroll without dying or clearing the main course")
	_check(float(Engine.get_physics_frames() - started) / 60.0 < 30, "The branch keeps a short retry interval")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _capture_scroll("loft")
	await _move_to(170)
	await _until(func(): return player.is_on_floor() and player.position.y > 580, 150, "Descend through the open center back to the original entrance")
	_check(respawns == 0 and stage.room_index == 0 and player.gravity_direction == 1, "The return path is safe and leaves the main route available")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _capture_scroll("entrance")
	await _retry()
	_check(progress.get_count("gravity") == 1 and player.position.distance_to(Vector2(72, 614)) < 5, "R preserves the confirmed scroll and original checkpoint")
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	_check(current_scene.get_node("Margin/Content/Stages/Stage3/Content/Collection/Count").text == "1 / 10", "Stage selection shows the actual collected and placed total")
	_check(current_scene.get_node("Margin/Content/Stages/Stage3").accessibility_name.contains("巻物 1 / 10"), "The collection count is available to assistive technology")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _capture_scroll("selection")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.has_scroll("gravity", "wall_loft_01"), "Leaving an unfinished stage preserves its saved collection")
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	var scroll: Area2D = current_scene.get_node("Rooms/Room1/ScrollAnnex/Scroll")
	_check(scroll.modulate.a < 1.0, "Revisiting leaves a subdued mark at the acquired scroll")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	_release_inputs()
	print("GRAVITY_SCROLL_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _move_to(target: float) -> void:
	_release_inputs()
	for frame in 180:
		var offset := target - player.position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_press("move_right" if offset > 0 else "move_left", minf(absf(offset) / 50.0, 1.0))
		await _step()
		if absf(offset) < 2 and absf(player.velocity.x) < 10:
			_release_inputs()
			return
	_check(false, "Real movement reaches the target x: %s at %s" % [target, player.position])
	_release_inputs()


func _capture_scroll(label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/scrolls")
	root.get_texture().get_image().save_png("res://docs/screenshots/scrolls/%s.png" % label)
