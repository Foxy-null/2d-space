extends "res://tests/stage_2_test.gd"

var companion: Grabbable
var companion_jumps := 0
var restored_position := Vector2.ZERO
var restored_jumps := 0
var captured_rest := false


func _run() -> void:
	stage = load("res://scenes/stage_2.tscn").instantiate()
	root.add_child(stage)
	player = stage.player
	companion = stage.get_node("Items/Item20")
	player.respawned.connect(func():
		respawns += 1
		restored_position = companion.position
		restored_jumps = companion.extra_jump_count())
	player.movement_action.connect(func(action: String):
		if action == "creature_jump":
			companion_jumps += 1)
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	if not screenshots:
		await _bypasses()
		await _carry_fall()
	for jump_delay in ([20] if screenshots else [16, 20, 24]):
		for dash_delay in ([20] if screenshots else [16, 20, 24]):
			await _enter()
			_capture("entrance")
			await _companion_course(jump_delay, dash_delay)
			_check(companion_jumps == 2 and respawns == 0, "Two real carried jumps cross with timing variation")
	_capture("checkpoint")
	_release()
	await _pulse("reset")
	await _step(6)
	_check(stage.checkpoint_index == 5 and player.position.distance_to(Vector2(900, -2986)) < 2, "Retry while carrying keeps checkpoint 06")
	print("TOWER_COMPANION_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)


func _enter() -> void:
	_release()
	stage._set_checkpoint(4)
	player.respawn()
	await _step(6)
	respawns = 0
	companion_jumps = 0


func _bypasses() -> void:
	for held in [false, true]:
		for start_x in ([280, 360, 460] if held else [280, 360, 390]):
			for direction in _directions():
				for dash_frame in [-1, 0, 12, 20, 28, 40]:
					await _attempt(held, false, start_x, direction, dash_frame)
			print("TOWER_COMPANION_BYPASSES held=%s start=%d: 48 attempts" % [held, start_x])
	for pickup in [false, true]:
		for direction in _directions():
			for dash_frame in [-1, 0, 12, 20, 28, 40]:
				await _attempt(pickup, true, 450, direction, dash_frame)
		print("TOWER_COMPANION_BYPASSES step+pickup=%s: 48 attempts" % pickup)


func _attempt(held: bool, stepped: bool, start_x: int, direction: Vector2, dash_frame: int) -> void:
	await _enter()
	if stepped:
		await _stand_on_companion()
	else:
		if held:
			Input.action_press("wall_grab")
			await _step(2)
		for frame in 90:
			var dx := start_x - player.position.x
			if absf(dx) < 10 and player.is_on_floor():
				break
			_set_direction(Vector2(signf(dx), 0))
			await _step()
		_set_direction(Vector2.ZERO)
		await _step(10)
		_check(player.is_on_floor() and absf(player.position.x - start_x) < 35, "The bypass reaches its live launch point")
	if held:
		Input.action_press("wall_grab")
	await _pulse("jump")
	if held:
		_check(player.get_held_object() == companion, "The bypass really grabs the companion")
	var reached := false
	var highest := player.position.y
	var grabbed := player.get_held_object() != null
	for frame in 180:
		Input.action_release("jump")
		_set_direction(Vector2(600 - player.position.x, -1))
		# Try the terrain's side; carrying disables wall actions naturally.
		if held or player.position.distance_to(companion.position) > 110:
			Input.action_press("wall_grab")
		else:
			Input.action_release("wall_grab")
		if frame == dash_frame:
			_set_direction(direction)
			await _pulse("dash")
		if player.is_on_wall() and frame % 18 == 0:
			Input.action_press("jump")
		await _step()
		if respawns > 0:
			break
		highest = minf(highest, player.position.y)
		grabbed = grabbed or player.get_held_object() != null
		reached = reached or (player.is_on_floor() and player.position.y < -2600) or stage.checkpoint_index > 4
	_check(not reached and companion_jumps == 0, "A floor/step/pickup/dash/wall bypass without the carried jump cannot reach the landing: held=%s stepped=%s start=%d direction=%s frame=%d" % [held, stepped, start_x, direction, dash_frame])
	if not held:
		_check(not grabbed, "The unheld bypass never grabs the companion")
	if stepped and direction == Vector2.UP and dash_frame == 20:
		print("TOWER_COMPANION_STEP_RISE %.2f pickup=%s" % [-2266.0 - highest, held])
	_release()


func _stand_on_companion() -> void:
	await _pulse("jump")
	var stood := false
	for frame in 100:
		var dx := companion.position.x - player.position.x
		_set_direction(Vector2(signf(dx) if absf(dx) > 8 else 0.0, 0))
		await _step()
		if player.is_on_floor() and player.position.y < -2300:
			stood = true
			break
	_set_direction(Vector2.ZERO)
	await _step(4)
	_check(stood and player.is_on_floor(), "A live jump stands on the companion before the bypass")


func _carry_fall() -> void:
	await _enter()
	Input.action_press("wall_grab")
	await _step(2)
	_check(player.get_held_object() == companion, "The fall begins with a real safe-floor grab")
	Input.action_press("move_right")
	await _pulse("jump")
	await _step(20)
	await _pulse("jump")
	_check(companion_jumps == 1 and companion.extra_jump_count() == 0, "The carried fall consumes the companion's real jump")
	for frame in 240:
		await _step()
		if respawns > 0:
			break
	_release()
	await _step(60)
	_check(respawns == 1 and stage.checkpoint_index == 4 and player.is_on_floor(), "Falling while carrying returns to the safe checkpoint")
	_check(restored_position.distance_to(Vector2(450, -2273)) < 1 and restored_jumps == 1, "The retry restores the companion's initial position and jump count")
	_check(is_instance_valid(companion) and companion.extra_jump_count() == 1 and companion.position.x > 240 and companion.position.x < 480 and companion.position.y > -2380 and companion.position.y < -2240, "The restored companion remains available on the entrance")
	_check(player.is_dash_ready() and player.get_wall_stamina() > 2.9, "The carried retry restores movement resources")


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
		root.get_texture().get_image().save_png("/tmp/tower-companion-%s.png" % label)


func _step(count: int = 1) -> void:
	await super._step(count)
	if is_instance_valid(player) and not captured_rest and player.is_on_floor() and absf(player.position.y + 2696) < 2:
		captured_rest = true
		_capture("rest")
