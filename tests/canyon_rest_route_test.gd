extends "res://tests/canyon_required_bumper_test.gd"

func _run() -> void:
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	for pause in ([180] if screenshots else [0, 60, 180]):
		for delay in ([16] if screenshots else [12, 16, 20]):
			await _setup()
			var started := Engine.get_physics_frames()
			_capture("entrance")
			await _rest()
			_capture("rest")
			var position_before := player.position
			_release_inputs()
			await _step(pause)
			_check(player.is_on_floor() and player.position.distance_to(position_before) < 2 and respawns == 0, "The resting place stays safe with no input for %d frames" % pause)
			_check(player.is_dash_ready(), "The rest restores dash for the next reflection")
			await _resume(delay)
			var seconds := (Engine.get_physics_frames() - started) / 60.0
			_check(stage.room_index == 11 and stage.transitioning and respawns == 1 and bounces == 5, "Resting and resuming reaches the next room through all five real reflections without dying")
			_check(seconds <= 30, "The optional rest route stays below thirty seconds")
			print("CANYON_REST_SECONDS pause=%d dash=%d seconds=%.2f" % [pause, delay, seconds])
	if not screenshots:
		for mode in ["retry", "fall", "thorn"]:
			await _recover(mode)
		await _setup()
		for bumper in stage._bumpers().get_children():
			bumper.monitoring = false
		await _step(2)
		for launch in [90, 135, 170]:
			for delay in [0, 12, 24, 36, 48, 60]:
				for direction in [Vector2.ZERO, Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
					await _try_without_bumper(10, launch, delay, direction)
		_check(bounces == 0, "The negative routes receive no reflection")
	_release_inputs()
	print("CANYON_REST_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _setup() -> void:
	_release_inputs()
	change_scene_to_file("res://scenes/stage_5.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	stage.room_index = 10
	stage._set_checkpoint()
	player.respawn()
	await _step(4)
	respawns = 0
	bounces = 0
	player.respawned.connect(func(): respawns += 1)
	for bumper in stage._bumpers().get_children():
		bumper.launched.connect(func(_body): bounces += 1)


func _rest() -> void:
	for frame in 600:
		if respawns > 0 or stage.room_index != 10:
			break
		if player.is_on_floor() and _x() > 700:
			break
		if stage.next_bumper < 3:
			_steer()
		else:
			_release_inputs()
			var dx := 780.0 - _x()
			var stopping := player.velocity.x * absf(player.velocity.x) / (2 * player.air_acceleration)
			if absf(dx - stopping) > 3:
				Input.action_press("move_right" if dx - stopping > 0 else "move_left")
		await _step()
	_release_inputs()
	_check(respawns == 0 and stage.next_bumper == 3 and bounces == 3 and player.is_on_floor() and absf(_x() - 780) < 20, "Three real reflections reach the optional resting platform")


func _resume(delay: int) -> void:
	await _pulse("jump")
	await _step(delay)
	Input.action_press("move_up")
	await _pulse("dash")
	Input.action_release("move_up")
	while player.is_dashing():
		await _step()
	_capture("ascent")
	for frame in 600:
		if stage.transitioning or respawns > 0:
			break
		_steer()
		await _step()
	_release_inputs()


func _recover(mode: String) -> void:
	await _setup()
	await _rest()
	if mode == "retry":
		await _pulse("reset")
	else:
		Input.action_press("move_right")
		if mode == "fall":
			for frame in 90:
				if _x() > 875:
					break
				await _step()
			Input.action_release("move_right")
			Input.action_press("move_down")
			await _pulse("dash")
			Input.action_release("move_down")
	for frame in 180:
		if respawns > 0:
			break
		await _step()
	_release_inputs()
	await _step(6)
	_check(respawns == 1 and stage.room_index == 10 and player.is_on_floor() and Vector2(_x(), player.position.y).distance_to(Vector2(90, 574)) < 2, "A %s from the real rest returns to the room entrance" % mode)
	_check(stage.next_bumper == 0 and player.is_dash_ready() and player.gravity_direction == 1, "Recovery restores the existing room resources and optional reflection progress")


func _capture(label: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/canyon-rest")
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/canyon-rest/%s.png" % label)
