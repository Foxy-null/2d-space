extends "res://tests/stage_3_test.gd"
const DIRECTIONS := [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1),
	Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]
var raw := 1.0
var landed := false


func _run() -> void:
	if not OS.get_cmdline_user_args().has("--routes-only"):
		if not OS.get_cmdline_user_args().has("--remaining-only"):
			await _alternatives()
		await _roof_alternative()
		await _superdash_alternatives()
	for strength in [1.0, 0.85]:
		raw = strength
		for delay in [16, 20, 24]:
			await _prepare_room()
			var started := Engine.get_physics_frames()
			await _approach()
			await _spring_route(delay)
			_check(stage.cleared.has(4) and respawns == 0, "The actual airborne Spring reaches arrival without a fall")
			_check(actions.get("exit_spring", 0) == 1 and actions.get("wall_jump", 0) >= 1 and actions.get("dash", 0) == (2 if raw < 1 else 1), "The route really uses its Spring, initial wall kick and downward dash")
			_check(flips == [-1, 1], "The moving Up gate and final Down gate both activate")
			var seconds := (Engine.get_physics_frames() - started) / 60.0
			_check(seconds <= 30, "The room remains below thirty seconds")
			print("ROOM5_SPRING raw=%.2f delay=%d seconds=%.2f deaths=%d" % [raw, delay, seconds, respawns])
	await _backtrack()
	await _retries()
	_release_inputs()
	print("GRAVITY_ROOM_FIVE_SPRING_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _normal_cap(launch: float = 388) -> void:
	_drive("move_right", true)
	await _until(func(): return player.is_on_floor() and _x() > 350 and player.position.y < 425, 240, "Climb onto the actual normal-gravity launch-wall cap")
	_drive("move_right")
	await _until(func(): return _x() >= launch, 60, "Reach the real cap or coyote takeoff")


func _alternatives() -> void:
	raw = 1
	for mode in ["cap", "coyote", "ceiling"]:
		for delay in [0, 16, 32, 48, 60]:
			for direction in DIRECTIONS:
				await _prepare_room()
				if mode == "ceiling":
					await _approach()
					_drive("move_right")
					await _until(func(): return _x() >= 900, 100, "Reach the real inverted takeoff")
				else:
					await _normal_cap(412 if mode == "coyote" else 388)
				var before: int = actions.get("jump", 0)
				await _jump()
				_check(actions.get("jump", 0) == before + 1, "The alternative begins with a real ordinary or coyote jump")
				await _step(delay)
				if respawns == 0:
					_aim(direction)
					await _dash()
					_drive("move_right", true, player.gravity_direction < 0)
					await _observe_alternative()
				_check((not landed and not stage.cleared.has(4)) or actions.has("exit_spring"), "An ordinary jump and late eight-way dash cannot land or clear without the actual Spring")
			print("ROOM5_ALTERNATIVES mode=%s delay=%d" % [mode, delay])


func _observe_alternative() -> void:
	for frame in 240:
		landed = landed or _on_exit_floor()
		if respawns > 0 or landed or stage.cleared.has(4) or stage.room_index != 4:
			break
		Input.action_release("jump")
		if player.is_on_wall() and not player.is_on_floor() and not player.is_dashing():
			Input.action_press("jump")
		await _step()
	_release_inputs()


func _roof_alternative() -> void:
	await _prepare_room()
	await _normal_cap()
	_release_inputs()
	await _step(12)
	await _jump()
	await _step(20)
	_aim(Vector2.UP)
	await _dash()
	_drive("move_left", true)
	for frame in 150:
		await _step()
		if respawns > 0 or (player.is_on_floor() and player.position.y < 40):
			break
	if player.is_on_floor() and player.position.y < 40 and respawns == 0:
		_drive("move_right")
		await _until(func(): return _x() >= 320, 100, "Walk to the old real roof edge")
		await _dash()
		await _observe_alternative()
	_check(not landed and not stage.cleared.has(4) and not actions.has("exit_spring"), "The old normal-gravity roof route cannot reach the exit")
	_check(respawns == 1, "The thick roof sends the old upper escape into the existing ceiling retry boundary")


func _superdash_alternatives() -> void:
	for mode in ["cap", "ceiling"]:
		for delay in ([0] if mode == "cap" else [0, 4, 8]):
			await _prepare_room()
			if mode == "cap":
				await _normal_cap(370)
			else:
				await _approach()
			_drive("move_right")
			await _dash()
			await _step(delay)
			await _jump()
			_check(actions.has("superdash"), "The alternative really performs a ground Dash-to-Jump")
			_drive("move_right", true, player.gravity_direction < 0)
			await _observe_alternative()
			_check((not landed and not stage.cleared.has(4)) or actions.has("exit_spring"), "A real Superdash cannot replace the airborne Spring")


func _at_spawn() -> bool:
	return stage.room_index == 4 and player.position.distance_to(stage.rooms.get_child(4).get_node("Spawn").global_position) < 20 and player.gravity_direction == 1 and player.is_dash_ready() and player.get_wall_stamina() > 2.9


func _retries() -> void:
	raw = 1
	await _prepare_room()
	await _approach()
	_release_inputs()
	await _step(180)
	_check(player.is_on_floor() and player.gravity_direction == -1 and respawns == 0, "The middle ceiling permits three seconds of safe observation")
	await _key(KEY_R)
	_check(_at_spawn() and not stage.cleared.has(4), "Real R resets the moving gate, gravity and resources before arrival")
	for after_down in [false, true]:
		await _prepare_room()
		await _approach()
		_drive("move_right")
		await _until(func(): return _x() >= 914, 100, "Reach the actual Spring takeoff for immediate R")
		await _jump()
		await _step(20)
		_aim(Vector2.DOWN)
		await _dash()
		_release_inputs()
		await _until(func(): return actions.has("exit_spring"), 180, "Actually rebound before pressing R")
		if after_down:
			_drive("move_right")
			await _until(func(): return player.gravity_direction == 1, 120, "Actually enter Down gravity before R")
		_release_inputs()
		await _key(KEY_R)
		await _step(6)
		_check(_at_spawn() and not stage.cleared.has(4), "R immediately after an actual Spring or Down gate cannot reapply its old motion")
		var gate: Area2D = stage.rooms.get_child(4).get_node("UpGate")
		_check(gate.position.distance_to(gate.get("_initial_position")) < 25, "Real R restarts the moving entrance gate")
	for ceiling in [false, true]:
		await _prepare_room()
		if ceiling:
			await _approach()
		else:
			await _normal_cap()
		_drive("move_right")
		await _until(func(): return respawns > 0, 300, "Walking off the real floor or ceiling reaches the existing fall boundary")
		_release_inputs()
		_check(_at_spawn() and not stage.cleared.has(4), "Both real falls retry the unfinished room without moving the checkpoint")


func _backtrack() -> void:
	var before := respawns
	_drive("move_right")
	await _until(func(): return stage.room_index == 5 and not stage.transitioning, 180, "The actual open exit reaches Room6")
	_drive("move_left")
	await _until(func(): return stage.room_index == 4 and not stage.transitioning, 180, "Room6 returns to Room5")
	_release_inputs()
	_check(respawns == before + 2 and stage.cleared.has(4) and _x() > 1200 and player.is_on_floor(), "Both real transitions retain arrival and use the safe return checkpoint")
	for frame in 600:
		if stage.room_index == 3 and not stage.transitioning:
			break
		_drive("move_left", true, player.gravity_direction < 0)
		await _step()
	_release_inputs()
	_check(stage.room_index == 3 and respawns == before + 3 and player.is_on_floor(), "The completed return bridge walks safely to Room4 without a fall")


func _prepare_room() -> void:
	_release_inputs()
	if is_instance_valid(stage):
		stage.free()
	stage = load("res://scenes/stage_3.tscn").instantiate()
	root.add_child(stage)
	player = stage.player
	player.movement_action.connect(func(a: String): actions[a]=actions.get(a, 0)+1)
	player.gravity_changed.connect(func(inverted: bool): flips.append(-1 if inverted else 1))
	player.respawned.connect(func(): respawns+=1)
	stage.rooms.get_child(4).get_node("ExitSpring").launched.connect(func(_body): actions["exit_spring"]=actions.get("exit_spring", 0)+1)
	stage.cleared[3]=true
	stage._set_room(3, false)
	player.respawn()
	await _step()
	stage._set_room(4, false)
	player.respawn()
	await _step(6)
	actions.clear()
	flips.clear()
	respawns = 0
	landed = false


func _approach() -> void:
	await _kick_gate(360, -1, "UpGate")
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() >= 330, 200, "Reach the late ordinary takeoff against the headwind")
	await _jump()
	if raw < 1:
		await _step(16)
		_aim(Vector2.RIGHT)
		await _dash()
		_drive("move_right")
	await _until(func(): return player.is_on_floor() and _x() > 470, 150, "The late jump crosses the first ceiling gap with weak input")
	_drive("move_right")
	for frame in 180:
		var braking: float = player.velocity.x * player.velocity.x / (2 * player.ground_acceleration)
		if player.is_on_floor() and _x() >= 800 - braking:
			break
		await _step()
	_release_inputs()
	await _step(30)
	_check(player.is_on_floor() and player.gravity_direction == -1 and respawns == 0, "The wide middle ceiling is a safe place to observe the airborne Spring")


