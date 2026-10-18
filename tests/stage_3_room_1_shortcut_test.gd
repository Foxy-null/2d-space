extends "res://tests/stage_3_test.gd"

var trials := 0
var intercepted := 0
var fell_out := 0
var attempt_respawns := 0
var wall_shift := 0.0


func _run() -> void:
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(3)
	stage = current_scene
	player = stage.player
	player.gravity_changed.connect(func(inverted: bool): flips.append(-1 if inverted else 1))
	player.respawned.connect(func(): respawns += 1)
	wall_shift = stage.rooms.get_child(0).get_node("RightKickWall").position.x - 662
	_check(stage.rooms.get_child(0).get_node("UpGate/CollisionShape2D").shape.size == Vector2(64, 160), "Room 1 Up gate uses the original, small size")
	_check(stage.rooms.get_child(0).get_node("DownGate/CollisionShape2D").shape.size == Vector2(64, 160), "Room 1 Down gate retains its original size")
	_check(stage.rooms.get_child(1).get_node("UpGate/CollisionShape2D").shape.size == Vector2(64, 160), "Room 2 retains the shared gate's original size")
	await _prepare()
	await _climb_second_wall(false)
	_release_inputs()
	# Let the reported drop finish without steering toward the gate. The old
	# full floor lets the same input continue to the arrival switch below.
	for frame in 120:
		if respawns > attempt_respawns or (player.is_on_floor() and player.position.y > 600):
			break
		await _step()
	if stage.rooms.get_child(0).has_node("ReturnBridge"):
		_check(respawns > attempt_respawns and flips.is_empty(), "The reported drop falls into the pit without touching a gravity gate")
		_check(player.position.distance_to(stage.rooms.get_child(0).get_node("Spawn").position) < 20, "The pit returns to the entrance")
		_check(player.gravity_direction == 1 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "The pit restores gravity, dash and wall stamina")
	await _attempt_exit("climb and drop")
	for offset in [0, 12, 24]:
		await _prepare()
		await _climb_second_wall(true, offset)
		_drive("move_right")
		await _jump()
		await _attempt_exit("ordinary jump, offset=%d" % offset)
		for direction in ["right", "up", "diagonal"]:
			for delay in [0, 3, 6, 8, 10, 12, 14, 18, 24, 28, 34, 40, 50, 60]:
				await _prepare()
				await _climb_second_wall(true, offset)
				await _jump()
				await _step(delay)
				await _dash(direction)
				await _attempt_exit("jump + %s dash, offset=%d delay=%d" % [direction, offset, delay])
			for delay in [0, 6, 12, 24]:
				await _prepare()
				await _climb_second_wall(true, offset)
				_drive("move_right")
				await _step(delay)
				await _dash(direction)
				await _attempt_exit("walk off + %s dash, offset=%d delay=%d" % [direction, offset, delay])
	# The taller first wall offers another launch point above the gate.
	for height in [-20, 35, 60, 120, 200]:
		for direction in ["right", "up", "diagonal"]:
			for delay in [0, 10, 20, 30]:
				await _prepare()
				_drive("move_right")
				await _until(func(): return player.is_on_wall() and _x() > 600 + wall_shift, 240, "Reach second wall from spawn")
				_drive("move_left", true)
				await _until(func(): return player.is_wall_grabbing() and player.position.y < 350, 80, "Climb before kicking onto first wall")
				await _jump()
				await _until(func(): return player.is_wall_grabbing() and _x() < 500 + wall_shift, 130, "Reach first wall with a real wall kick")
				await _until(func(): return player.position.y <= height, 120, "Climb first wall to launch height")
				_drive("move_right", true)
				await _jump()
				_drive("move_right")
				await _step(delay)
				await _dash(direction)
				await _attempt_exit("high wall kick + %s dash, height=%d delay=%d" % [direction, height, delay])
	_release_inputs()
	print("STAGE_3_ROOM_1_SHORTCUT_TEST_%s (%d trials, %d intercepted, %d fell out, %d checks)" % ["FAILED" if failed else "OK", trials, intercepted, fell_out, checks])
	quit(1 if failed else 0)


func _prepare() -> void:
	if failed:
		quit(1)
		return
	await _retry()
	flips.clear()
	attempt_respawns = respawns


func _climb_second_wall(stop_on_top: bool, offset := 0) -> void:
	_drive("move_right")
	await _until(func(): return player.is_on_wall() and _x() > 600 + wall_shift, 240, "Reach second wall using the floor Spring")
	_drive("move_right", true)
	if stop_on_top:
		await _until(func(): return player.is_on_floor() and player.position.y < 310, 180, "Climb onto second wall without a wall kick")
		if offset > 0:
			await _until(func(): return _x() >= 669 + wall_shift + offset, 20, "Walk toward the edge before jumping")
		_release_inputs()
		await _step(3)
	else:
		await _until(func(): return _x() > 704 + wall_shift, 180, "Climb over second wall")


func _dash(direction: String) -> void:
	_release_inputs()
	if direction != "up":
		Input.action_press("move_right")
	if direction != "right":
		Input.action_press("move_up")
	Input.action_press("dash")
	await _step(10)
	_drive("move_right")


func _attempt_exit(label: String) -> void:
	trials += 1
	for frame in 240:
		if flips.has(-1) or respawns > attempt_respawns or stage.cleared.has(0):
			break
		_drive("move_right")
		if _x() >= 1140:
			_release_inputs()
		elif player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_check(not stage.cleared.has(0), "No gravity-free clear: " + label)
	_check(flips.has(-1) or respawns > attempt_respawns, "Attempt actually encounters Up gravity or falls out: " + label)
	if flips.has(-1):
		intercepted += 1
	else:
		fell_out += 1
	if failed:
		print("SHORTCUT_FAILURE ", label, " position=", player.position, " flips=", flips)
		_release_inputs()
		quit(1)
