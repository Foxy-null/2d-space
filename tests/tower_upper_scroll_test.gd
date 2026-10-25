extends "res://tests/stage_2_test.gd"

var progress: Node
var scroll: Area2D


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://tower_upper_scroll_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(6)
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	await _wall_course()
	await _spring_course()
	await _dash_course()
	await _extra_jump_course()
	await _companion_course()
	await _finale_course()
	await _upper_course(6)
	_check(respawns == 0 and stage.checkpoint_index == 7, "The real entrance reaches the new spring branch through the seven main sections")
	scroll = stage.get_node("ScrollBranch/SpringTurnScroll")
	for manual in [true, false]:
		await _spring_rest()
		await _spring_pickup()
		var before := respawns
		if manual:
			await _upper_pulse("reset")
		else:
			_horizontal(80)
			for frame in 180:
				await _step()
				if respawns > before:
					break
		await _step(8)
		_check(respawns == before + 1 and stage.checkpoint_index == 7 and player.is_on_floor(), "An unconfirmed spring branch safely retries at its actual checkpoint")
		_check(scroll._follower == null and progress.get_count("tower") == 0, "R and an actual fall return the unsecured spring scroll")
	await _spring_rest()
	await _walk_to(365)
	await _upper_capture("spring-branch-entrance")
	var started := Engine.get_physics_frames()
	var before := respawns
	await _spring_pickup()
	await _land_on(-230, -5226)
	await _step(20)
	_check(progress.has_scroll("tower", "spring_turn_02"), "Landing on the real balcony secures the spring scroll")
	await _upper_capture("spring-scroll")
	await _walk_to(-120)
	Input.action_press("move_right")
	await _upper_pulse("jump")
	await _step(20)
	await _upper_pulse("dash")
	await _land_on(420, -5226, 240)
	_check(respawns == before and stage.checkpoint_index == 7, "The spring branch returns to the same main rest without moving its checkpoint")
	_check(float(Engine.get_physics_frames() - started) / 60.0 < 30, "The spring detour and return remain short")
	print("TOWER_SPRING_SCROLL_SECONDS %.2f" % (float(Engine.get_physics_frames() - started) / 60.0))
	await _upper_pulse("reset")
	await _step(8)
	_check(scroll._secured and progress.get_count("tower") == 1, "Retry keeps a confirmed upper scroll")
	await _upper_course(7)
	await _upper_course(8)
	await _upper_course(9)
	await _upper_course(10)
	scroll = stage.get_node("ScrollBranch/WindRestScroll")
	for manual in [true, false]:
		await _wind_pickup()
		before = respawns
		if manual:
			await _upper_pulse("reset")
		else:
			# Leave on the first landing frame, before the 0.2-second confirmation.
			for frame in 180:
				_horizontal(-260)
				await _step()
				if player.is_on_floor():
					break
			_check(scroll._follower == player and not scroll._secured, "A touch-and-go landing still has a pending scroll")
			Input.action_release("move_up")
			_horizontal(40)
			await _upper_pulse("jump")
			await _step(20)
			await _upper_pulse("dash")
			for frame in 180:
				_horizontal(40)
				await _step()
				if respawns > before:
					break
		await _step(8)
		_check(respawns == before + 1 and stage.checkpoint_index == 11 and player.is_on_floor(), "The unsecured wind branch retries on the same safe main floor")
		_check(scroll._follower == null and progress.get_count("tower") == 1, "R and an actual wind-branch fall do not save a pending scroll: manual=%s count=%s secured=%s" % [manual, progress.get_count("tower"), scroll._secured])
	await _upper_capture("wind-branch-entrance")
	before = respawns
	started = Engine.get_physics_frames()
	await _wind_pickup()
	await _land_on(-260, -9566)
	await _step(20)
	_check(progress.has_scroll("tower", "wind_rest_03"), "The second upper branch secures its own stable scroll ID: p=%s follower=%s safe=%s count=%s" % [player.position, scroll._follower, scroll._safe_time, progress.get_count("tower")])
	await _upper_capture("wind-scroll")
	await _walk_to(-188)
	Input.action_press("move_right")
	await _upper_pulse("jump")
	await _step(20)
	Input.action_press("move_up")
	await _upper_pulse("dash")
	await _land_on(360, -9566)
	_check(respawns == before and stage.checkpoint_index == 11, "The wind rest's branch returns to the same safe checkpoint")
	_check(float(Engine.get_physics_frames() - started) / 60.0 < 30, "The second optional round trip keeps a short retry interval")
	print("TOWER_WIND_SCROLL_SECONDS %.2f" % (float(Engine.get_physics_frames() - started) / 60.0))
	await _upper_course(11)
	_check(stage.completed, "All twelve sections and both new detours reach the final physical goal")
	stage.get_node("PauseMenu").return_to_select()
	await _step(5)
	_check(current_scene.get_node("Margin/Content/Stages/Stage2/Content/Collection/Count").text == "2 / 3", "Selection counts the two new scrolls against all three actual tower placements")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.has_scroll("tower", "spring_turn_02") and progress.has_scroll("tower", "wind_rest_03"), "Returning from the expanded tower preserves both confirmed scrolls")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	_release()
	print("TOWER_UPPER_SCROLL_TEST_", "FAILED" if failed else "OK")
	quit(1 if failed else 0)


func _spring_rest() -> void:
	_release()
	Input.action_press("move_right")
	await _await_launch()
	_horizontal(420)
	await _step(46)
	await _upper_pulse("dash")
	await _land_on(420, -5226)


func _spring_pickup() -> void:
	_horizontal(280)
	await _await_launch()
	_horizontal(-60)
	await _step(20)
	Input.action_press("move_up")
	await _upper_pulse("dash")
	for frame in 150:
		if not player.is_dashing():
			Input.action_release("move_up")
			_horizontal(-60)
		await _step()
		if scroll._follower == player:
			break
	_check(scroll._follower == player and not scroll._secured and not player.is_on_floor(), "A real spring and diagonal dash pick up the optional scroll before landing")


func _check(ok: bool, message: String) -> void:
	super._check(ok, message)
	if not ok:
		quit(1)


func _wind_pickup() -> void:
	await _walk_to(198)
	Input.action_press("move_left")
	await _upper_pulse("jump")
	await _step(20)
	Input.action_press("move_up")
	await _upper_pulse("dash")
	for frame in 180:
		if not player.is_dashing():
			Input.action_release("move_up")
			_horizontal(-260)
		await _step()
		if scroll._follower == player:
			break
	_check(scroll._follower == player and not scroll._secured and not player.is_on_floor(), "The wind branch picks up its scroll before the confirming landing")
