extends SceneTree

var tutorial: Node
var player: PlayerController
var room: Node2D
var heavy: Grabbable
var button: Area2D
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	room = tutorial.get_node("Rooms/Room12")
	heavy = room.get_node("Heavy")
	button = room.get_node("Button")
	await _step(5)
	await _carry_bypasses()
	await _push_and_drop()
	await _failed_throw_retry()
	for release_x in [420, 440, 460, 480, 500, 510]:
		await _enter()
		await _grab()
		await _walk_to(release_x)
		Input.action_release("wall_grab")
		await _step()
		Input.action_release("move_right")
		await _step(100)
		_check(player.get_held_object() == null and not heavy.freeze, "Moving release restores the real rigid body")
		_check(button.is_pressed() and button.total_weight == heavy.weight, "Ground throw reaches the wide target from x=%d" % release_x)
		_check(room.get_node("Divider/Collision").disabled and not room.get_node("Divider/Visual").visible, "Actual weight opens the visible route")
		if release_x == 510:
			await _walk_goal()
	await _reset_after_success()
	_release()
	tutorial.free()
	print("TUTORIAL_THROW_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _carry_bypasses() -> void:
	for method in ["walk", "jump", "dash", "up_dash", "wall_kick"]:
		await _enter()
		await _grab()
		await _walk_to(480)
		if method in ["jump", "up_dash", "wall_kick"]:
			await _pulse("jump")
		if method == "up_dash":
			await _step(14)
			Input.action_release("move_right")
			Input.action_press("move_up")
		if method in ["dash", "up_dash"]:
			await _pulse("dash")
		Input.action_press("move_right")
		for frame in 180:
			if method == "wall_kick" and player.is_on_wall() and frame % 20 == 0:
				await _pulse("jump")
			await _step()
		_check(player.get_held_object() == heavy and _local().x < 546, "Carrying cannot cross the closed route using " + method)
		_check(not button.is_pressed() and not room.get_node("Divider/Collision").disabled, "A held box never supplies the switch weight")
	# Unlocking the arrival mission alone must not remove the physical throw gate.
	tutorial.seen["throw"] = true
	tutorial.seen["throw_button"] = true
	tutorial.call("_update_lesson")
	await _step(60)
	_check(not room.get_node("Divider/Collision").disabled and _local().x < 546, "Recorded actions alone cannot open the route")


func _push_and_drop() -> void:
	await _enter()
	Input.action_press("move_right")
	await _step(300)
	_check(not button.is_pressed() and heavy.position.x < 619, "Pushing the free box cannot reach the target")
	_check(_local().x < 546, "The player stops at the gate while pushing")
	await _enter()
	await _grab()
	await _walk_to(480)
	Input.action_release("move_right")
	await _step(15)
	Input.action_release("wall_grab")
	await _step(90)
	_check(player.get_held_object() == null and not button.is_pressed(), "Stationary drop stays on the near side")
	_check(not room.get_node("Divider/Collision").disabled, "Dropping does not open the route")
	await _enter()
	await _grab()
	Input.action_press("move_right")
	await _step(150)
	Input.action_release("move_right")
	await _step(15)
	Input.action_release("wall_grab")
	await _step(90)
	_check(player.get_held_object() == null and not button.is_pressed(), "Stopping at the gate still permits a safe stationary drop")


func _failed_throw_retry() -> void:
	await _enter()
	await _grab()
	await _walk_to(460)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _step(18)
	Input.action_release("wall_grab")
	await _step()
	Input.action_release("move_left")
	await _step(100)
	_check(not button.is_pressed() and not room.get_node("Divider/Collision").disabled, "A missed throw leaves the route closed")
	await _pulse("reset")
	await _step(8)
	_check(_local().x < 100 and absf(heavy.position.x - 230) < 1, "R restores both the player and the missed box")
	_check(player.is_dash_ready() and player.get_held_object() == null and not heavy.freeze, "Retry restores resources and free-box physics")
	_check(not button.is_pressed() and not room.get_node("Divider/Collision").disabled, "Retry resets the actual weight switch and gate")


func _walk_goal() -> void:
	Input.action_press("move_right")
	for frame in 350:
		if tutorial.cleared.has(11):
			break
		Input.action_release("jump")
		if _local().x >= 1150:
			Input.action_release("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release()
	await _step(2)
	_check(tutorial.cleared.has(11) and room.get_node("Goal").is_pressed(), "Throw, cross the opened route, and press the actual arrival switch")
	_check(room.get_node("ExitBarrier/Collision").disabled, "Completing the route opens the room exit")


func _reset_after_success() -> void:
	await _pulse("reset")
	await _step(8)
	_check(not button.is_pressed() and room.get_node("Divider/Collision").disabled, "A cleared throw route remains open after R")
	_check(room.get_node("ExitBarrier/Collision").disabled, "A cleared lesson keeps its normal exit open")
	tutorial.call("_set_room", 11, true)
	player.respawn()
	await _step(8)
	Input.action_press("move_left")
	for frame in 250:
		if _local().x < 500:
			break
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_check(_local().x < 500, "Backtracking from the right entrance crosses a completed throw gate")


func _enter() -> void:
	_release()
	tutorial.call("_set_room", 11, false)
	player.respawn()
	await _step(8)


func _grab() -> void:
	await _walk_to(160)
	Input.action_press("wall_grab")
	await _step(3)
	_check(player.get_held_object() == heavy, "Natural grab acquires the heavy box")


func _walk_to(x: float) -> void:
	Input.action_press("move_right")
	for frame in 150:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Approach timed out at x=%s" % x)


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
		push_error("TUTORIAL_THROW_ROUTE: %s (player=%s box=%s weight=%s)" % [message, _local(), heavy.position, button.total_weight])
