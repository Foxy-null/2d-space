extends SceneTree

var tutorial: Node
var player: PlayerController
var room: Node2D
var checks := 0
var failed := false
var respawns := 0


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
	await _safe_retry()
	await _dash_alternatives()
	await _wall_alternative()
	await _superdash_attempt()
	for launch_x in [390, 410, 430]:
		for delay in [8, 12, 16, 20, 24, 28]:
			await _enter()
			await _walk_to(launch_x)
			_check(tutorial.seen.has("jump_crystal") and player.is_air_jump_ready(), "Walking to the takeoff naturally collects the purple boot")
			await _double_jump(delay)
			_check(tutorial.seen.has("air_jump") and not tutorial.seen.has("dash"), "The second real jump uses the boot without a dash")
			for frame in 100:
				if _on_landing():
					break
				await _step()
			_check(respawns == 0 and _on_landing() and player.is_dash_ready() and not player.is_air_jump_ready(), "The broad platform accepts x=%d, second-jump delay=%df" % [launch_x, delay])
			if launch_x == 430 and delay == 28:
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
	await _double_jump(8)
	for frame in 100:
		if _on_landing():
			break
		await _step()
	_check(_on_landing(), "Two jumps can retry through the one-way platform from the safe floor")
	Input.action_press("move_left")
	for frame in 150:
		if _local().x < 520:
			break
		await _step()
	_release()
	for frame in 90:
		if player.is_on_floor() and _local().y > 600:
			break
		await _step()
	_check(respawns == 0 and player.is_on_floor() and not player.is_air_jump_ready(), "Dropping from the landing is safe and does not refill a used boot")
	await _pulse("reset")
	await _step(4)
	_check(_local().x < 100 and player.is_on_floor() and room.get_node("JumpCrystal").visible, "R restores the safe entrance and purple boot")
	await _walk_to(400)
	_check(player.is_air_jump_ready(), "The restored boot can be collected naturally again")


func _dash_alternatives() -> void:
	for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
		await _enter()
		await _walk_to(400)
		await _pulse("jump")
		await _step(16)
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
		_check(reached == (direction == Vector2.UP or direction == Vector2(1, -1)), "Only the existing upward dash alternatives reach the raised area: %s" % direction)
		_check(not tutorial.seen.has("air_jump") and room.get_node("Goal").locked and not tutorial.cleared.has(5), "A dash alternative does not fake the additional-jump lesson")


func _wall_alternative() -> void:
	await _enter()
	await _walk_to(1230)
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await _step(80)
	_check(player.is_wall_grabbing() and tutorial.seen.has("climb"), "The existing exit wall permits a real wall climb")
	_release()
	Input.action_press("move_left")
	await _pulse("jump")
	_check(tutorial.seen.has("wall_jump"), "The wall route performs a real wall kick")
	_check(await _reaches_raised_area(), "The existing wall route remains an advanced alternative")
	_check(not tutorial.seen.has("air_jump") and room.get_node("Goal").locked, "Wall techniques do not unlock the additional-jump lesson")


func _superdash_attempt() -> void:
	await _enter()
	await _walk_to(400)
	await _pulse("dash")
	await _step(3)
	await _pulse("jump")
	_check(tutorial.seen.has("superdash"), "The attempt performs an actual Superdash")
	_check(not await _reaches_raised_area(), "A horizontal Superdash cannot reach the high platform")
	_check(not tutorial.seen.has("air_jump") and room.get_node("Goal").locked, "Superdash does not bypass the lesson")


func _reaches_raised_area() -> bool:
	for frame in 180:
		if player.is_on_floor() and _local().x > 530 and _local().y < 470:
			return true
		await _step()
	return false


func _finish_course() -> void:
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
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 6 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 6 and player.is_on_floor() and player.controls_enabled, "Walking out reaches room 7")


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


func _walk_to(x: float) -> void:
	Input.action_press("move_right")
	for frame in 300:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to x=%s timed out" % x)


func _double_jump(delay: int) -> void:
	await _pulse("jump")
	await _step(delay)
	await _pulse("jump")


func _on_landing() -> bool:
	if not player.is_on_floor():
		return false
	for index in player.get_slide_collision_count():
		if player.get_slide_collision(index).get_collider() == room.get_node("HighLanding"):
			return true
	return false


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


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
