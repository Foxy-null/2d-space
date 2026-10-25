extends SceneTree

const DIRECTIONS := [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1),
	Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0
var umbrella_top := INF
var frames := 0
var bare_max := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://tutorial_carry_learning_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _new_world()
	_check(tutorial.STEPS[13].is_empty() and not _room().get_node("Goal").locked, "The terrain-led arrival has no action-history lock")
	_check(not _room().has_node("GlideHint") and not _room().has_node("ReleaseHint"), "The visible umbrella and landing replace duplicate action labels")
	await _step(120)
	_check(respawns == 0 and player.is_on_floor(), "The entrance permits safe observation before moving")
	_capture("entrance")
	if not OS.get_cmdline_user_args().has("--screenshots") and not OS.get_cmdline_user_args().has("--routes-only"):
		for launch_at in [220, 280, 300]:
			for jump_kind in ["walk", "jump", "superdash"]:
				for direction in DIRECTIONS:
					for dash_frame in [-1, 0, 6, 12, 18, 24, 30, 36, 42, 48, 54, 60]:
						await _without_parachute(launch_at, jump_kind, direction, dash_frame)
		await _ground_dash_alternatives()
		await _umbrella_step_alternatives()
		await _wall_alternatives()
		await _retry()
	for axis in [1.0, 0.85]:
		for dash_frame in [24, 48, 80]:
			for release_at in [-1, 1025, 1050]:
				if OS.get_cmdline_user_args().has("--screenshots") and [axis, dash_frame, release_at] != [0.85, 48, 1050]:
					continue
				await _new_world()
				await _crossing(axis, dash_frame, release_at)
	await _test_backtrack()
	if not OS.get_cmdline_user_args().has("--screenshots") and not OS.get_cmdline_user_args().has("--routes-only"):
		await _new_world()
		await _crossing(1.0, -1, -1)
	_release()
	print("GLIDE_BARE_MAX_X %.3f; landing starts at %.1f" % [bare_max, _landing_corner().x])
	print("TUTORIAL_CARRY_LEARNING_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	tutorial.queue_free()
	await _step(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	quit(1 if failed else 0)


func _without_parachute(launch_at: float, jump_kind: String, direction: Vector2, dash_frame: int) -> void:
	await _enter()
	await _walk_to(launch_at)
	_check(respawns == 0 and _local().x >= launch_at, "The bypass starts at the intended real coyote/ground position")
	if jump_kind == "superdash":
		await _pulse("dash")
		await _step(4)
	if jump_kind != "walk":
		await _pulse("jump")
	await _step(maxi(0, dash_frame))
	if dash_frame >= 0:
		_drive(direction)
		await _pulse("dash")
	_drive(Vector2.RIGHT)
	_check(not await _bare_landing(), "No umbrella: launch=%d kind=%s dash=%d aim=%s cannot reach the landing" % [launch_at, jump_kind, dash_frame, direction])
	_release()


func _bare_landing() -> bool:
	for frame in 200:
		if respawns > 0 or tutorial.room_index != 13:
			return tutorial.room_index > 13
		if _local().y <= _landing_corner().y - 26:
			bare_max = maxf(bare_max, _local().x)
		if _on_landing() or tutorial.cleared.has(13):
			return true
		# Grabbing the exit's side cannot create a floor on a one-way platform.
		if _local().x > 850:
			Input.action_press("wall_grab")
			Input.action_press("move_up")
		await _step()
	return false


func _ground_dash_alternatives() -> void:
	for launch in [72, 120, 180]:
		for jump_delay in [0, 4, 10]:
			for dash_delay in [12, 24, 36, 42, 48, 60]:
				for direction in DIRECTIONS.slice(0, 3):
					await _enter()
					await _walk_to(launch)
					await _pulse("dash")
					await _step(jump_delay)
					await _pulse("jump")
					await _step(dash_delay)
					_drive(direction)
					await _pulse("dash")
					_drive(Vector2.RIGHT)
					_check(not await _bare_landing(), "Ground Dash/Superdash plus an attempted second dash cannot replace the umbrella")


func _umbrella_step_alternatives() -> void:
	for delay in [0, 24, 42, 54]:
		for direction in DIRECTIONS.slice(0, 3):
			for grab_jump in [false, true]:
				await _enter()
				await _pulse("jump")
				var umbrella: Grabbable = _room().get_node("Parachute")
				var stood := false
				for frame in 110:
					var dx := umbrella.position.x - _local().x
					_drive(Vector2(signf(dx), 0) if absf(dx) > 5 else Vector2.ZERO)
					await _step()
					if player.is_on_floor() and _local().y < 200:
						stood = true
						break
				_check(stood and player.get_held_object() == null, "A real jump stands on the free umbrella as a step")
				_drive(Vector2.RIGHT)
				if grab_jump:
					Input.action_press("wall_grab")
				await _pulse("jump")
				if grab_jump:
					_check(player.get_held_object() == umbrella and player.velocity.y < -620, "Simultaneous Grab plus Jump performs an ordinary step-assisted jump")
					Input.action_release("wall_grab")
				await _step(delay)
				_drive(direction)
				await _pulse("dash")
				_drive(Vector2.RIGHT)
				_check(not await _bare_landing() and not tutorial.seen.has("glide"), "Umbrella step plus ordinary jump and dash cannot bypass actual glide")


func _wall_alternatives() -> void:
	for delay in [0, 12, 24, 36, 48]:
		for direction in DIRECTIONS.slice(0, 3):
			await _enter()
			await _pulse("jump")
			await _walk_to(280)
			_drive(Vector2.LEFT)
			for frame in 60:
				if _local().y > 330:
					break
				await _step()
			Input.action_press("wall_grab")
			Input.action_press("move_up")
			var climbed := false
			for frame in 60:
				await _step()
				if player.is_wall_grabbing():
					climbed = true
					break
				if respawns > 0:
					break
			_check(climbed, "The entrance-wall alternative reaches a real climbable wall")
			await _pulse("jump")
			Input.action_release("wall_grab")
			_drive(Vector2.RIGHT)
			_check(tutorial.seen.has("wall_jump"), "The wall alternative performs an actual kick")
			await _step(delay)
			_drive(direction)
			await _pulse("dash")
			_drive(Vector2.RIGHT)
			_check(not await _bare_landing(), "Entrance wall climb/kick plus dash cannot reach the opposite landing")


func _retry() -> void:
	await _new_world()
	await _grab()
	await _walk_to(220)
	await _pulse("jump")
	await _step(48)
	_check(tutorial.seen.has("glide") and not player.is_on_floor(), "R regression begins during actual glide")
	await _reset_key()
	_check(respawns == 1 and _local().distance_to(_room().get_node("Spawn").position) < 2 and player.get_held_object() == null, "Real R returns to the entrance and releases the umbrella")
	_check(tutorial.seen.is_empty() and not tutorial.cleared.has(13) and not _room().get_node("Goal").locked, "Retry clears temporary history while keeping the terrain-led goal available")
	_check(_room().get_node("Parachute").position.distance_to(Vector2(170, 223.4)) < 5, "R restores the visible entrance umbrella")
	await _grab()
	await _walk_to(220)
	await _pulse("jump")
	await _step(48)
	Input.action_release("wall_grab")
	_drive(Vector2.RIGHT)
	for frame in 200:
		if respawns > 1:
			break
		await _step()
	_release()
	_check(respawns == 2 and not tutorial.cleared.has(13), "An early release falls and restores the unfinished entrance")
	await _grab()
	_check(player.get_held_object() == _room().get_node("Parachute"), "The restored umbrella can be acquired again after a fall")
	await _reset_key()


func _crossing(axis: float, dash_frame: int, release_at: int) -> void:
	var started := frames
	await _grab()
	_release_move()
	_joy(axis)
	if axis < 1:
		_check(is_equal_approx(Input.get_axis("move_left", "move_right"), 0.7), "Raw stick 0.85 preserves the existing deadzone-adjusted 0.7 movement")
	for frame in 160:
		if _local().x >= 220:
			break
		await _step()
	await _pulse("jump")
	if dash_frame >= 0:
		await _step(dash_frame)
		_drive(Vector2.RIGHT)
		await _pulse("dash")
		_release_move()
		_joy(axis)
	var released := false
	var landed := false
	for frame in 400:
		if respawns > 0 or tutorial.cleared.has(13):
			break
		if release_at >= 0 and not released and _local().x >= release_at:
			_check(not player.is_on_floor() and tutorial.seen.has("glide"), "Release is optional and occurs after a real airborne glide")
			_capture("release")
			Input.action_release("wall_grab")
			released = true
		if not landed and _on_landing():
			landed = true
			_capture("landing")
		Input.action_release("jump")
		# A thrown umbrella can settle underfoot at the arrival; Grab frees the cap.
		if released and landed and player.is_on_floor() and _local().x > 1100:
			Input.action_press("wall_grab")
		if _local().x >= 1140:
			_joy(0)
			_release_move()
		elif player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		if frame == 24:
			_capture("glide")
		await _step()
	_check(respawns == 0 and landed and tutorial.cleared.has(13) and _room().get_node("Goal").is_pressed(), "Held/released glide reaches the real platform and presses the arrival without a death")
	_check(tutorial.seen.has("glide") and umbrella_top >= 0, "The route uses slow fall and keeps the entire held umbrella on screen")
	_check(release_at < 0 or released, "Requested release positions are reached before arrival")
	if release_at < 0:
		_check(not tutorial.seen.has("parachute_release") and not tutorial.seen.has("fast_fall"), "Keeping the umbrella works without release/fast-fall history")
	print("GLIDE_ROUTE raw=%.2f dash=%d release=%d seconds=%.2f respawns=%d top=%.2f" % [axis, dash_frame, release_at, (frames - started) / 60.0, respawns, umbrella_top])
	_capture("cleared")
	_drive(Vector2.RIGHT)
	_joy(0)
	for frame in 160:
		if tutorial.room_index == 14 and not tutorial.transitioning:
			break
		# A buffered joystick zero must not cancel the exit input.
		_drive(Vector2.RIGHT)
		await _step()
	_release()
	_check(tutorial.room_index == 14 and player.controls_enabled and respawns == 1, "The landing leads safely into Room15")


func _test_backtrack() -> void:
	_drive(Vector2.LEFT)
	for frame in 240:
		if tutorial.room_index == 13 and not tutorial.transitioning:
			break
		_drive(Vector2.LEFT)
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 13 and player.controls_enabled and player.is_on_floor(), "Walking left from Room15 returns safely to Room14")
	_check(_local().distance_to(_room().get_node("Return").position) < 10, "Backtracking reaches the safe entrance beside the umbrella")
	var before_reset := respawns
	await _reset_key()
	_check(respawns == before_reset + 1 and _local().distance_to(_room().get_node("Return").position) < 2, "R after backtracking preserves its entrance checkpoint")
	_check(_room().get_node("Parachute").position.distance_to(Vector2(170, 223.4)) < 5 and tutorial.cleared.has(13), "Backtracking retry restores the umbrella and preserves the cleared room")
	_drive(Vector2.LEFT)
	for frame in 180:
		if tutorial.room_index == 12 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 12 and player.controls_enabled and player.is_on_floor(), "The safe entrance leads back into Room13")
	var previous: Node2D = tutorial.rooms.get_child(12)
	_drive(Vector2.LEFT)
	for frame in 240:
		if player.global_position.x - previous.global_position.x <= 230:
			break
		await _step()
	_drive(Vector2.ZERO)
	Input.action_press("wall_grab")
	await _step(3)
	_check(player.get_held_object() == previous.get_node("Creature"), "The neighboring-room bypass starts with a real acquired companion")
	_drive(Vector2.RIGHT)
	for frame in 300:
		if tutorial.room_index == 13 and not tutorial.transitioning:
			break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 13 and player.controls_enabled and player.is_on_floor() and _local().distance_to(_room().get_node("Spawn").position) < 10, "Room14 can be re-entered safely from Room13")
	_check(player.get_held_object() == null and not player.is_air_jump_ready(), "Room entry cannot import a companion or personal extra-jump right")


