extends "res://tests/stage_3_test.gd"

const DIRECTIONS := [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1),
	Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]

var raw := 1.0
var anchor := 785.0
var hazard_hits := 0
var captured_boots := 0
var floor_hits := 0
var alternative_landed := false


func _run() -> void:
	if not OS.get_cmdline_user_args().has("--routes-only"):
		await _inverted_alternatives()
		await _normal_alternatives()
		await _late_floor_dashes()
		await _superdash_alternatives()
	for strength in [1.0, 0.85]:
		raw = strength
		for first in [16, 20, 24]:
			for second in [16, 20, 24]:
				await _prepare_room()
				var started := Engine.get_physics_frames()
				await _approach()
				await _route(first, second)
				_check(stage.cleared.has(2) and respawns == 0, "Both jumps and a downward dash reach the real arrival without a retry")
				_check(actions.get("air_jump", 0) == 1 and actions.get("jump_crystal", 0) == 1 and actions.get("dash", 0) == 1, "The normal route actually spends its one acquired jump and one dash")
				_check(flips == [-1, 1] and not player.is_air_jump_ready(), "The actual Up and Down gates return to ordinary gravity with the boot spent")
				var seconds := (Engine.get_physics_frames() - started) / 60.0
				_check(seconds <= 30, "The room stays below thirty seconds")
				print("ROOM3_JUMP raw=%.2f gaps=%d/%d seconds=%.2f deaths=%d" % [raw, first, second, seconds, respawns])
	await _backtrack_room()
	await _retries()
	_release_inputs()
	print("GRAVITY_ROOM_THREE_JUMP_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _approach() -> void:
	await _kick_gate(240, -1)
	await _cross_ceiling_pit(330, 470)
	_drive("move_right")
	for frame in 180:
		var stop_distance := player.velocity.x * player.velocity.x / (2 * player.ground_acceleration)
		if player.is_on_floor() and _x() >= anchor - stop_distance:
			break
		await _step()
	_release_inputs()
	await _step(30)
	_check(player.is_on_floor() and player.gravity_direction == -1 and respawns == 0 and not player.is_air_jump_ready(), "The wide middle ceiling safely overlooks the boot and hanging spikes")
	if raw < 1:
		_joy(JOY_AXIS_LEFT_X, raw)
		_check(is_equal_approx(Input.get_axis("move_left", "move_right"), 0.7), "Raw stick 0.85 keeps the real deadzone-adjusted 0.7 input")
		_release_inputs()


func _route(first: int, second: int) -> void:
	await _jump()
	await _step(first)
	_check(player.is_air_jump_ready() and not player.is_on_floor(), "An ordinary inverted jump really collects the airborne boot")
	await _jump()
	await _step(second)
	_check(actions.has("air_jump") and not player.is_air_jump_ready(), "The next jump spends the acquired right before the dash")
	_aim(Vector2.DOWN)
	await _dash()
	_release_inputs()
	await _until(func(): return player.position.y >= 500 or respawns > 0, 90, "The two jumps and downward dash get below the hanging spikes")
	await _finish()


func _finish() -> void:
	_drive("move_right")
	for frame in 300:
		if respawns > 0 or stage.cleared.has(2):
			break
		Input.action_release("jump")
		if _x() >= 1140:
			_release_inputs()
		elif player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release_inputs()


func _inverted_alternatives() -> void:
	raw = 1
	for launch in [620, 735, 790]:
		for delay in [0, 16, 32, 48]:
			for direction in DIRECTIONS:
				await _prepare_room()
				await _kick_gate(240, -1)
				await _cross_ceiling_pit(330, 470)
				_drive("move_right")
				await _until(func(): return _x() >= launch, 180, "Reach the real inverted takeoff")
				await _jump()
				await _step(delay)
				_aim(direction)
				await _dash()
				_drive("move_right", true, true)
				await _observe_alternative()
				_check(not alternative_landed and not stage.cleared.has(2) and not actions.has("air_jump"), "A normal jump and any late dash cannot replace the airborne jump")
				captured_boots += int(actions.has("jump_crystal"))
		print("ROOM3_NO_AIR_INVERTED launch=%d" % launch)
	_check(captured_boots > 0, "No-air-jump alternatives include actual crystal collections with an unused right")


func _normal_alternatives() -> void:
	raw = 1
	for launch in [270, 315]:
		for delay in [0, 16, 32, 48]:
			for direction in DIRECTIONS:
				await _prepare_room()
				_drive("move_right", true)
				await _until(func(): return player.is_on_floor() and player.position.y < 410 and _x() > 240, 180, "Climb onto the actual launch-wall cap without flipping")
				_drive("move_right")
				await _until(func(): return _x() >= launch, 60, "Walk to a real cap or coyote takeoff")
				var before: int = actions.get("jump", 0)
				await _jump()
				_check(actions.get("jump", 0) == before + 1 and not actions.has("air_jump"), "The floor-side alternative starts with a real ordinary or coyote jump")
				await _step(delay)
				_aim(direction)
				await _dash()
				_drive("move_right", true)
				await _observe_alternative()
				_check(not alternative_landed and not stage.cleared.has(2) and not actions.has("air_jump"), "A raised floor-side jump, late dash and wall grab cannot reach the exit")
		print("ROOM3_NO_AIR_NORMAL launch=%d" % launch)


func _late_floor_dashes() -> void:
	raw = 1
	for delay in range(50, 62):
		for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP]:
			await _prepare_room()
			_drive("move_right", true)
			await _until(func(): return player.is_on_floor() and player.position.y < 410 and _x() > 240, 180, "Reach the natural wall-cap takeoff used by the old shortcut")
			_drive("move_right")
			await _jump()
			await _step(delay)
			if respawns == 0:
				_aim(direction)
				await _dash()
				_drive("move_right", true)
				await _observe_alternative()
			_check(not alternative_landed and not stage.cleared.has(2) and not actions.has("air_jump"), "The pit spikes reject a very late floor-side dash before it can land")
	print("ROOM3_LATE_FLOOR_DONE (36 inputs)")


