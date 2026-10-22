extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	# Reaching this lesson normally requires opening the preceding room's exit.
	tutorial.cleared[12] = true
	tutorial.call("_set_room", 12, false)
	player.respawn()
	await _step(3)
	await _enter()
	_capture("entrance")
	# Reachability is measured before the mission lock, so it cannot hide a bypass.
	for launch_at in [220, 280, 300]:
		for jump_kind in ["walk", "jump", "superdash"]:
			for direction in ["right", "up_right", "up"]:
				for dash_frame in [-1, 0, 6, 12, 18, 24, 30, 36, 42, 48, 54, 60]:
					await _without_parachute(launch_at, jump_kind, direction, dash_frame)
	await _enter()
	await _grab()
	Input.action_press("move_right")
	for frame in 160:
		if _local().x >= 650 or respawns > 0:
			break
		await _step()
	Input.action_release("wall_grab")
	for frame in 120:
		if respawns > 0:
			break
		await _step()
	_release()
	await _step(3)
	_check(respawns > 0, "Releasing too early must return to the entrance")
	_check(player.get_held_object() == null, "Retry clears the held object")
	_check(_room().get_node("Parachute").position.distance_to(Vector2(170, 253.4)) < 5, "Retry restores the parachute on the entrance")
	await _enter()
	await _grab()
	Input.action_press("move_right")
	for frame in 50:
		if _local().x >= 220:
			break
		await _step()
	await _pulse("jump")
	for frame in 220:
		if _local().x >= 1000 or respawns > 0:
			break
		await _step()
	_check(respawns == 0 and _local().x >= 1000, "A jump with the held parachute glides within reach of the landing without a dash")
	_check(tutorial.seen.has("glide") and not player.is_on_floor(), "The crossing uses real slow fall")
	_capture("landing")
	Input.action_release("wall_grab")
	for frame in 140:
		if tutorial.cleared.has(13):
			break
		Input.action_release("jump")
		if _local().x >= 1140:
			Input.action_release("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_check(respawns == 0 and tutorial.cleared.has(13), "Releasing over the landing completes the real lesson and presses the goal")
	_capture("cleared")
	Input.action_press("move_right")
	for frame in 120:
		if tutorial.room_index == 14 and not tutorial.transitioning:
			break
		await _step()
	_check(tutorial.room_index == 14 and player.controls_enabled, "The completed landing leads safely into the next lesson")
	await _test_backtrack()
	_release()
	print("TUTORIAL_CARRY_LEARNING_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _test_backtrack() -> void:
	_release()
	Input.action_press("move_left")
	for frame in 180:
		if tutorial.room_index == 13 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 13 and player.controls_enabled and player.is_on_floor(), "Walking left from Room15 returns safely to Room14")
	_check(_local().distance_to(Vector2(72, 274)) < 10, "Backtracking lands beside the entrance parachute instead of beyond the valley")
	var before_reset := respawns
	await _pulse("reset")
	await _step(4)
	_check(respawns == before_reset + 1 and _local().distance_to(Vector2(72, 274)) < 2, "Retry after backtracking keeps the safe entrance checkpoint")
	_check(_room().get_node("Parachute").position.distance_to(Vector2(170, 253.4)) < 5 and tutorial.cleared.has(13), "Backtracking retry restores the parachute and preserves the cleared lesson")
	Input.action_press("move_left")
	for frame in 180:
		if tutorial.room_index == 12 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 12 and player.controls_enabled and player.is_on_floor(), "Walking left after retry can continue to Room13")


func _without_parachute(launch_at: float, jump_kind: String, direction: String, dash_frame: int) -> void:
	await _enter()
	Input.action_press("move_right")
	for frame in 250:
		if _local().x >= launch_at:
			break
		await _step()
	_check(respawns == 0 and _local().x >= launch_at, "Reach the tested launch position before attempting a bypass")
	if jump_kind == "superdash":
		await _pulse("dash")
		await _step(4)
	if jump_kind != "walk":
		await _pulse("jump")
	var reached := false
	for frame in 160:
		if frame == dash_frame:
			if direction != "right":
				Input.action_press("move_up")
			if direction == "up":
				Input.action_release("move_right")
			await _pulse("dash")
			Input.action_press("move_right")
			Input.action_release("move_up")
		# Try to rescue a late crossing by grabbing/climbing the landing's side.
		if _local().x > 850:
			Input.action_press("wall_grab")
			Input.action_press("move_up")
		await _step()
		reached = reached or (_local().x >= 1082 and _local().y <= 614)
		if respawns > 0:
			break
	_check(not reached and respawns > 0, "%s from %d with %s dash at %d cannot reach the landing without a parachute" % [jump_kind, launch_at, direction, dash_frame])
	_release()


func _grab() -> void:
	Input.action_press("move_right")
	for frame in 60:
		if _local().x >= 110:
			break
		await _step()
	Input.action_release("move_right")
	Input.action_press("wall_grab")
	await _step(3)
	_check(player.get_held_object() == _room().get_node("Parachute"), "Movement and Grab acquire the visible entrance parachute")


func _enter() -> void:
	_release()
	tutorial.cleared.erase(13)
	tutorial.call("_set_room", 13, false)
	player.respawn()
	await _step(6)
	respawns = 0


func _room() -> Node:
	return tutorial.rooms.get_child(13)


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


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_CARRY_LEARNING: %s (position=%s velocity=%s seen=%s)" % [message, _local(), player.velocity, tutorial.seen.keys()])


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/tutorial-carry-%s.png" % name)
