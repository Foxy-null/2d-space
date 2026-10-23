extends "res://tests/stage_2_test.gd"

var dash_count := 0
var crystal_count := 0
var captured_chain := false


func _run() -> void:
	stage = load("res://scenes/stage_2.tscn").instantiate()
	root.add_child(stage)
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action: String):
		if action == "dash":
			dash_count += 1)
	for name in ["Item2", "Item3", "Item4"]:
		stage.get_node("Items/" + name).collected.connect(func(_body: PlayerController):
			crystal_count += 1)
	if not OS.get_cmdline_user_args().has("--screenshots"):
		await _bypasses()
		await _stop_after_refill()
	await _enter()
	_capture("entrance")
	await _dash_course()
	_check(dash_count == 4 and crystal_count == 3 and respawns == 0, "The airborne route uses three refills and four actual dashes without retry")
	_capture("checkpoint")
	await _pulse("reset")
	await _step(6)
	_check(stage.checkpoint_index == 3 and player.position.distance_to(Vector2(900, -1546)) < 2, "Retry after the chain keeps checkpoint 04")
	print("TOWER_DASH_ROUTE_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)


func _enter() -> void:
	_release()
	stage._set_checkpoint(2)
	player.respawn()
	await _step(6)
	respawns = 0
	dash_count = 0
	crystal_count = 0


func _bypasses() -> void:
	for active in [false, true]:
		for name in ["Item2", "Item3", "Item4"]:
			stage.get_node("Items/" + name).collision_mask = 1 if active else 0
		for start_x in [260, 360, 460]:
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				for dash_frame in [-1, 0, 12, 24, 36, 48]:
					await _attempt(active, start_x, direction, dash_frame)
			print("TOWER_DASH_BYPASSES crystals=%s start=%d: 48 attempts" % [active, start_x])


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
	_check(absf(player.position.x - start_x) < 35 and player.is_on_floor(), "The bypass launch point is reached by live input")
	await _pulse("jump")
	var reached := false
	for frame in 180:
		Input.action_release("jump")
		_set_direction(Vector2(740 - player.position.x, -1))
		Input.action_press("wall_grab")
		if frame == dash_frame or (not active and dash_frame >= 0 and frame > dash_frame and frame % 18 == 0):
			_set_direction(direction)
			await _pulse("dash")
		if player.is_on_wall() and frame % 18 == 0:
			Input.action_press("jump")
		await _step()
		reached = reached or player.position.y < -1460 or stage.checkpoint_index > 2
		if respawns > 0:
			break
	_check(not reached and (not active or dash_count <= 1), "An unrefilled/single dash cannot reach the exit: active=%s start=%d direction=%s frame=%d" % [active, start_x, direction, dash_frame])
	if not active:
		_check(crystal_count == 0, "Disabled crystals do not refill the bypass dash")
	_release()


func _stop_after_refill() -> void:
	await _enter()
	await _dash_launch()
	_release()
	_check(crystal_count == 1 and dash_count == 1 and player.is_dash_ready(), "The first real crystal restores an available dash")
	for frame in 180:
		await _step()
		if respawns > 0:
			break
	_release()
	await _step(8)
	_check(respawns == 1 and stage.checkpoint_index == 2, "Skipping the refilled dash falls back to checkpoint 03")
	_check(player.is_on_floor() and player.position.distance_to(Vector2(360, -826)) < 2, "The retry leaves a safe standing restart")
	for name in ["Item2", "Item3", "Item4"]:
		_check(stage.get_node("Items/" + name).visible, "Retry restores every crystal, including " + name)
	_check(player.is_dash_ready() and player.get_wall_stamina() > 2.9, "Retry restores movement resources")


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
		root.get_texture().get_image().save_png("/tmp/tower-dash-%s.png" % label)


func _step(count: int = 1) -> void:
	await super._step(count)
	if is_instance_valid(player) and not captured_chain and dash_count == 3 and player.position.y < -1280:
		captured_chain = true
		_capture("chain")
