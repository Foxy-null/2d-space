extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var frames := 0
var route_start := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	tutorial.cleared[11] = true
	tutorial.call("_set_room", 11, false)
	player.respawn()
	await _step(3)
	await _safe_retry()
	await _dash_alternatives()
	await _wall_alternatives()
	await _creature_step_alternatives()
	for launch in [390, 410, 430]:
		for first in [16, 20, 24]:
			for second in [16, 20, 24]:
				await _course(first, second, false, launch)
	for first in [12, 16, 20, 24]:
		for second in [20, 24, 28]:
			await _course(first, second, true, 410)
	await _course(20, 20, false, 410)
	await _capture("upper_landing")
	await _finish_course()
	await _backtrack()
	_release()
	tutorial.free()
	print("TUTORIAL_COMPANION_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _safe_retry() -> void:
	await _enter()
	_check(not _room().get_node("Goal").locked and tutorial.seen.is_empty(), "The terrain-led arrival starts ready without action history")
	await _capture("entrance")
	await _grab()
	await _walk_to(410)
	await _pulse("jump")
	await _step(60)
	_release_horizontal()
	await _step(20)
	_check(respawns == 0 and player.is_on_floor() and absf(_local().y - 614) < 2, "An ordinary jump safely returns to the continuous floor")
	_check(player.get_held_object() == _room().get_node("Creature") and player.get_available_extra_jump_count() == 1, "A miss preserves the held companion and its ready jump")
	await _walk_to(620)
	_release_horizontal()
	await _step(15)
	await _pulse("jump")
	await _step(20)
	await _pulse("jump")
	await _step(20)
	await _up_dash()
	_check(await _wait_high(), "The safe floor permits another attempt without R")
	_check(player.get_available_extra_jump_count() == 1 and tutorial.seen.has("creature_landed"), "Landing refills the companion after its additional jump")
	await _capture("rest")
	_release_horizontal()
	await _step(60)
	_check(_on_landing() and player.get_available_extra_jump_count() == 1, "The wide landing allows an unhurried rest")
	await _pulse("jump")
	await _step(16)
	Input.action_release("wall_grab")
	await _up_dash()
	for frame in 120:
		if respawns > 0:
			break
		await _step()
	_release()
	await _step(4)
	_check(respawns > 0 and _local().x < 100 and player.is_on_floor(), "An actual upward overshoot respawns at the entrance")
	await _pulse("reset")
	await _step(5)
	_check(_local().x < 100 and player.get_held_object() == null, "R returns to the safe entrance and clears held state")
	_check(_room().get_node("Creature").position.distance_to(Vector2(150, 607.1)) < 4, "R restores the companion next to the entrance")
	await _grab()
	_check(player.get_available_extra_jump_count() == 1, "The restored companion can be acquired again")


func _course(first: int, second: int, dash_first: bool, launch: float) -> void:
	await _enter()
	await _grab()
	await _walk_to(launch)
	await _pulse("jump")
	await _step(first)
	if dash_first:
		await _up_dash()
		await _step(second)
		await _pulse("jump")
	else:
		await _pulse("jump")
		await _step(second)
		await _up_dash()
	_check(tutorial.seen.has("creature_jump") and tutorial.seen.has("dash"), "The route uses a real companion jump and dash")
	_check(await _wait_high() and respawns == 0, "The 420px ascent accepts launch=%d gaps=%d/%df dash_first=%s" % [launch, first, second, dash_first])
	_check(player.get_held_object() == _room().get_node("Creature") and player.get_available_extra_jump_count() == 1, "The upper landing refills the held companion")


func _dash_alternatives() -> void:
	for held in [false, true]:
		for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
			for delay in [8, 16, 24, 32]:
				await _enter()
				if held:
					await _grab()
				else:
					Input.action_press("move_right")
					await _pulse("jump")
				await _walk_to(410)
				await _pulse("jump")
				await _step(delay)
				_release_horizontal()
				if direction.x != 0:
					Input.action_press("move_right" if direction.x > 0 else "move_left")
				if direction.y != 0:
					Input.action_press("move_down" if direction.y > 0 else "move_up")
				await _pulse("dash")
				_check(player.is_dashing(), "The alternative starts a real directional dash")
				Input.action_release("move_up")
				Input.action_release("move_down")
				_release_horizontal()
				Input.action_press("move_right")
				_check(not await _wait_high() and not tutorial.cleared.has(12), "No directional dash reaches the open arrival without the companion jump: held=%s direction=%s delay=%d" % [held, direction, delay])
				_check(not tutorial.seen.has("creature_jump"), "The alternative never spends a companion jump")


func _wall_alternatives() -> void:
	await _enter()
	Input.action_press("move_right")
	await _pulse("jump")
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
	_check(climbed and respawns > 0 and not tutorial.cleared.has(12), "Visible spikes stop an empty-handed exit-wall climb")
	await _enter()
	Input.action_press("move_right")
	await _pulse("jump")
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
	_check(tutorial.seen.has("wall_jump"), "The wall alternative performs a real kick")
	await _step(12)
	Input.action_release("move_left")
	Input.action_press("move_up")
	await _pulse("dash")
	Input.action_release("move_up")
	Input.action_press("move_left")
	_check(not await _wait_high(), "Wall kick plus upward dash does not replace the companion jump")


func _creature_step_alternatives() -> void:
	for delay in [16, 20, 24]:
		await _enter()
		await _grab()
		await _walk_to(600)
		_release_horizontal()
		await _step(20)
		Input.action_release("wall_grab")
		await _step(2)
		Input.action_press("move_left")
		await _step(25)
		_release_horizontal()
		await _step(30)
		var creature: Grabbable = _room().get_node("Creature")
		_check(player.get_held_object() == null and absf(creature.position.y - 607.1) < 4, "The actual drop leaves a free companion below the high landing")
		await _pulse("jump")
		var stood := false
		for frame in 110:
			_steer_to(creature.position.x)
			await _step()
			if player.is_on_floor() and _local().y < 570:
				stood = true
				break
		_release_horizontal()
		_check(stood, "A real jump lands on top of the free companion")
		Input.action_press("wall_grab")
		await _pulse("jump")
		_check(player.get_held_object() == creature and player.velocity.y < -620 and not tutorial.seen.has("creature_jump"), "Grab plus Jump from the companion uses a higher ordinary jump")
		await _step(delay)
		await _up_dash()
		_check(player.is_dashing() and player.get_held_object() == creature and not tutorial.seen.has("creature_jump"), "The step attempt starts a real upward dash while carrying")
		_check(not await _wait_high() and not tutorial.cleared.has(12) and not tutorial.seen.has("creature_jump"), "The companion step plus ordinary jump and upward dash cannot bypass the 420px ascent")


func _finish_course() -> void:
	Input.action_press("move_right")
	for frame in 240:
		if tutorial.cleared.has(12):
			break
		Input.action_release("jump")
		if _local().x >= 850:
			Input.action_release("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_check(tutorial.cleared.has(12) and respawns == 0 and _room().get_node("Goal").is_pressed(), "The actual arrival clears the terrain-led room")
	print("ROOM13_ROUTE_SECONDS %.2f" % ((frames - route_start) / 60.0))
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 13 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 13 and player.is_on_floor() and player.controls_enabled and respawns == 1, "The safe descent reaches room 14 and its raised checkpoint")


func _backtrack() -> void:
	await _pulse("reset")
	await _step(4)
	Input.action_press("move_left")
	for frame in 180:
		if tutorial.room_index == 12 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 12 and _local().x > 1100 and player.is_on_floor(), "Returning from room 14 reaches the safe right floor")
	await _pulse("reset")
	await _step(4)
	_check(_local().x > 1100 and player.is_on_floor() and _room().get_node("Goal").is_pressed(), "R after returning preserves the checkpoint and cleared arrival")
	Input.action_press("move_left")
	Input.action_press("wall_grab")
	for frame in 300:
		if tutorial.room_index == 11 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 11 and player.is_on_floor() and player.controls_enabled, "The continuous floor returns to room 12 after R")


