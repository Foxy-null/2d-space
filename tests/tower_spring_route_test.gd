extends "res://tests/stage_2_test.gd"

var spring_launches := 0
var captured_rest := false


func _run() -> void:
	stage = load("res://scenes/stage_2.tscn").instantiate()
	root.add_child(stage)
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	for name in ["Item19", "Item0"]:
		stage.get_node("Items/" + name).launched.connect(func(_body: PlayerController): spring_launches += 1)
	if not OS.get_cmdline_user_args().has("--screenshots"):
		await _bypasses()
		await _fall_retry()
	await _enter()
	_capture("entrance")
	await _spring_course()
	_check(spring_launches == 2 and respawns == 0, "The intended route uses both springs without a retry")
	_capture("checkpoint")
	await _pulse("reset")
	await _step(6)
	_check(stage.checkpoint_index == 2 and player.position.distance_to(Vector2(360, -826)) < 2, "Retry keeps checkpoint 03 after the spring section")
	_release()
	print("TOWER_SPRING_ROUTE_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)


func _enter() -> void:
	_release()
	stage._set_checkpoint(1)
	player.respawn()
	await _step(6)
	respawns = 0
	spring_launches = 0


func _bypasses() -> void:
	stage.get_node("Items/Item19").collision_mask = 0
	for start_x in [800, 900, 1000, 1150]:
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			for dash_frame in [-1, 0, 12, 24, 36, 48]:
				await _attempt(start_x, direction, dash_frame)
		print("TOWER_SPRING_BYPASSES start=%d: 48 attempts" % start_x)
	stage.get_node("Items/Item19").collision_mask = 1


func _attempt(start_x: int, direction: Vector2, dash_frame: int) -> void:
	await _enter()
	# Reach the launch point with live controls, including the lower outer-wall cap.
	for frame in 120:
		var dx := start_x - player.position.x
		if absf(dx) < 10 and player.is_on_floor():
			break
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 8:
			Input.action_press("move_right" if dx > 0 else "move_left")
		if start_x == 1150 and player.position.x > 975 and player.is_on_floor():
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		await _step()
	_release()
	await _step(10)
	_check(absf(player.position.x - start_x) < 35 and player.is_on_floor(), "The bypass starts on its real reachable launch point: %d" % start_x)
	var reached := false
	await _pulse("jump")
	for frame in 150:
		Input.action_release("jump")
		_set_direction(Vector2(730 - player.position.x, -1))
		Input.action_press("wall_grab")
		if frame == dash_frame:
			_set_direction(direction)
			await _pulse("dash")
		# Actively try a wall kick, then return to the inner landing's side.
		if player.is_on_wall() and frame % 18 == 0:
			Input.action_press("jump")
		await _step()
		reached = reached or player.position.y < -475 or stage.checkpoint_index > 1
		if respawns > 0:
			break
	_check(not reached and spring_launches == 0, "No-spring jump/dash/wall bypass stays below the landing: start=%d direction=%s dash_frame=%d" % [start_x, direction, dash_frame])
	_release()


func _fall_retry() -> void:
	await _enter()
	Input.action_press("move_left")
	for frame in 180:
		await _step()
		if respawns > 0:
			break
	_release()
	await _step(8)
	_check(respawns == 1 and stage.checkpoint_index == 1, "Missing the spring returns to checkpoint 02")
	_check(player.is_on_floor() and player.position.distance_to(Vector2(900, -106)) < 4, "The fall leaves a safe standing restart")
	_check(spring_launches == 0 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "Fall restores resources without granting spring progress")


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
		root.get_texture().get_image().save_png("/tmp/tower-spring-%s.png" % label)


func _step(count: int = 1) -> void:
	await super._step(count)
	if is_instance_valid(player) and not captured_rest and player.is_on_floor() and absf(player.position.y + 556) < 2:
		captured_rest = true
		_capture("rest")
