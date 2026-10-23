extends SceneTree

var tutorial: Node
var player: PlayerController
var room: Node2D
var failed := false
var checks := 0
var respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	room = tutorial.get_node("Rooms/Room9")
	player.respawned.connect(func(): respawns += 1)
	await _step(5)
	await _safe_approach()
	await _jump_bypasses()
	for launch_y in [650, 690, 730, 742]:
		await _wall_kick_bypass(launch_y)
	await _outside_dash_bypasses()
	for launch_x in [470, 480, 490, 500, 510, 520, 530]:
		await _enter()
		await _walk_to(launch_x)
		await _pulse("dash")
		_check(player.is_dashing() and player.velocity.x > 850, "Dash ignores headwind from x=%d" % launch_x)
		for frame in 100:
			if player.is_on_floor() and _local().x > 730:
				break
			await _step()
		_check(respawns == 0 and player.is_on_floor() and _local().x > 730, "A ground dash reaches the broad landing without jump timing")
		_check(player.is_dash_ready() and not tutorial.seen.has("jump") and not tutorial.seen.has("wind_grab"), "Landing restores dash without requiring jump or wall grab")
		if launch_x == 530:
			await _finish_course()
	await _backtrack()
	_release()
	tutorial.free()
	print("TUTORIAL_WIND_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _safe_approach() -> void:
	await _enter()
	await _walk_to(380)
	await _step(24)
	_check(player.is_on_floor() and _local().x < 520 and player.velocity.x < 60, "Headwind can be felt on safe ground before the gap")
	Input.action_release("move_right")
	await _step(20)
	_check(player.is_on_floor() and respawns == 0 and _local().x < 380, "Letting go of movement safely drifts back from the gap")
	await _enter()
	Input.action_press("move_right")
	for frame in 600:
		if respawns > 0:
			break
		await _step()
	_check(respawns > 0 and _local().x < 100, "Walking into the gap safely retries at the entrance")
	_check(player.is_dash_ready() and player.gravity_direction == 1, "Falling restores dash and down gravity")
	await _pulse("reset")
	await _step(3)
	_check(_local().x < 100 and player.is_on_floor(), "R restores the same safe entrance")


func _jump_bypasses() -> void:
	for launch_x in [300, 490, 530, 540]:
		await _enter()
		await _walk_to(launch_x)
		await _pulse("jump")
		var jumped := player.velocity.y < 0
		var reached := false
		for frame in 140:
			reached = reached or _local().x >= 712
			if respawns > 0:
				break
			await _step()
		_check(jumped and not reached, "A normal or coyote jump cannot cross the headwind gap from x=%d" % launch_x)


func _wall_kick_bypass(launch_y: float) -> void:
	await _enter()
	await _walk_to(540)
	Input.action_release("move_right")
	Input.action_press("move_left")
	Input.action_press("wall_grab")
	for frame in 30:
		if player.is_wall_grabbing():
			break
		await _step()
	Input.action_press("move_down")
	for frame in 80:
		if _local().y >= launch_y:
			break
		await _step()
	Input.action_release("move_down")
	_check(player.is_wall_grabbing(), "Wall-kick bypass starts from the real entrance face")
	Input.action_release("move_left")
	Input.action_release("wall_grab")
	Input.action_press("move_right")
	await _pulse("jump")
	_check(tutorial.seen.has("wall_jump"), "The bypass uses the actual wall-kick action")
	var reached := false
	for frame in 140:
		reached = reached or _local().x >= 712
		if respawns > 0:
			break
		await _step()
	_check(not reached and not tutorial.seen.has("wind_dash"), "An entrance wall kick cannot replace the wind dash")


func _outside_dash_bypasses() -> void:
	for method in ["dash", "superdash", "jump_dash", "up_dash", "diagonal_dash"]:
		await _enter()
		await _walk_to(320)
		if method == "jump_dash":
			await _pulse("jump")
		if method in ["up_dash", "diagonal_dash"]:
			Input.action_press("move_up")
		if method == "up_dash":
			Input.action_release("move_right")
		await _pulse("dash")
		var dashed := player.is_dashing()
		Input.action_release("move_up")
		Input.action_press("move_right")
		if method == "superdash":
			await _step(3)
			await _pulse("jump")
		var reached := false
		for frame in 240:
			reached = reached or _local().x >= 712
			if respawns > 0:
				break
			await _step()
		_check(dashed and not reached and not tutorial.seen.has("wind_dash"), "Dash begun outside the wind cannot skip the challenge: " + method)


func _finish_course() -> void:
	Input.action_press("move_right")
	for frame in 350:
		if tutorial.cleared.has(8):
			break
		Input.action_release("jump")
		if _local().x >= 1150:
			Input.action_release("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release()
	await _step(2)
	_check(tutorial.cleared.has(8) and room.get_node("Goal").is_pressed(), "The natural wind route presses the actual arrival switch")
	_check(room.get_node("ExitBarrier/Collision").disabled, "The completed route opens the exit")
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 9 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 9 and player.is_on_floor() and player.controls_enabled, "Walking out reaches the higher floor of the next room")


func _backtrack() -> void:
	# Open the preceding exit as it would be after a real playthrough.
	tutorial.cleared[7] = true
	tutorial.call("_set_room", 7, false)
	player.respawn()
	await _step(3)
	tutorial.call("_set_room", 9, false)
	player.respawn()
	await _step(6)
	Input.action_press("move_left")
	for frame in 120:
		if tutorial.room_index == 8 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(3)
	_check(tutorial.room_index == 8 and _local().x < 200 and player.is_on_floor(), "Coming from the right returns to safe ground")
	await _pulse("reset")
	await _step(3)
	Input.action_press("move_left")
	for frame in 120:
		if tutorial.room_index == 7 and not tutorial.transitioning:
			break
		await _step()
	_check(tutorial.room_index == 7 and player.controls_enabled, "R after backtracking still permits walking into the preceding room")


func _enter() -> void:
	_release()
	tutorial.call("_set_room", 8, false)
	player.respawn()
	await _step(6)
	respawns = 0


func _walk_to(x: float) -> void:
	Input.action_press("move_right")
	for frame in 450:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to x=%s timed out" % x)


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
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_WIND_ROUTE: %s (position=%s velocity=%s)" % [message, _local(), player.velocity])
