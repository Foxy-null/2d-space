extends SceneTree

var tutorial: Node
var player: PlayerController
var room: Node2D
var checks := 0
var failed := false
var respawns := 0
var frames := 0
var route_start := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	room = tutorial.get_node("Rooms/Room6")
	player.respawned.connect(func(): respawns += 1)
	await _step(5)
	# Preserve the preceding room's completed exit for the later real backtrack.
	tutorial.cleared[4] = true
	tutorial.call("_set_room", 4, false)
	player.respawn()
	await _step(3)
	await _enter()
	_check(not room.get_node("Goal").locked and tutorial.seen.is_empty(), "Room 6 arrival is available without an action-history lock")
	await _capture("entrance")
	await _safe_retry()
	await _dash_alternatives()
	await _wall_alternative()
	await _superdash_attempt()
	for launch_x in [390, 410, 430]:
		for delay in [12, 16, 20, 24, 28]:
			await _enter()
			await _walk_to(launch_x)
			_check(tutorial.seen.has("jump_crystal") and player.is_air_jump_ready(), "Walking to the takeoff naturally collects the purple boot")
			await _double_jump(delay)
			await _step(16)
			await _up_dash()
			_check(tutorial.seen.has("air_jump") and tutorial.seen.has("dash"), "The real route combines the boot and learned upward dash")
			for frame in 100:
				if _on_landing():
					break
				await _step()
			_check(respawns == 0 and _on_landing() and player.is_dash_ready() and not player.is_air_jump_ready(), "The broad platform accepts x=%d, second-jump delay=%df" % [launch_x, delay])
			if launch_x == 430 and delay == 28:
				await _capture("upper_landing")
				await _finish_course()
	for first in [12, 16, 20, 24, 28]:
		for second in [12, 16, 20, 24, 28]:
			await _enter()
			await _walk_to(390)
			await _double_jump(first)
			await _step(second)
			await _up_dash()
			_check(await _reaches_raised_area(), "Additional-jump-first route accepts gaps %d/%df" % [first, second])
	for first in [8, 16, 24, 32]:
		for second in [16, 20, 24, 28]:
			await _enter()
			await _walk_to(430)
			await _pulse("jump")
			await _step(first)
			await _up_dash()
			await _step(second)
			await _pulse("jump")
			_check(await _reaches_raised_area(), "Dash-first route accepts gaps %d/%df" % [first, second])
	await _finish_course()
	await _backtrack()
	_release()
	tutorial.free()
	print("TUTORIAL_EXTRA_JUMP_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _safe_retry() -> void:
	await _enter()
	await _walk_to(400)
	await _pulse("jump")
	await _step(60)
	_release()
	await _step(6)
	_check(player.is_on_floor() and absf(_local().y - 614) < 1 and respawns == 0, "A missed normal jump lands safely below the platform")
	_check(player.is_air_jump_ready(), "The unused boot remains available after landing")
	await _double_jump(16)
	await _step(100)
	_release()
	_check(player.is_on_floor() and absf(_local().y - 614) < 1 and not player.is_air_jump_ready(), "Two jumps alone return safely to the floor below the 400px ascent")
	await _pulse("reset")
	await _step(4)
	_check(_local().x < 100 and player.is_on_floor() and room.get_node("JumpCrystal").visible, "R restores the safe entrance and purple boot")
	player.global_position.y = 780
	player.velocity = Vector2.ZERO
	await _step(4)
	_check(_local().x < 100 and player.is_on_floor() and room.get_node("JumpCrystal").visible, "A fall below the room restores the safe entrance and boot")
	await _walk_to(400)
	_check(player.is_air_jump_ready(), "The restored boot can be collected naturally again")


func _dash_alternatives() -> void:
	for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
		for delay in [0, 16, 32]:
			await _enter()
			await _walk_to(400)
			await _pulse("jump")
			await _step(delay)
			_release()
			if direction.x != 0:
				Input.action_press("move_right" if direction.x > 0 else "move_left")
			if direction.y != 0:
				Input.action_press("move_down" if direction.y > 0 else "move_up")
			await _pulse("dash")
			_check(player.is_dashing(), "The alternative starts a real directional dash")
			_release()
			Input.action_press("move_right")
			var reached := await _reaches_raised_area()
			_check(not reached, "No directional dash without the extra jump reaches the 400px landing: %s" % direction)
			_check(not tutorial.seen.has("air_jump") and not room.get_node("Goal").locked and not tutorial.cleared.has(5), "The open arrival remains unreachable without the additional jump")


func _wall_alternative() -> void:
	await _enter()
	await _walk_to(1230)
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	var climbed := false
	for frame in 80:
		climbed = climbed or player.is_wall_grabbing()
		if respawns > 0:
			break
		await _step()
	_release()
	await _step(3)
	_check(climbed and respawns > 0, "Visible spikes stop climbing the exit wall above the safe floor")
	_check(_local().x < 100 and player.is_on_floor() and room.get_node("JumpCrystal").visible, "Wall contact restores the entrance and boot without a teleport collision")
	_check(not tutorial.cleared.has(5), "Wall techniques do not reach the open arrival")
	await _enter()
	await _walk_to(1230)
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await _step(4)
	Input.action_release("move_up")
	await _step(10)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _pulse("jump")
	Input.action_release("wall_grab")
	_check(tutorial.seen.has("wall_jump"), "The strongest wall attempt starts a real wall kick")
	await _step(12)
	Input.action_release("move_left")
	Input.action_press("move_up")
	await _pulse("dash")
	Input.action_release("move_up")
	Input.action_press("move_left")
	_check(not await _reaches_raised_area(), "A low wall kick plus upward dash cannot reach the landing")


func _superdash_attempt() -> void:
	await _enter()
	await _walk_to(260)
	await _pulse("dash")
	await _step(10)
	await _pulse("jump")
	_check(tutorial.seen.has("superdash") and player.is_dash_ready(), "A late Superdash retains a fresh air dash")
	await _step(16)
	await _up_dash()
	_check(player.is_dashing(), "The strongest Superdash attempt includes a real upward air dash")
	_check(not await _reaches_raised_area(), "Superdash plus upward dash still cannot reach the high platform")
	_check(not tutorial.seen.has("air_jump") and not tutorial.cleared.has(5), "Superdash does not bypass the terrain")


func _reaches_raised_area() -> bool:
	for frame in 180:
		if player.is_on_floor():
			return _local().x > 470 and _local().y <= 214
		await _step()
	return false


func _finish_course() -> void:
	var before_respawns := respawns
	Input.action_press("move_right")
	for frame in 350:
		if tutorial.cleared.has(5):
			break
		Input.action_release("jump")
		if _local().x >= 900:
			Input.action_release("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release()
	_check(tutorial.cleared.has(5) and room.get_node("Goal").is_pressed(), "The two-jump route presses the actual arrival switch")
	_check(room.get_node("ExitBarrier/Collision").disabled, "The actual arrival opens the exit")
	print("ROOM6_ROUTE_SECONDS %.2f" % ((frames - route_start) / 60.0))
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 6 and not tutorial.transitioning:
			break
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release()
	_check(tutorial.room_index == 6 and player.is_on_floor() and player.controls_enabled and respawns == before_respawns + 1, "Dropping from the upper landing and walking out reaches room 7 safely")


func _backtrack() -> void:
	await _pulse("reset")
	await _step(4)
	_check(tutorial.room_index == 6 and player.is_on_floor() and player.controls_enabled, "R in room 7 keeps its safe checkpoint before returning")
	Input.action_press("move_left")
	for frame in 180:
		if tutorial.room_index == 5 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 5 and _local().x > 1100 and player.is_on_floor(), "Returning from room 7 reaches the safe right floor")
	await _pulse("reset")
	await _step(4)
	_check(_local().x > 1100 and player.is_on_floor(), "R after returning preserves a safe checkpoint")
	Input.action_press("move_left")
	for frame in 300:
		if tutorial.room_index == 4 and not tutorial.transitioning:
			break
		await _step()
	_check(tutorial.room_index == 4 and player.is_on_floor() and player.controls_enabled, "The continuous floor lets the player return to room 5 after R")


func _enter() -> void:
	_release()
	tutorial.call("_set_room", 5, false)
	player.respawn()
	await _step(6)
	respawns = 0
	route_start = frames


func _walk_to(x: float) -> void:
	Input.action_press("move_right")
	for frame in 300:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to x=%s timed out" % x)


func _up_dash() -> void:
	Input.action_release("move_right")
	Input.action_press("move_up")
	await _pulse("dash")
	Input.action_release("move_up")
	Input.action_press("move_right")


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):
		return
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial-air-jump")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/tutorial-air-jump/%s.png" % name)


func _double_jump(delay: int) -> void:
	await _pulse("jump")
	await _step(delay)
	await _pulse("jump")


func _on_landing() -> bool:
	return player.is_on_floor() and _local().y <= 214.0


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		frames += 1


func _local() -> Vector2:
	return player.global_position - room.global_position


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_EXTRA_JUMP_ROUTE: %s (position=%s velocity=%s)" % [message, _local(), player.velocity])
