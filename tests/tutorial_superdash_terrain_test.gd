extends "res://tests/tutorial_extension_test.gd"

const DIRECTIONS := [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1),
	Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]
var respawns := 0
var actions: Dictionary = {}
var trials := 0
var pad := false
var save_path := "user://superdash_terrain_%d.cfg" % OS.get_process_id()


func _run() -> void:
	root.get_node("CollectionProgress").save_path = save_path
	root.get_node("CollectionProgress")._collected.clear()
	_new_world()
	await _enter_optional()
	_check(tutorial.STEPS[16].is_empty() and not _room().get_node("Goal").locked, "The real arrival has no Superdash-history lock")
	_check(not _room().has_node("PracticeHint") and not _room().has_node("ArrivalHint"), "Terrain replaces repeated practice and arrival labels")
	await _step(180)
	_check(player.is_on_floor() and respawns == 0, "The entrance permits an unhurried three-second observation")
	_capture("entrance")
	if not OS.get_cmdline_user_args().has("--screenshots") and not OS.get_cmdline_user_args().has("--routes-only"):
		await _alternatives()
		await _retries()
	for raw in [1.0, 0.85]:
		for launch in [575, 590, 605]:
			for delay in [3, 5, 7]:
				if OS.get_cmdline_user_args().has("--screenshots") and [raw, launch, delay] != [0.85, 590, 5]:
					continue
				await _enter_optional()
				pad = raw < 1
				var started := Engine.get_physics_frames()
				await _approach(launch, raw)
				if pad:
					_check(is_equal_approx(Input.get_axis("move_left", "move_right"), 0.7), "Raw joystick 0.85 uses the existing deadzone-adjusted 0.7 movement")
				await _pulse("dash")
				await _step(delay)
				await _pulse("jump")
				await _step(12)
				_check(actions.get("superdash", 0) == 1, "A grounded horizontal dash and buffered jump produce one real Superdash")
				_capture("jump")
				await _finish(raw)
				_check(tutorial.cleared.has(16) and respawns == 0, "The timing profile reaches and presses the real arrival without dying")
				_check(_room().get_node("ExitBarrier/Collision").disabled, "Physical arrival opens the exit")
				_check(Engine.get_physics_frames() - started < 1800, "The checkpoint-to-arrival route stays within thirty seconds")
				print("SUPERDASH_ROUTE raw=%.2f launch=%d delay=%d seconds=%.2f" % [raw, launch, delay, (Engine.get_physics_frames() - started) / 60.0])
	_capture("cleared")
	if not OS.get_cmdline_user_args().has("--screenshots"):
		await _return_from_arrival()
		await _main_completion_and_boundary()
	_release()
	print("TUTORIAL_SUPERDASH_TERRAIN_TEST_%s (%d checks, %d negative routes)" % ["FAILED" if failed else "OK", checks, trials])
	tutorial.queue_free()
	await _step(20)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit(1 if failed else 0)


