extends "res://tests/stage_2_test.gd"

var progress: Node
var scroll: Area2D


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://tower_scroll_route_test_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(6)
	stage = current_scene
	player = stage.player
	scroll = stage.get_node("ScrollBranch/Scroll")
	player.respawned.connect(func(): respawns += 1)
	await _wall_course()
	await _spring_course()
	_check(respawns == 0 and stage.checkpoint_index == 2, "The real entrance and both required themes lead to the optional branch")
	await _without_dash()
	await _move_to(258)
	await _capture_scroll("entrance")
	for delay in [16, 20, 24]:
		await _cross_left(false, delay)
		_release()
		await _pulse("reset")
		await _step(6)
		_check(not is_instance_valid(scroll._follower) and scroll.global_position == scroll._origin and progress.get_count("tower") == 0, "R before landing returns the pending scroll to its branch")
		_check(stage.checkpoint_index == 2 and player.position.distance_to(Vector2(360, -826)) < 2, "The optional attempt retries at CP03")
		respawns = 0
		await _move_to(258)
	await _move_to(258)
	await _cross_left(false)
	_release()
	Input.action_press("move_right")
	for frame in 180:
		await _step()
		if respawns > 0:
			break
	_release()
	await _step(6)
	_check(respawns == 1 and progress.get_count("tower") == 0 and not is_instance_valid(scroll._follower), "Falling beyond the balcony returns the unconfirmed scroll without saving it")
	_check(stage.checkpoint_index == 2 and player.position.distance_to(Vector2(360, -826)) < 2, "The branch fall keeps its nearby checkpoint")
	respawns = 0
	await _move_to(258)
	var started := Engine.get_physics_frames()
	await _cross_left(true)
	_check(stage.camera.position.x < 150 and respawns == 0, "The camera reveals the left branch without a retry")
	await _capture_scroll("balcony")
	await _move_to(-120)
	await _cross_right()
	_check(stage.checkpoint_index == 2 and respawns == 0 and player.is_on_floor(), "The collected detour returns to the same main-route platform")
	var seconds := float(Engine.get_physics_frames() - started) / 60.0
	_check(seconds < 30, "The complete optional round trip stays below thirty seconds")
	print("TOWER_SCROLL_ROUND_TRIP_SECONDS %.2f" % seconds)
	await _capture_scroll("return")
	await _pulse("reset")
	await _step(6)
	_check(progress.get_count("tower") == 1 and scroll._secured, "R preserves the confirmed scroll")
	respawns = 0
	await _without_dash()
	_check(progress.get_count("tower") == 1 and scroll._secured, "A real fall preserves the confirmed scroll")
	await _dash_course()
	await _extra_jump_course()
	await _companion_course()
	await _finale_course()
	_check(respawns == 0 and stage.completed, "The entire original tower remains playable after the optional return")
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	_check(current_scene.get_node("Margin/Content/Stages/Stage2/Content/Collection/Count").text == "1 / 1", "Selection shows the collected and actual placed tower total")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.has_scroll("tower", "left_balcony_01"), "Leaving the stage preserves its saved collection")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	_release()
	print("TOWER_SCROLL_ROUTE_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)


func _cross_left(land: bool, dash_delay: int = 20) -> void:
	_release()
	Input.action_press("move_left")
	await _pulse("jump")
	await _step(dash_delay)
	await _pulse("dash")
	for frame in 90:
		await _step()
		if is_instance_valid(scroll._follower):
			break
	_check(is_instance_valid(scroll._follower) and not player.is_on_floor(), "A real airborne jump and horizontal Dash reaches the scroll across the gap")
	if not land:
		return
	for frame in 90:
		if player.position.x < -160:
			_release()
		await _step()
		if progress.has_scroll("tower", "left_balcony_01"):
			break
	_check(progress.has_scroll("tower", "left_balcony_01") and player.is_on_floor() and player.position.x < -100, "A safe balcony landing confirms the following scroll")
	_check(player.is_dash_ready(), "The balcony restores the Dash for the return trip")


func _without_dash() -> void:
	await _move_to(258)
	player.dash_enabled = false
	Input.action_press("move_left")
	await _pulse("jump")
	for frame in 150:
		await _step()
		if respawns > 0:
			break
	_release()
	player.dash_enabled = true
	await _step(6)
	_check(respawns == 1 and stage.checkpoint_index == 2 and player.position.distance_to(Vector2(360, -826)) < 2, "An ordinary jump cannot cross the gap and safely retries at CP03")
	respawns = 0


func _cross_right() -> void:
	_release()
	Input.action_press("move_right")
	await _pulse("jump")
	await _step(20)
	await _pulse("dash")
	for frame in 120:
		await _step()
		if player.position.x >= 320:
			_release()
		if player.is_on_floor() and player.position.x > 240:
			break
	_release()
	await _step(16)
	_check(player.position.y < -820 and player.is_on_floor(), "Jump and horizontal Dash return across the real gap")


func _move_to(target: float) -> void:
	_release()
	for frame in 120:
		var dx := target - player.position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_press("move_right" if dx > 0 else "move_left", minf(absf(dx) / 50.0, 1.0))
		await _step()
		if absf(dx) < 2 and absf(player.velocity.x) < 10:
			break
	_release()
	await _step(6)
	_check(player.is_on_floor() and absf(player.position.x - target) < 5, "Real walking reaches the branch launch edge")


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _capture_scroll(label: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		await process_frame
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tower-scroll")
		root.get_texture().get_image().save_png("res://docs/screenshots/tower-scroll/%s.png" % label)
