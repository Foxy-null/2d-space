extends "res://tests/stage_2_test.gd"

var progress: Node
var scroll: Area2D

func _run() -> void:
	if OS.get_cmdline_user_args().has("--weak"):
		upper_strength = 0.85
		Input.action_press("move_right", upper_strength)
		_check(is_equal_approx(Input.get_axis("move_left","move_right"),0.85), "The optional-route probe uses a real 0.85 movement axis")
		_release()
	progress = root.get_node("CollectionProgress")
	for high in [false, true]:
		await _fresh_branch(high)
		var ids := {}
		for placed in stage.get_node("ScrollBranch").get_children():
			if placed is Area2D:
				_check(placed.stage_id == "tower" and not ids.has(placed.scroll_id), "All actual tower scrolls have unique stage-scoped IDs")
				ids[placed.scroll_id] = true
		_check(ids.size() == 5, "The reported total corresponds to five actual collectibles")
		for manual in [true, false]:
			await _pickup(high)
			var before := respawns
			if manual:
				await _upper_pulse("reset")
			else:
				# The first airborne touch is deliberately taken away from a landing.
				if high:
					_horizontal(-560)
					for frame in 120:
						await _step()
						if player.is_on_floor():break
					_check(scroll._follower == player and not scroll._secured, "The high scroll is still pending on its first landing frame")
					_horizontal(-1000)
					await _upper_pulse("jump")
					await _step(20)
					await _upper_pulse("dash")
				else:
					_horizontal(-800)
				for frame in 240:
					await _step()
					if respawns > before:break
			await _step(8)
			_check(respawns == before + 1 and player.is_on_floor(), "A real fall and R return to the current safe flag")
			_check(scroll._follower == null and not scroll._secured, "A pending optional scroll resets instead of being saved")
		var before := respawns
		var start := Engine.get_physics_frames()
		await _pickup(high)
		await _land_on(-560 if high else -1030, -18526 if high else -14286)
		_check(respawns == before, "The real balcony is reached without falling back to the same-height checkpoint")
		await _more_walk(-560 if high else -1030)
		await _step(20)
		_check(scroll._secured, "A stable actual balcony landing secures the scroll")
		if high:
			await _more_walk(-500)
			Input.action_press("move_right", upper_strength)
			await _upper_pulse("jump")
			await _step(20)
			await _upper_pulse("dash")
			await _land_on(0,-18106,240)
			await _more_walk(950)
			Input.action_press("move_right", upper_strength)
			await _upper_pulse("jump")
			await _land_on(1200,-18106,180)
			await _more_walk(1200)
		else:
			await _more_walk(-940)
			Input.action_press("move_right", upper_strength)
			await _upper_pulse("jump")
			await _step(20)
			await _upper_pulse("dash")
			await _land_on(-550,-14286,240)
			await _more_walk(-400)
		_check(respawns == before and stage.checkpoint_index == (16 if high else 14), "Both optional branches return naturally to their original flag: high=%s before=%s respawns=%s cp=%s pos=%s" % [high,before,respawns,stage.checkpoint_index,player.position])
		var seconds := (Engine.get_physics_frames() - start) / 60.0
		_check(seconds < 30, "Optional collection and return stay below thirty seconds")
		print("TOWER_MORE_SCROLL_SECONDS high=%s %.2f" % [high,seconds])
		await _upper_pulse("reset")
		await _step(8)
		_check(scroll._secured, "R preserves a confirmed optional scroll")
		before = respawns
		Input.action_press("wall_grab")
		Input.action_press("move_right" if high else "move_left", upper_strength)
		for frame in 240:
			await _step()
			if respawns > before: break
		_release()
		await _step(8)
		_check(respawns == before + 1 and player.is_on_floor() and scroll._secured, "An actual fall also preserves the confirmed scroll at the same flag")
	stage.get_node("PauseMenu").return_to_select()
	await _step(5)
	_check(current_scene.get_node("Margin/Content/Stages/Stage2/Content/Collection/Count").text == "2 / 5", "Selection counts both new scrolls against all five placements")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.has_scroll("tower", "left_return_04") and progress.has_scroll("tower", "upper_wall_05"), "Both unique scroll IDs survive a disk reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	_release()
	print("TOWER_MORE_SCROLL_TEST_", "FAILED" if failed else "OK")
	quit(1 if failed else 0)

func _fresh_branch(high: bool) -> void:
	_release()
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(6)
	stage = current_scene
	player = stage.player
	stage._set_checkpoint(16 if high else 13)
	player.respawned.connect(func():respawns += 1)
	player.respawn()
	await _step(8)
	respawns = 0
	if not high:
		await _more_bounce(1300, "More14Bumper", Vector2(800,-13600))
		await _more_spring(-800, Vector2(-400,-14260))
		_check(respawns == 0 and stage.checkpoint_index == 14, "The actual first landing activates CP15 before the left detour")
	scroll = stage.get_node("ScrollBranch/MoreHighScroll" if high else "ScrollBranch/MoreLeftScroll")

func _pickup(high: bool) -> void:
	if high:
		await _more_walk(1170)
		Input.action_press("move_left", upper_strength)
		await _upper_pulse("jump")
		await _land_on(850,-18106,180)
	await _more_walk(-70 if high else -570)
	Input.action_press("move_left", upper_strength)
	await _upper_pulse("jump")
	await _step(20)
	await _upper_pulse("dash")
	if high:
		for frame in 120:
			if not player.is_dashing():
				Input.action_press("wall_grab")
				Input.action_press("move_up")
			await _step()
			if player.is_on_wall():break
		_check(player.is_on_wall(), "A real horizontal gap jump reaches the optional wall")
		for frame in 180:
			Input.action_press("wall_grab")
			Input.action_press("move_up")
			await _step()
			if player.is_on_floor() and player.position.y < -18500:break
		_release()
		_check(player.is_on_floor() and player.position.y < -18500, "The optional wall reaches its actual top")
		await _more_walk(-560)
		await _upper_pulse("jump")
		for frame in 60:
			await _step()
			if scroll._follower == player:break
	else:
		for frame in 90:
			if not player.is_dashing():_horizontal(-1030)
			await _step()
			if scroll._follower == player:break
	_check(scroll._follower == player and not scroll._secured and not player.is_on_floor(), "A real airborne pickup remains pending until safe landing")

func _check(ok: bool, message: String) -> void:
	super._check(ok,message)
	if not ok:quit(1)