func _alternatives() -> void:
	# Actual entrance, unchanged abilities: normal jumps and eight-direction air dashes.
	for launch in [630, 650, 670, 678]:
		for direction in DIRECTIONS:
			for delay in [-1, 0, 3, 6, 10, 16]:
				await _enter_optional()
				await _approach(launch)
				await _pulse("jump")
				await _reject(direction, delay, "ordinary jump / delayed air dash")
	print("SUPERDASH_AIR_ALTERNATIVES_OK ", trials)
	# Ground diagonals into the low ceiling, including a later jump and wall actions.
	for launch in [380, 530, 630, 670]:
		for direction in DIRECTIONS:
			for jump_delay in [-1, 4, 10, 18]:
				if direction.y == 0 and direction.x != 0 and jump_delay >= 0:
					continue # This is the intended ground-Dash-to-Jump.
				await _enter_optional()
				await _approach(launch)
				_move(direction)
				await _pulse("dash")
				var reached := false
				for frame in 180:
					if respawns > 0: break
					if not player.is_dashing(): _move(Vector2.RIGHT)
					if frame == jump_delay: await _pulse("jump")
					await _step()
					reached = reached or _on_landing() or tutorial.cleared.has(16)
				_check(not reached and not actions.has("superdash"), "A ground diagonal / ceiling collision cannot replace Superdash: %s at %d wait %d" % [direction, launch, jump_delay])
				trials += 1
	print("SUPERDASH_GROUND_ALTERNATIVES_OK ", trials)
	await _refilled_dash_alternatives()
	# Coyote jumps after a natural walk off the edge; no artificial launch coordinates.
	for wait in [0, 2, 4, 6]:
		for direction in DIRECTIONS:
			for dash_delay in [-1, 0, 6, 12]:
				await _enter_optional()
				await _approach(678)
				for frame in 120:
					if not player.is_on_floor() or respawns > 0: break
					await _step()
				await _step(wait)
				if respawns == 0: await _pulse("jump")
				await _reject(direction, dash_delay, "coyote jump / eight-direction dash")
	print("SUPERDASH_COYOTE_ALTERNATIVES_OK ", trials)
	# Repeat Jump and Grab/Up/WallKick against actual roof faces and both outer walls.
	for launch in [72, 330, 380, 630, 678]:
		for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP]:
			await _enter_optional()
			await _approach(launch)
			Input.action_press("wall_grab")
			await _pulse("jump")
			await _reject(direction, 6, "Grab / repeated wall jump", true)
	await _enter_optional()
	_move(Vector2.LEFT)
	await _step(15)
	_check(tutorial.room_index == 16, "The left-wall attempt begins before the actual room boundary")
	await _pulse("jump")
	await _reject(Vector2(1, -1), 6, "left outer wall / diagonal dash", true)


func _refilled_dash_alternatives() -> void:
	var ready_starts := 0
	for launch in [400, 450]:
		for wait in [18, 24]:
			for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP]:
				for delay in [0, 6, 12]:
					await _enter_optional()
					await _approach(launch)
					await _pulse("dash")
					await _step(wait)
					if respawns == 0:
						if player.is_on_floor() and player.is_dash_ready(): ready_starts += 1
						await _pulse("jump")
					await _reject(direction, delay, "refilled ground dash / expired Superdash / normal jump")
	_check(ready_starts > 0, "The delayed fixtures include an actual restored ground dash before a normal jump and second air dash")
	print("SUPERDASH_REFILLED_ALTERNATIVES_OK ", ready_starts)


func _reject(direction: Vector2, delay: int, label: String, wall_actions: bool = false) -> void:
	var reached := false
	for frame in 210:
		if respawns > 0 or tutorial.room_index != 16: break
		if frame == delay:
			_move(direction)
			await _pulse("dash")
		if not player.is_dashing():
			_move(Vector2(1, -1) if wall_actions else Vector2.RIGHT)
		if wall_actions:
			Input.action_press("wall_grab")
			if frame % 6 == 0: await _pulse("jump")
		await _step()
		reached = reached or _on_landing() or tutorial.cleared.has(16)
	_check(not reached and not actions.has("superdash"), "%s cannot land on the exit or press its unlocked goal: %s delay %d" % [label, direction, delay])
	trials += 1


func _retries() -> void:
	await _enter_optional()
	await _approach(678)
	for frame in 180:
		if respawns > 0: break
		await _step()
	_release()
	await _step(6)
	_check(respawns == 1 and _local().distance_to(Vector2(72, 614)) < 3, "An actual walk into the floor spikes retries at the same entrance")
	_check(not tutorial.cleared.has(16) and not _room().get_node("Goal").locked and player.is_dash_ready(), "Spike retry restores dash without adding a history lock")
	await _enter_optional()
	var pending: Area2D = load("res://scenes/scroll_collectible.tscn").instantiate()
	pending.stage_id = "tutorial"
	pending.scroll_id = "superdash_retry_fixture"
	pending.position = Vector2(715, 570)
	_room().add_child(pending)
	await _approach(590)
	await _pulse("dash")
	await _step(4)
	await _pulse("jump")
	await _step(10)
	_check(pending._follower == player and not pending._secured, "The actual flying player touches the native test scroll without securing it")
	_release()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_R
	event.keycode = KEY_R
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(6)
	_check(respawns == 1 and _local().distance_to(Vector2(72, 614)) < 3 and player.velocity.length() < 1, "Actual R during the Superdash restores the entrance without residual speed")
	_check(tutorial.seen.is_empty() and not tutorial.cleared.has(16), "R clears flight telemetry and leaves the optional room unfinished")
	_check(pending._follower == null and not pending._secured and pending.global_position == pending._origin and not root.get_node("CollectionProgress").has_scroll("tutorial", pending.scroll_id), "Actual R returns an unsecured native scroll to its origin without saving")
	pending.queue_free()
	await _step()