func _on_exit_floor() -> bool:
	if not player.is_on_floor():
		return false
	for index in player.get_slide_collision_count():
		if player.get_slide_collision(index).get_collider() == stage.rooms.get_child(2).get_node("ExitFloor"):
			return true
	return false


func _superdash_alternatives() -> void:
	raw = 1
	for delay in [0, 4, 8]:
		await _prepare_room()
		await _approach()
		_drive("move_left")
		await _dash()
		await _step(delay)
		await _jump()
		_check(actions.has("superdash"), "The inverted alternative produces a real ground Dash-to-Jump")
		_drive("move_right", true, true)
		await _observe_alternative()
		_check(not alternative_landed and not stage.cleared.has(2) and not actions.has("air_jump"), "A real Superdash cannot replace the crystal jump")


func _observe_alternative() -> void:
	for frame in 260:
		alternative_landed = alternative_landed or _on_exit_floor()
		if respawns > 0 or alternative_landed or stage.cleared.has(2) or stage.room_index != 2:
			break
		# Keep climbing and real wall kicks available while preserving any boot.
		Input.action_release("jump")
		if player.is_on_wall() and not player.is_on_floor() and not player.is_dashing():
			Input.action_press("jump")
		await _step()
	_release_inputs()


func _retries() -> void:
	raw = 1
	await _prepare_room()
	await _approach()
	await _step(180)
	_check(player.is_on_floor() and respawns == 0, "The middle ceiling permits three seconds of safe observation")
	await _jump()
	await _step(20)
	_check(player.is_air_jump_ready(), "The real R regression begins after earning the airborne boot")
	_release_inputs()
	await _key(KEY_R)
	await _step(6)
	_check(_at_spawn() and not player.is_air_jump_ready() and stage.rooms.get_child(2).get_node("ExitJumpCrystal").visible and not stage.cleared.has(2), "R restores the entrance and crystal without keeping an earned jump")
	await _prepare_room()
	await _approach()
	_drive("move_right")
	await _until(func(): return respawns > 0, 160, "Walking toward the actual hanging spikes causes a retry")
	_release_inputs()
	_check(hazard_hits == 1 and _at_spawn(), "A real spike contact returns safely to the unfinished entrance")
	await _prepare_room()
	await _approach()
	_drive("move_left")
	await _until(func(): return respawns > 0, 260, "Walking off the middle ceiling falls out of the screen")
	_release_inputs()
	_check(hazard_hits == 0 and _at_spawn(), "A ceiling fall resets gravity, dash and the boot")
	await _prepare_room()
	_drive("move_right", true)
	await _until(func(): return player.is_on_floor() and player.position.y < 410 and _x() > 240, 180, "Reach the real floor-side cap")
	_drive("move_right")
	await _until(func(): return respawns > 0, 200, "Walking off the raised floor cap falls into the open floor pit")
	_release_inputs()
	_check(hazard_hits == 0 and floor_hits == 1 and _at_spawn(), "A real fall onto the pit spikes retries before reaching the exit")


func _at_spawn() -> bool:
	return stage.room_index == 2 and player.position.distance_to(stage.rooms.get_child(2).get_node("Spawn").global_position) < 20 and player.gravity_direction == 1 and player.is_dash_ready() and player.get_wall_stamina() > 2.9


func _backtrack_room() -> void:
	var before := respawns
	_drive("move_right")
	await _until(func(): return stage.room_index == 3 and not stage.transitioning, 180, "The real open exit reaches Room4")
	_drive("move_left")
	await _until(func(): return stage.room_index == 2 and not stage.transitioning, 180, "The next room returns to Room3")
	_release_inputs()
	_check(respawns == before + 2 and player.is_on_floor() and _x() > 1200 and stage.cleared.has(2), "The two real transitions restore the safe return entrance and preserve arrival")
	for frame in 500:
		if stage.room_index == 1 and not stage.transitioning:
			break
		_drive("move_left", true, player.gravity_direction < 0)
		await _step()
	_release_inputs()
	_check(stage.room_index == 1 and player.is_on_floor() and respawns == before + 3, "The completed return bridge passes below the spikes and reaches Room2 without a fall")


func _prepare_room() -> void:
	_release_inputs()
	if is_instance_valid(stage):
		stage.free()
	stage = load("res://scenes/stage_3.tscn").instantiate()
	root.add_child(stage)
	player = stage.player
	player.movement_action.connect(func(action: String): actions[action] = actions.get(action, 0) + 1)
	player.gravity_changed.connect(func(inverted: bool): flips.append(-1 if inverted else 1))
	player.respawned.connect(func(): respawns += 1)
	stage.rooms.get_child(2).get_node("ExitJumpCrystal").collected.connect(func(_body): actions["jump_crystal"] = actions.get("jump_crystal", 0) + 1)
	stage.rooms.get_child(2).get_node("ExitWallSpikes").player_hit.connect(func(): hazard_hits += 1)
	stage.rooms.get_child(2).get_node("FloorSpikes").player_hit.connect(func(): floor_hits += 1)
	stage.cleared[1] = true
	stage.cleared.erase(2)
	stage._set_room(1, false)
	player.respawn()
	await _step()
	stage._set_room(2, false)
	player.respawn()
	await _step(6)
	actions.clear()
	flips.clear()
	respawns = 0
	hazard_hits = 0
	floor_hits = 0
	alternative_landed = false


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
