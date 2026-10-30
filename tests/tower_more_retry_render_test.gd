extends "res://tests/stage_2_test.gd"


func _run() -> void:
	var capture := OS.get_cmdline_user_args().has("--screenshots")
	var poses := [
		[12, "13-entrance", Vector2(420,-10726)], [12, "13-refill", Vector2(700,-11326)], [12, "13-spring", Vector2(1800,-11826)],
		[13, "14-reflection", Vector2(1450,-12486)], [13, "14-turn", Vector2(-730,-13626)],
		[14, "15-entrance", Vector2(-400,-14286)], [14, "15-upper-wall", Vector2(650,-15366)],
		[15, "16-entrance", Vector2(650,-15966)], [15, "16-refill", Vector2(1400,-17606)],
		[16, "17-reflection", Vector2(1200,-18106)], [16, "17-left-rest-edge", Vector2(0,-19246)], [16, "17-upper-spring", Vector2(1520,-19786)],
		[17, "18-entrance", Vector2(1300,-20446)], [17, "18-final-spring", Vector2(310,-21586)],
		[17, "18-summit", Vector2(-100,-22346)],
		[14, "left-branch-mark", Vector2(-550,-14286)], [14, "left-scroll-balcony", Vector2(-1030,-14286)],
		[16, "high-branch-mark", Vector2(-50,-18106)], [16, "high-scroll-wall", Vector2(-560,-18526)],
	]
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): selected = arg.trim_prefix("--view=")
	for pose in poses:
		if selected != "" and not String(pose[1]).begins_with(selected): continue
		_release()
		change_scene_to_file("res://scenes/stage_2.tscn")
		await _step(6)
		stage = current_scene
		player = stage.player
		stage._set_checkpoint(pose[0])
		player.set_respawn_position(pose[2])
		player.respawn()
		await _step(12)
		_check(player.is_on_floor(), "The visual fixture rests on its actual native floor: " + pose[1])
		var rest: Vector2 = player.position
		await _step(180 if not capture else 3)
		_check(player.position.distance_to(rest) < 1.0 and player.is_on_floor(), "The native observation rest remains stable: " + pose[1])
		_check(is_equal_approx(stage.get_node("Background/Stars").camera_top, stage.get_node("Goal").position.y - 240.0), "The ascent sky spans the actual new goal height")
		var screen := player.get_global_transform_with_canvas().origin
		_check(screen.x > 20 and screen.x < 1260 and screen.y > 100 and screen.y < 700, "The camera keeps the player visible: " + pose[1])
		if pose[1] in ["14-reflection", "17-reflection", "18-final-spring"]:
			var target_name := "More18Dash" if pose[0] == 17 else ("More14Bumper" if pose[0] == 13 else "More17Bumper")
			var bumper: Node2D = stage.get_node("Items/" + target_name)
			var bumper_screen := bumper.get_global_transform_with_canvas().origin
			var bumper_rect := Rect2(bumper_screen - Vector2(34,34), Vector2(68,68))
			_check(not bumper_rect.intersects(stage.get_node("HUD/Info").get_global_rect()), "The next airborne target is clear of the HUD from its safe launch")
		if capture:
			await process_frame
			await RenderingServer.frame_post_draw
			var folder := "res://docs/screenshots/tower-more"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			_check(root.get_texture().get_image().save_png(folder + "/" + pose[1] + ".png") == OK, "The native tower view saves: " + pose[1])
		else:
			stage._set_checkpoint(pose[0])
			await _upper_pulse("reset")
			await _step(8)
			_check(player.is_on_floor() and absf(player.position.y - stage.checkpoints.get_child(pose[0]).position.y + 26) < 3, "R restores the actual current flag from every rest")
	if not capture and selected == "":
		for section in range(12,18):
			stage._set_checkpoint(section)
			player.respawn()
			await _step(8)
			var falls := [0]
			var callback := func(): falls[0] += 1
			player.respawned.connect(callback)
			Input.action_press("wall_grab")
			Input.action_press("move_left" if section == 12 else "move_right")
			var start := Engine.get_physics_frames()
			for frame in 500:
				await _step()
				if falls[0] > 0: break
			_release()
			await _step(10)
			player.respawned.disconnect(callback)
			_check(falls[0] == 1 and stage.checkpoint_index == section and player.is_on_floor(), "An actual off-edge fall returns to each new flag")
			_check((Engine.get_physics_frames() - start) / 60.0 < 30, "Fall and recovery stay short")
	_release()
	print("TOWER_MORE_RETRY_RENDER_TEST_", "FAILED" if failed else "OK")
	quit(1 if failed else 0)
