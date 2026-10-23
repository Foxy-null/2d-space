extends "res://tests/stage_2_test.gd"

var wall_frames := 0
var wall_jumps := 0
var superdashes := 0
var captured_rest := false
var rest_frames := 0


func _run() -> void:
	stage = load("res://scenes/stage_2.tscn").instantiate()
	root.add_child(stage)
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action: String):
		if action == "wall_jump": wall_jumps += 1
		if action == "superdash": superdashes += 1)
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	if not screenshots:
		await _bypasses()
		await _let_go()
	for grab_delay in ([0] if screenshots else [0, 6, 12]):
		for dash_delay in ([20] if screenshots else [16, 20, 24]):
			await _enter()
			_capture("entrance")
			await _wall_course(grab_delay, dash_delay)
			_check(wall_frames > 60 and respawns == 0, "The opening uses a real sustained wall climb without retry")
	_capture("checkpoint")
	await _pulse("reset")
	await _step(6)
	_check(stage.checkpoint_index == 1 and player.is_on_floor() and player.position.distance_to(Vector2(900, -106)) < 2, "R after the opening preserves CP02")
	print("TOWER_WALL_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)


func _enter() -> void:
	_release()
	stage._set_checkpoint(0)
	player.respawn()
	await _step(6)
	respawns = 0
	wall_frames = 0
	wall_jumps = 0
	superdashes = 0
	captured_rest = false
	rest_frames = 0


func _bypasses() -> void:
	# 標準のジャンプ・ダッシュだけを残し、壁登りと壁キックを除いて比較する。
	player.wall_actions_enabled = false
	for start_x in [180, 300, 450]:
		for direction in _directions():
			for dash_frame in [-1, 0, 12, 20, 28, 40]:
				await _attempt(start_x, direction, dash_frame, false)
		print("TOWER_WALL_BYPASSES jump start=%d: 48 attempts" % start_x)
	var actual_superdashes := 0
	for start_x in [180, 300, 450]:
		for direction in [Vector2.LEFT, Vector2.RIGHT]:
			for jump_frame in [0, 2, 4, 8, 12, 16]:
				await _attempt(start_x, direction, jump_frame, true)
				actual_superdashes += int(superdashes > 0)
		print("TOWER_WALL_BYPASSES superdash start=%d: 12 attempts" % start_x)
	_check(actual_superdashes >= 12, "The bypass sweep contains real ground-dash-to-jump superdashes")
	print("TOWER_WALL_ACTUAL_SUPERDASHES %d" % actual_superdashes)
	player.wall_actions_enabled = true


func _attempt(start_x: int, direction: Vector2, action_frame: int, superdash: bool) -> void:
	await _enter()
	for frame in 120:
		var dx := start_x - player.position.x
		if absf(dx) < 10 and player.is_on_floor(): break
		_set_direction(Vector2(signf(dx), 0))
		await _step()
	_set_direction(Vector2.ZERO)
	await _step(12)
	_check(player.is_on_floor() and absf(player.position.x - start_x) < 35, "The ordinary-movement bypass reaches its actual floor launch")
	if superdash:
		_set_direction(direction)
		await _pulse("dash")
	else:
		await _pulse("jump")
	var highest := player.position.y
	for frame in 180:
		_set_direction(Vector2(620 - player.position.x, -1))
		if frame == action_frame:
			if superdash:
				await _pulse("jump")
			else:
				_set_direction(direction)
				await _pulse("dash")
		await _step()
		if respawns > 0: break
		highest = minf(highest, player.position.y)
	_check(highest > 184 and stage.checkpoint_index == 0 and wall_frames == 0 and wall_jumps == 0, "Ordinary jump/dash/superdash and the outer wall cannot reach the first rest without a wall action: start=%d direction=%s frame=%d superdash=%s highest=%.2f" % [start_x, direction, action_frame, superdash, highest])
	_release()


func _let_go() -> void:
	await _enter()
	Input.action_press("move_right")
	for frame in 90:
		await _step()
		if player.is_on_wall(): break
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	await _step(45)
	_check(player.is_wall_grabbing() and player.position.y < 500 and player.get_wall_stamina() < 2.5, "The fall starts after a real climb that consumes stamina")
	_release()
	Input.action_press("move_left")
	await _step(54)
	_release()
	await _step(80)
	_check(respawns == 0 and stage.checkpoint_index == 0 and player.is_on_floor() and player.position.y <= 675, "Letting go returns to the safe floor without a death or lost checkpoint")
	_check(player.is_dash_ready() and player.get_wall_stamina() > 2.9, "The safe floor restores the movement resources for another try")
	await _pulse("reset")
	await _step(6)
	_check(player.is_on_floor() and player.position.distance_to(Vector2(360, 614)) < 2, "R returns to the original observation platform")


func _directions() -> Array:
	return [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]


func _set_direction(direction: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if absf(direction.x) > 0.1:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if absf(direction.y) > 0.1:
		Input.action_press("move_down" if direction.y > 0 else "move_up")


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _release() -> void:
	super._release()
	Input.action_release("move_down")
	Input.action_release("reset")


func _capture(label: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/tower-wall-%s.png" % label)


func _step(count: int = 1) -> void:
	for frame in count:
		await super._step()
		if is_instance_valid(player):
			if player.is_wall_grabbing() and player.velocity.y < -100:
				wall_frames += 1
			rest_frames = rest_frames + 1 if player.is_on_floor() and absf(player.position.y - 184) < 2 and player.get_wall_stamina() > 2.9 else 0
			if not captured_rest and rest_frames >= 3:
				captured_rest = true
				_capture("rest")
