extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var advanced_reached := 0
var umbrella_top := INF


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _new_world()
	_capture("entrance")
	# Reachability is measured before the mission lock, so it cannot hide a bypass.
	for launch_at in [220, 280, 300]:
		for jump_kind in ["walk", "jump", "superdash"]:
			for direction in ["right", "up_right", "up", "up_left", "left", "down_left", "down", "down_right"]:
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
	_check(_room().get_node("Parachute").position.distance_to(Vector2(170, 203.4)) < 5, "Retry restores the parachute on the entrance")
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
	for axis in [0.0, 0.85]:
		for release_at in [925, 950, 975, 1000, 1025, 1050]:
			await _new_world()
			await _crossing(axis, release_at)
	await _test_backtrack()
	_release()
	print("CARRY_BARE_INPUTS: 864 samples; %d advanced routes reach the landing" % advanced_reached)
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
	_check(_local().distance_to(Vector2(72, 224)) < 10, "Backtracking lands beside the entrance parachute instead of beyond the valley")
	var before_reset := respawns
	await _pulse("reset")
	await _step(4)
	_check(respawns == before_reset + 1 and _local().distance_to(Vector2(72, 224)) < 2, "Retry after backtracking keeps the safe entrance checkpoint")
	_check(_room().get_node("Parachute").position.distance_to(Vector2(170, 203.4)) < 5 and tutorial.cleared.has(13), "Backtracking retry restores the parachute and preserves the cleared lesson")
	Input.action_press("move_left")
	for frame in 180:
		if tutorial.room_index == 12 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 12 and player.controls_enabled and player.is_on_floor(), "Walking left after retry can continue to Room13")
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 13 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 13 and player.controls_enabled and player.is_on_floor() and _local().distance_to(Vector2(72, 224)) < 10, "The higher entrance can be re-entered from Room13")


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
	var landing := _landing_corner()
	var aim: Vector2 = {"right": Vector2.RIGHT, "up_right": Vector2(1, -1), "up": Vector2.UP,
		"up_left": Vector2(-1, -1), "left": Vector2.LEFT, "down_left": Vector2(-1, 1),
		"down": Vector2.DOWN, "down_right": Vector2(1, 1)}[direction]
	for frame in 160:
		if frame == dash_frame:
			for action in ["move_left", "move_right", "move_up", "move_down"]:
				Input.action_release(action)
			if aim.x < 0: Input.action_press("move_left")
			if aim.x > 0: Input.action_press("move_right")
			if aim.y < 0: Input.action_press("move_up")
			if aim.y > 0: Input.action_press("move_down")
			await _pulse("dash")
			for action in ["move_left", "move_up", "move_down"]:
				Input.action_release(action)
			Input.action_press("move_right")
		# Try to rescue a late crossing by grabbing/climbing the landing's side.
		if _local().x > 850:
			Input.action_press("wall_grab")
			Input.action_press("move_up")
		await _step()
		reached = reached or (_local().x >= landing.x - 18 and _local().y <= landing.y - 26)
		if respawns > 0:
			break
	if jump_kind != "superdash" and dash_frame <= 12:
		_check(not reached and respawns > 0, "Walking, jumping and early %s dash at %d from %d cannot reach the landing without a parachute" % [direction, dash_frame, launch_at])
	elif reached:
		advanced_reached += 1
	if launch_at == 300 and jump_kind == "jump" and direction == "up_right" and dash_frame == 42:
		_check(reached and not tutorial.cleared.has(13) and not tutorial.seen.has("glide"), "The documented late coyote-jump/diagonal-dash alternative reaches the floor while the umbrella lesson stays locked")
		_capture("advanced-bare-route")
	_release()


func _crossing(axis: float, release_at: float) -> void:
	await _grab()
	if axis > 0:
		Input.action_release("move_right")
		_joy(axis)
		_check(absf(Input.get_axis("move_left", "move_right") - 0.7) < 0.001, "Joystick 0.85 uses the existing 0.5 deadzone")
	else:
		Input.action_press("move_right")
	for frame in 180:
		if _local().x >= 220:
			break
		await _step()
	await _pulse("jump")
	for frame in 600:
		if _local().x >= release_at or respawns > 0:
			break
		await _step()
	_check(respawns == 0 and _local().x >= release_at and not player.is_on_floor() and tutorial.seen.has("glide"), "Real glide stays airborne until release=%d with joystick=%f" % [release_at, axis])
	_check(umbrella_top >= 0.0 and not tutorial.seen.has("dash"), "The whole held umbrella stays on screen without an extra dash")
	var released_at := _local()
	Input.action_release("wall_grab")
	var first_landing := false
	var fast_before_landing := false
	for frame in 400:
		if tutorial.cleared.has(13) or respawns > 0:
			break
		if not first_landing and player.is_on_floor():
			first_landing = true
			fast_before_landing = tutorial.seen.has("fast_fall")
		Input.action_release("jump")
		if _local().x >= 1140:
			_joy(0.0)
			Input.action_release("move_right")
		if player.is_on_floor() and (player.is_on_wall() or _local().x >= 1100):
			Input.action_press("jump")
		await _step()
	_check(first_landing and fast_before_landing, "Release=%d with joystick=%f produces fast fall before the first landing, independently of the arrival jump" % [release_at, axis])
	_check(respawns == 0 and tutorial.cleared.has(13), "The natural crossing presses the real arrival switch")
	print("CARRY_RELEASE_WINDOW axis=%f target=%d actual=%s umbrella_top=%f" % [axis, release_at, released_at, umbrella_top])
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 14 and not tutorial.transitioning:
			break
		await _step()
	_check(tutorial.room_index == 14 and player.controls_enabled, "The lower landing still crosses the taller Room15 boundary")
	_release()


func _new_world() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	# Open the preceding exit as normal progression would, including its collision.
	tutorial.cleared[12] = true
	tutorial.call("_set_room", 12, false)
	player.respawn()
	await _step(3)
	await _enter()
	umbrella_top = INF


func _landing_corner() -> Vector2:
	var collision: CollisionShape2D = _room().get_node("ExitFloor/Collision")
	return collision.to_global(collision.shape.get_rect().position) - _room().global_position


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
		if is_instance_valid(player) and player.get_held_object() != null:
			var sprite: AnimatedSprite2D = player.get_held_object().get_node("Visuals/Body")
			var size: Vector2 = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size()
			var rect := Rect2(-size * 0.5 + sprite.offset, size)
			for corner in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
				umbrella_top = minf(umbrella_top, sprite.to_global(corner).y)
			if not player.is_on_floor() and absf(player.velocity.y) < 32:
				_capture("apex")


func _release() -> void:
	_joy(0.0)
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _joy(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_CARRY_LEARNING: %s (position=%s velocity=%s seen=%s)" % [message, _local(), player.velocity, tutorial.seen.keys()])


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/tutorial-carry-%s.png" % name)