func _enter() -> void:
	_release()
	tutorial.call("_set_room", 12, false)
	player.respawn()
	await _step(6)
	respawns = 0
	route_start = frames


func _grab() -> void:
	Input.action_press("wall_grab")
	await _step(3)
	_check(player.get_held_object() == _room().get_node("Creature"), "The companion can be grabbed at the entrance")


func _walk_to(x: float) -> void:
	var direction := 1 if x > _local().x else -1
	_release_horizontal()
	Input.action_press("move_right" if direction > 0 else "move_left")
	for frame in 350:
		if (_local().x - x) * direction >= 0:
			return
		await _step()
	_check(false, "Walking to %s timed out" % x)


func _steer_to(x: float) -> void:
	_release_horizontal()
	if absf(x - _local().x) > 6:
		Input.action_press("move_right" if x > _local().x else "move_left")


func _up_dash() -> void:
	_release_horizontal()
	Input.action_press("move_up")
	await _pulse("dash")
	Input.action_release("move_up")
	Input.action_press("move_right")


func _wait_high() -> bool:
	for frame in 160:
		if player.is_on_floor():
			var landed := _on_landing()
			await _step()
			return landed
		await _step()
	return false


func _on_landing() -> bool:
	return player.is_on_floor() and _local().y <= 194


func _room() -> Node:
	return tutorial.rooms.get_child(12)


func _local() -> Vector2:
	return player.global_position - _room().global_position


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		frames += 1


func _release_horizontal() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_COMPANION_ROUTE: %s (position=%s velocity=%s)" % [message, _local(), player.velocity])


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):
		return
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial-companion")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/tutorial-companion/%s.png" % name)
