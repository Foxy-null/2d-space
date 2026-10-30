extends "res://tests/stage_2_test.gd"

var extra_jumps := 0
var boots := 0
var captured_rest := false


func _run() -> void:
	stage = load("res://scenes/stage_2.tscn").instantiate()
	root.add_child(stage)
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action: String):
		if action == "air_jump":
			extra_jumps += 1)
	for name in ["Item5", "Item6"]:
		stage.get_node("Items/" + name).collected.connect(func(_body: PlayerController): boots += 1)
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	if not screenshots:
		await _bypasses()
		await _collect_then_fall()
	for jump_delay in ([20] if screenshots else [16, 20, 24]):
		for dash_delay in ([20] if screenshots else [16, 20, 24]):
			await _enter()
			_capture("entrance")
			await _extra_jump_course(jump_delay, dash_delay)
			_check(extra_jumps == 2 and boots == 2 and respawns == 0, "Two real boots and extra jumps cross with timing variation without retry")
	_capture("checkpoint")
	await _pulse("reset")
	await _step(6)
	_check(stage.checkpoint_index == 4 and player.position.distance_to(Vector2(360, -2266)) < 2, "Retry after the route keeps checkpoint 05")
	print("TOWER_EXTRA_JUMP_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)


func _enter() -> void:
	_release()
	stage._set_checkpoint(3)
	player.respawn()
	await _step(6)
	respawns = 0
	extra_jumps = 0
	boots = 0


func _bypasses() -> void:
	for active in [false, true]:
		for name in ["Item5", "Item6"]:
			stage.get_node("Items/" + name).collision_mask = 1 if active else 0
		for start_x in [800, 900, 1000]:
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				for dash_frame in [-1, 0, 12, 20, 28, 40]:
					await _attempt(active, start_x, direction, dash_frame)
			print("TOWER_EXTRA_JUMP_BYPASSES boots=%s start=%d: 48 attempts" % [active, start_x])


func _attempt(active: bool, start_x: int, direction: Vector2, dash_frame: int) -> void:
	await _enter()
	for frame in 90:
		var dx := start_x - player.position.x
		if absf(dx) < 10 and player.is_on_floor():
			break
		_set_direction(Vector2(signf(dx), 0))
		await _step()
	_release()
	await _step(10)
	_check(absf(player.position.x - start_x) < 35 and player.is_on_floor(), "The bypass reaches its real launch point")
	await _pulse("jump")
	var reached := false
	for frame in 180:
		Input.action_release("jump")
		_set_direction(Vector2(650 - player.position.x, -1))
		Input.action_press("wall_grab")
		if frame == dash_frame:
			_set_direction(direction)
			await _pulse("dash")
		if player.is_on_wall() and frame % 18 == 0:
			Input.action_press("jump")
		await _step()
		reached = reached or player.position.y < -1916 or stage.checkpoint_index > 3
		if respawns > 0:
			break
	_check(not reached and extra_jumps == 0, "A jump/dash/wall bypass without an extra jump stays below the first landing: active=%s start=%d direction=%s frame=%d" % [active, start_x, direction, dash_frame])
	if not active:
		_check(boots == 0, "Disabled boots cannot grant a jump")
	_release()


func _collect_then_fall() -> void:
	await _enter()
	Input.action_press("move_right")
	for frame in 90:
		if player.position.x >= 950:
			break
		await _step()
	_release()
	await _step(12)
	Input.action_press("move_left")
	await _pulse("jump")
	for frame in 30:
		await _step()
		if boots > 0:
			break
	_check(boots == 1 and player.is_air_jump_ready(), "A real jump collects the first boot before the fall")
	for frame in 180:
		await _step()
		if respawns > 0:
			break
	_release()
	await _step(8)
	_check(respawns == 1 and extra_jumps == 0 and stage.checkpoint_index == 3, "Skipping the extra jump returns to checkpoint 04")
	_check(player.is_on_floor() and player.position.distance_to(Vector2(900, -1546)) < 4, "Falling restores a safe standing start")
	for name in ["Item5", "Item6"]:
		_check(stage.get_node("Items/" + name).visible, "Respawn restores " + name)
	_check(not player.is_air_jump_ready() and player.is_dash_ready(), "Respawn clears the unused extra jump and restores the dash")


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
		root.get_texture().get_image().save_png("/tmp/tower-extra-jump-%s.png" % label)


func _step(count: int = 1) -> void:
	await super._step(count)
	if is_instance_valid(player) and not captured_rest and player.is_on_floor() and absf(player.position.y + 1986) < 2:
		captured_rest = true
		_capture("rest")