func _walk_to(x: float) -> void:
	_drive(Vector2.RIGHT)
	for frame in 250:
		if _local().x >= x:
			break
		await _step()


func _on_landing() -> bool:
	if not player.is_on_floor():
		return false
	for index in player.get_slide_collision_count():
		var body: Object = player.get_slide_collision(index).get_collider()
		if body == _room().get_node("ExitFloor") or body == _room().get_node("Goal/Cap"):
			return true
	return false


func _drive(direction: Vector2) -> void:
	_release_move()
	if direction.x > 0: Input.action_press("move_right")
	if direction.x < 0: Input.action_press("move_left")
	if direction.y > 0: Input.action_press("move_down")
	if direction.y < 0: Input.action_press("move_up")


func _release_move() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _reset_key() -> void:
	_release()
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(5)


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
		frames += 1
		if is_instance_valid(player) and player.get_held_object() != null:
			var sprite: AnimatedSprite2D = player.get_held_object().get_node("Visuals/Body")
			var size: Vector2 = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size()
			var rect := Rect2(-size * 0.5 + sprite.offset, size)
			for corner in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
				umbrella_top = minf(umbrella_top, sprite.to_global(corner).y)


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
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial-glide")
		root.get_texture().get_image().save_png("res://docs/screenshots/tutorial-glide/%s.png" % name)