func _return_from_arrival() -> void:
	_release()
	await _pulse("reset")
	await _step(6)
	_check(respawns == 1 and _local().distance_to(Vector2(72, 614)) < 3, "Retry returns from the completed arrival to the safe entrance")
	_check(tutorial.cleared.has(16) and _room().get_node("ExitBarrier/Collision").disabled, "Retry retains the physically completed optional lesson")


func _main_completion_and_boundary() -> void:
	_release()
	tutorial.cleared.erase(15)
	tutorial.cleared.erase(16)
	tutorial.completed = false
	_new_world()
	await _enter(15)
	respawns = 0
	await _glider_combo_course()
	_check(tutorial.completed and tutorial.cleared.has(15) and not tutorial.cleared.has(16), "The real sixteenth room completes the main course without Superdash")
	_move(Vector2.RIGHT)
	for frame in 240:
		if tutorial.room_index == 16 and not tutorial.transitioning: break
		await _step()
	_release()
	await _step(4)
	_check(tutorial.room_index == 16 and player.is_on_floor() and player.controls_enabled, "The real 16-to-17 boundary reaches the safe practice entrance")
	respawns = 0
	actions.clear()
	await _approach(590)
	await _pulse("dash")
	await _step(4)
	await _pulse("jump")
	await _finish(1)
	_check(tutorial.cleared.has(16) and tutorial.completed and respawns == 0, "The optional real arrival also works after completing the main course")
	await _return_from_arrival()
	_move(Vector2.LEFT)
	for frame in 120:
		if tutorial.room_index == 15 and not tutorial.transitioning: break
		await _step()
	_release()
	_check(tutorial.room_index == 15 and player.is_on_floor() and tutorial.completed and tutorial.cleared.has(16), "Actual Goal then R and left exit preserve both completion states")
	await _grab("Parachute")
	for frame in 600:
		if tutorial.room_index == 16 and not tutorial.transitioning: break
		await _step()
	_release()
	_check(tutorial.room_index == 16 and player.is_on_floor() and tutorial.completed and tutorial.cleared.has(16), "Carrying the real parachute across Room16 re-enters the completed optional practice room")
	_check(_room().get_node("ExitBarrier/Collision").disabled and root.get_node("CollectionProgress").get_count("tutorial") == 0, "Re-entry retains its open exit and does not save the canceled test scroll")


func _new_world() -> void:
	if is_instance_valid(tutorial): tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action): actions[action] = actions.get(action, 0) + 1)


func _enter_optional() -> void:
	_release()
	if tutorial.get_node("Rooms/Room17/Goal").is_pressed(): _new_world()
	pad = false
	tutorial.cleared.erase(16)
	await _enter(16)
	respawns = 0
	actions.clear()


func _approach(target: float, raw: float = 1) -> void:
	_move(Vector2(raw, 0))
	for frame in 900:
		if _local().x >= target or respawns > 0: return
		await _step()
	_check(false, "The natural approach reaches its tested launch position")


func _finish(raw: float) -> void:
	for frame in 600:
		if tutorial.cleared.has(16) or respawns > 0: break
		_move(Vector2(raw, 0))
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall(): Input.action_press("jump")
		if _local().x >= 1035: _move(Vector2.ZERO)
		await _step()
	_release()


func _on_landing() -> bool:
	if not player.is_on_floor(): return false
	for index in player.get_slide_collision_count():
		if player.get_slide_collision(index).get_collider() == _room().get_node("Landing"): return true
	return false


func _move(direction: Vector2) -> void:
	if pad:
		_joy(JOY_AXIS_LEFT_X, direction.x)
		_joy(JOY_AXIS_LEFT_Y, direction.y)
		return
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	if direction.x: Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y: Input.action_press("move_down" if direction.y > 0 else "move_up")


func _joy(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release() -> void:
	super._release()
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]: _joy(axis, 0)


func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial-superdash")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/tutorial-superdash/%s.png" % label)