func _spring_route(delay: int) -> void:
	_drive("move_right")
	await _until(func(): return _x() >= (930 if raw < 1 else 914), 160, "Walk to the fixed Spring takeoff")
	await _jump()
	_check(actions.get("jump", 0) == 2, "The final takeoff is an actual ordinary or coyote jump")
	await _step(delay)
	_aim(Vector2.DOWN)
	await _dash()
	_release_inputs()
	await _until(func(): return actions.has("exit_spring") or respawns > 0, 180, "The downward dash passes below the Spring and natural inverted gravity returns into it")
	_check(actions.has("exit_spring") and respawns == 0, "The actual Spring must fire before reaching the exit")
	await _finish()


func _finish() -> void:
	_drive("move_right")
	for frame in 300:
		landed = landed or _on_exit_floor()
		if respawns > 0 or stage.cleared.has(4):
			break
		Input.action_release("jump")
		if _x() >= 1140:
			_release_inputs()
		elif player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release_inputs()


func _on_exit_floor() -> bool:
	if not player.is_on_floor():
		return false
	for i in player.get_slide_collision_count():
		if player.get_slide_collision(i).get_collider() == stage.rooms.get_child(4).get_node("ExitFloor"):
			return true
	return false


func _drive(direction: String, grab := false, inverted := false) -> void:
	_release_inputs()
	_joy(JOY_AXIS_LEFT_X, raw * (-1 if direction == "move_left" else 1))
	if grab:
		Input.action_press("wall_grab")
		Input.action_press("move_down" if inverted else "move_up")


func _aim(direction: Vector2) -> void:
	_release_inputs()
	_joy(JOY_AXIS_LEFT_X, direction.x * raw)
	_joy(JOY_AXIS_LEFT_Y, direction.y * raw)


func _dash() -> void:
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")


func _joy(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release_inputs() -> void:
	super._release_inputs()
	_joy(JOY_AXIS_LEFT_X, 0)
	_joy(JOY_AXIS_LEFT_Y, 0)


func _check(condition: bool, message: String) -> void:
	super._check(condition, message)
	if not condition:
		quit(1)
