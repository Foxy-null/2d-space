extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var highest := INF


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _new_world()
	await _bypasses()
	await _fall_retry()
	for pause in [0, 20, 60]:
		await _new_world()
		await _course(pause)
	await _backtrack()
	_release()
	print("TUTORIAL_SPRING_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _bypasses() -> void:
	for lower in [false, true]:
		for launch in ([350, 400, 480, 560] if lower else [72, 120, 160, 180]):
			for direction in ["right", "up_right", "up"]:
				for dash_frame in [-1, 0, 12, 24, 36, 48, 60]:
					await _attempt(lower, launch, direction, dash_frame)
	for launch in [72, 400, 480]:
		await _attempt(launch > 72, launch, "superdash", -1)


func _attempt(lower: bool, launch: float, direction: String, dash_frame: int) -> void:
	await _enter()
	if lower:
		await _walk_to(110)
		await _pulse("jump")
	await _walk_to(launch)
	if lower:
		_check(not tutorial.seen.has("floor_spring"), "The lower-floor bypass starts beyond the spring without using it")
	if direction == "superdash":
		await _pulse("dash")
		await _step(4)
	await _pulse("jump")
	var reached := false
	for frame in 240:
		if tutorial.seen.has("floor_spring") or respawns > 0:
			break
		if frame == dash_frame:
			Input.action_release("move_up")
			if direction != "right":
				Input.action_press("move_up")
			if direction == "up":
				Input.action_release("move_right")
			await _pulse("dash")
			Input.action_press("move_right")
			Input.action_release("move_up")
		if _local().x > 480:
			Input.action_press("wall_grab")
			Input.action_press("move_up")
		# Try climbing the exit wall and jumping back onto the landing.
		if player.is_wall_grabbing() and _local().x > 1200 and _local().y < 360:
			Input.action_release("move_right")
			Input.action_press("move_left")
			await _pulse("jump")
		await _step()
		reached = reached or (_local().x >= 482 and _local().y <= 304)
	_check(not reached or tutorial.seen.has("floor_spring"), "Jump/dash/wall actions cannot reach the upper landing without the spring: lower=%s launch=%d direction=%s frame=%d" % [lower, launch, direction, dash_frame])
	_release()


func _fall_retry() -> void:
	await _enter()
	await _walk_to(110)
	await _pulse("jump")
	Input.action_press("move_right")
	for frame in 240:
		if respawns > 0:
			break
		await _step()
	_release()
	await _step(4)
	_check(respawns == 1 and _local().distance_to(Vector2(72, 614)) < 10, "Missing the spring and falling restores the safe entrance")
	_check(not tutorial.seen.has("floor_spring") and not tutorial.cleared.has(6), "A failed jump cannot satisfy the spring lesson")


func _course(pause: int) -> void:
	_capture("entrance")
	if pause > 0:
		await _walk_to(150)
		_release()
		await _step(pause)
	Input.action_press("move_right")
	for frame in 200:
		if tutorial.seen.has("floor_spring") and player.is_on_floor() and _local().y < 400:
			break
		await _step()
	_check(tutorial.seen.has("floor_spring") and player.is_on_floor() and absf(_local().y - 304) < 2, "Holding right after a pause of %d frames reaches the wide landing" % pause)
	_check(respawns == 0 and highest >= 26, "The spring flight stays inside the screen without an upward retry")
	_check(not tutorial.seen.has("jump") and not tutorial.seen.has("dash") and not tutorial.seen.has("wall_jump"), "Reaching the landing requires only right input")
	_capture("landing")
	Input.action_release("move_right")
	await _step(60)
	_check(player.is_on_floor() and absf(_local().y - 304) < 2, "The wide landing provides a safe rest")
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.cleared.has(6):
			break
		Input.action_release("jump")
		if _local().x >= 900:
			Input.action_release("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_check(tutorial.cleared.has(6) and respawns == 0, "The real arrival switch completes the spring-only lesson")
	_check(not tutorial.seen.has("wall_spring") and not tutorial.seen.has("spring_dash"), "A wall spring and a dash are not extra completion requirements")
	_capture("cleared")
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 7 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 7 and player.controls_enabled, "The landing leads into Room8")


func _backtrack() -> void:
	Input.action_press("move_left")
	for frame in 180:
		if tutorial.room_index == 6 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 6 and player.is_on_floor() and _local().distance_to(Vector2(72, 614)) < 10, "Returning from Room8 uses the safe left entrance")
	await _pulse("reset")
	await _step(4)
	_check(_local().distance_to(Vector2(72, 614)) < 2 and tutorial.cleared.has(6), "Retry after backtracking preserves the entrance and cleared lesson")
	Input.action_press("move_left")
	for frame in 180:
		if tutorial.room_index == 5 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 5 and player.controls_enabled, "Left input after retry continues into Room6")
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 6 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 6 and player.controls_enabled, "Room6 can be re-entered from its right exit into Room7")


func _new_world() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	# Earlier rooms are already open when the player reaches this lesson.
	tutorial.cleared[5] = true
	tutorial.call("_set_room", 5, false)
	player.respawn()
	await _step(3)
	await _enter()


func _enter() -> void:
	_release()
	tutorial.call("_set_room", 6, false)
	player.respawn()
	await _step(6)
	respawns = 0
	highest = _local().y


func _walk_to(x: float) -> void:
	Input.action_press("move_right")
	for frame in 180:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to %d timed out" % x)


func _local() -> Vector2:
	return player.global_position - Vector2(7680, 0)


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		if is_instance_valid(player) and tutorial.room_index == 6:
			highest = minf(highest, _local().y)


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_SPRING_ROUTE: %s (room=%d position=%s velocity=%s seen=%s)" % [message, tutorial.room_index + 1, _local(), player.velocity, tutorial.seen.keys()])


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/tutorial-spring-%s.png" % name)
