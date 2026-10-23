extends SceneTree

const DIRECTIONS := [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1),
	Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]

var tutorial: Node
var player: PlayerController
var room: Node2D
var pad := false
var failed := false
var checks := 0
var respawns := 0
var frames := 0
var carry_top := INF
var boot_only_collected := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _new_world()
	_check(tutorial.STEPS[14].is_empty() and not room.get_node("Goal").locked, "Terrain requires both resources without an action-history lock")
	_check(not room.has_node("ComboHint") and not room.has_node("CountHint"), "The airborne boot and high landing replace repeated instructions")
	await _step(120)
	_check(respawns == 0 and player.is_on_floor(), "The low entrance permits safe observation")
	_capture("entrance")
	if not OS.get_cmdline_user_args().has("--screenshots") and not OS.get_cmdline_user_args().has("--routes-only"):
		await _single_resource_alternatives()
		await _superdash_alternatives()
		await _step_alternatives()
		await _wall_alternatives()
		await _retry()
	for speed in [1.0, 0.85]:
		for first in [16, 20, 24]:
			for second in [16, 20, 24]:
				for third in [16, 20, 24]:
					if OS.get_cmdline_user_args().has("--screenshots") and [speed, first, second, third] != [0.85, 20, 20, 20]:
						continue
					await _new_world()
					var started := frames
					await _prepare("both", speed, 380)
					await _launch(first, second, third)
					await _finish_goal()
					print("COMBO_REQUIRED raw=%.2f gaps=%d/%d/%d seconds=%.2f respawns=%d sprite_top=%.2f" % [speed, first, second, third, (frames - started) / 60.0, respawns, carry_top])
					await _next_room()
	await _backtrack()
	if not OS.get_cmdline_user_args().has("--screenshots"):
		await _boot_roundtrip()
	_release()
	print("TUTORIAL_COMBO_JUMP_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _prepare(mode: String, speed: float, launch: float) -> void:
	await _enter()
	pad = speed < 1
	if mode == "creature":
		var crystal: Area2D = room.get_node("JumpCrystal")
		crystal.process_mode = Node.PROCESS_MODE_DISABLED
		crystal.monitoring = false
		crystal.get_node("CollisionShape2D").disabled = true
	if mode in ["both", "creature"]:
		await _grab_creature()
	await _walk_to(launch, speed)
	if mode == "both":
		_check(player.get_held_object() == room.get_node("Creature") and not player.is_air_jump_ready(), "The entrance provides a held companion; the boot must be acquired in flight")
	if pad:
		_check(is_equal_approx(Input.get_axis("move_left", "move_right"), 0.7), "Raw joystick 0.85 uses the existing deadzone-adjusted 0.7 movement")


func _launch(first: int, second: int, third: int) -> void:
	await _jump()
	await _step(first)
	await _jump()
	_check(tutorial.seen.has("creature_jump") and room.get_node("Creature").extra_jump_count() == 0, "The first air jump spends the held companion")
	_capture("companion")
	await _step(second)
	_check(player.is_air_jump_ready() and tutorial.seen.has("jump_crystal") and not player.is_on_floor(), "The companion jump reaches the real airborne boot before the next jump")
	await _jump()
	_check(tutorial.seen.has("air_jump") and player.get_available_extra_jump_count() == 0, "The next air jump spends the newly acquired boot in the same flight")
	_capture("boot")
	await _step(third)
	_move(Vector2.UP)
	await _pulse_dash()
	_move(Vector2(0.85 if pad else 1.0, 0))
	_check(await _land_high() and respawns == 0, "Both jumps plus an upward dash reach the wide one-way rest without a death")
	_check(player.get_available_extra_jump_count() == 1 and not player.is_air_jump_ready() and player.is_dash_ready(), "Landing refills the companion and dash while the spent boot stays spent")
	_capture("landing")


func _finish_goal() -> void:
	for frame in 220:
		if tutorial.cleared.has(14) or respawns > 0:
			break
		_move(Vector2(0.85 if pad else 1.0, 0))
		await _step()
	_move(Vector2.ZERO)
	_check(respawns == 0 and tutorial.cleared.has(14) and room.get_node("Goal").is_pressed(), "Walking from the high rest onto the lower arrival presses the real cap")
	_check(carry_top >= 0 and tutorial.seen.has("creature_jump") and tutorial.seen.has("air_jump"), "The entire held companion remains on screen throughout the route")
	_capture("cleared")


func _next_room() -> void:
	_move(Vector2(0.85 if pad else 1.0, 0))
	for frame in 200:
		if tutorial.room_index == 15 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 15 and player.controls_enabled and respawns == 1, "The completed arrival leads into Room16 with only its transition respawn")
	_check(player.get_held_object() != room.get_node("Creature") and not player.is_air_jump_ready(), "The next lesson receives neither the preceding companion nor a boot right")


func _single_resource_alternatives() -> void:
	for launch in [380, 480, 540]:
		for direction in DIRECTIONS:
			for delay in [12, 20, 28]:
				for extra_delay in [12, 20, 28]:
					await _prepare("boot", 1.0, launch)
					await _jump()
					await _step(delay)
					_move(direction)
					await _pulse_dash()
					_move(Vector2.RIGHT)
					await _step(extra_delay)
					if tutorial.seen.has("jump_crystal"):
						boot_only_collected += 1
					await _jump()
					_check(not await _alternative_landing(), "Boot only: jump/dash/boot cannot replace the companion")
				for dash_delay in [12, 20, 28]:
					await _prepare("creature", 1.0, launch)
					await _jump()
					await _step(delay)
					await _jump()
					await _step(dash_delay)
					_move(direction)
					await _pulse_dash()
					_move(Vector2.RIGHT)
					_check(not await _alternative_landing(), "Companion only: its jump plus any dash cannot replace the boot")
	_check(boot_only_collected > 0, "Single-resource alternatives include actual airborne boot collections")


func _superdash_alternatives() -> void:
	for launch in [72, 180, 380, 480]:
		for jump_delay in [0, 4, 10]:
			for direction in DIRECTIONS:
				await _prepare("boot", 1.0, launch)
				await _pulse_dash()
				await _step(jump_delay)
				await _jump()
				await _step(20)
				_move(direction)
				await _pulse_dash()
				_move(Vector2.RIGHT)
				await _step(20)
				await _jump()
				_check(not await _alternative_landing(), "Ground Dash/Superdash and a collected boot cannot bypass the companion")


func _step_alternatives() -> void:
	for grab_jump in [false, true]:
		for delay in [16, 24, 32]:
			for direction in DIRECTIONS.slice(0, 3):
				for boot_delay in [12, 24, 36]:
					await _enter()
					await _jump()
					var creature: Grabbable = room.get_node("Creature")
					var stood := false
					for frame in 110:
						var dx := creature.position.x - _local().x
						_move(Vector2(signf(dx), 0) if absf(dx) > 5 else Vector2.ZERO)
						await _step()
						if player.is_on_floor() and _local().y < 630:
							stood = true
							break
					_check(stood, "An actual jump stands on the free companion")
					_move(Vector2.RIGHT)
					_grab(grab_jump)
					await _jump()
					if grab_jump:
						_check(player.get_held_object() == creature and player.velocity.y < -620, "Simultaneous Grab plus Jump uses a step-assisted ordinary jump")
					await _step(delay)
					_move(direction)
					await _pulse_dash()
					_move(Vector2.RIGHT)
					await _step(boot_delay)
					# Spend the boot only when acquired; preserve the unused creature.
					if player.is_air_jump_ready():
						await _jump()
					_check(not await _alternative_landing() and not tutorial.seen.has("creature_jump"), "The companion step plus boot/dash cannot replace its actual extra jump")


func _wall_alternatives() -> void:
	for delay in [0, 12, 24]:
		await _prepare("boot", 1.0, 530)
		await _step(6)
		_move(Vector2.LEFT)
		await _pulse_dash()
		await _step(10)
		await _jump()
		_check(tutorial.seen.has("wall_jump"), "The outside entrance-face alternative makes a real wall kick")
		_move(Vector2.RIGHT)
		await _step(delay)
		_move(Vector2.UP)
		await _pulse_dash()
		_move(Vector2.RIGHT)
		_check(not await _alternative_landing(), "An entrance-wall kick cannot replace both air jumps")


func _alternative_landing() -> bool:
	for frame in 220:
		if tutorial.room_index != 14:
			return tutorial.room_index > 14
		if respawns > 0:
			return false
		if _on_high() or tutorial.cleared.has(14):
			return true
		if _local().x > 1000:
			_grab(true)
			Input.action_press("move_up")
		await _step()
	return false


func _retry() -> void:
	await _new_world()
	await _prepare("both", 1.0, 380)
	await _jump()
	await _step(20)
	await _jump()
	await _step(20)
	_check(player.is_air_jump_ready() and player.get_held_object() != null, "Real R starts after receiving the airborne boot")
	_release()
	await _reset_key()
	_check(respawns == 1 and _local().distance_to(room.get_node("Spawn").position) < 2 and not tutorial.cleared.has(14), "R restores the unfinished entrance")
	_check(player.get_held_object() == null and not player.is_air_jump_ready() and room.get_node("JumpCrystal").visible and room.get_node("Creature").extra_jump_count() == 1, "R restores both items and removes imported rights")
	await _prepare("both", 1.0, 380)
	await _jump()
	await _jump()
	_move(Vector2.UP)
	await _pulse_dash()
	_move(Vector2.RIGHT)
	for frame in 200:
		if respawns > 0:
			break
		await _step()
	_check(respawns == 1 and not tutorial.cleared.has(14), "An unsuccessful early sequence falls back to the unfinished entrance")
	await _prepare("both", 1.0, 380)
	await _launch(20, 20, 20)
	_move(Vector2.RIGHT)
	for frame in 200:
		if room.get_node("Goal").pressing:
			break
		await _step()
	_check(room.get_node("Goal").pressing and not tutorial.cleared.has(14), "The retry regression starts during an actual cap press")
	_release()
	await _reset_key()
	_check(respawns == 1 and not tutorial.cleared.has(14) and not room.get_node("Goal").pressing and not room.get_node("Goal").is_pressed(), "R cancels the terrain-led arrival's incomplete press")


func _backtrack() -> void:
	pad = false
	_move(Vector2.LEFT)
	for frame in 300:
		if tutorial.room_index == 14 and not tutorial.transitioning:
			break
		_move(Vector2.LEFT)
		await _step()
	_release()
	await _step(5)
	_check(tutorial.room_index == 14 and player.is_on_floor() and _local().distance_to(room.get_node("Return").position) < 5, "Returning from Room16 reaches the wide high rest")
	var before := respawns
	await _reset_key()
	_check(respawns == before + 1 and tutorial.cleared.has(14) and _local().distance_to(room.get_node("Return").position) < 2, "R after returning preserves the cleared arrival and high checkpoint")
	_move(Vector2.LEFT)
	for frame in 300:
		if tutorial.room_index == 13 and not tutorial.transitioning:
			break
		await _step()
	_release()
	_check(tutorial.room_index == 13 and player.controls_enabled and player.is_on_floor(), "Walking off the high rest lands on the entrance floor and returns safely to Room14")


func _boot_roundtrip() -> void:
	await _new_world()
	await _prepare("both", 1.0, 380)
	await _jump()
	await _step(20)
	await _jump()
	await _step(20)
	_check(player.is_air_jump_ready() and player.get_held_object() == room.get_node("Creature"), "The carry-back attempt really earns an unused airborne boot while holding the companion")
	_move(Vector2.LEFT)
	await _pulse_dash()
	for frame in 320:
		if tutorial.room_index == 13 and not tutorial.transitioning:
			break
		_move(Vector2.LEFT)
		await _step()
	_release()
	await _step(2)
	_check(tutorial.room_index == 13 and player.controls_enabled and player.is_on_floor() and not player.is_air_jump_ready() and player.get_held_object() != room.get_node("Creature"), "Returning to Room14 removes the actual unspent boot and companion")
	await _reset_key()
	var previous: Node2D = tutorial.rooms.get_child(13)
	_move(Vector2.RIGHT)
	for frame in 100:
		if player.global_position.x - previous.global_position.x >= 110:
			break
		await _step()
	_grab(true)
	await _step(3)
	_check(player.get_held_object() == previous.get_node("Parachute"), "The round trip reacquires Room14's actual umbrella")
	for frame in 100:
		if player.global_position.x - previous.global_position.x >= 220:
			break
		await _step()
	await _jump()
	await _step(48)
	await _pulse_dash()
	for frame in 500:
		if tutorial.room_index == 14 and not tutorial.transitioning:
			break
		_move(Vector2.RIGHT)
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_release()
	_check(tutorial.room_index == 14 and player.controls_enabled and player.is_on_floor() and respawns == 3, "The playable Room14 crossing returns to Room15 with only two transitions and the requested R")
	_check(not player.is_air_jump_ready() and player.get_held_object() != previous.get_node("Parachute") and not tutorial.cleared.has(14), "Re-entry cannot import the earlier boot or umbrella to bypass the unfinished combined lesson")


func _grab_creature() -> void:
	_move(Vector2.RIGHT)
	for frame in 80:
		if _local().x >= 110:
			break
		await _step()
	_move(Vector2.ZERO)
	_grab(true)
	await _step(3)
	_check(player.get_held_object() == room.get_node("Creature"), "Real movement and Grab acquire the entrance companion")


func _walk_to(x: float, speed: float) -> void:
	_move(Vector2(speed, 0))
	for frame in 250:
		if _local().x >= x or respawns > 0:
			return
		await _step()
	_check(false, "The tested launch position is reachable by normal movement")


func _pulse_dash() -> void:
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")


func _land_high() -> bool:
	for frame in 220:
		if respawns > 0:
			return false
		if player.is_on_floor():
			return _on_high()
		await _step()
	return false


func _on_high() -> bool:
	if not player.is_on_floor():
		return false
	for index in player.get_slide_collision_count():
		if player.get_slide_collision(index).get_collider() in [room.get_node("HighLanding"), room.get_node("RightWall")]:
			var collision: CollisionShape2D = room.get_node("HighLanding/Collision")
			return player.global_position.y <= collision.to_global(collision.shape.get_rect().position).y - 25
	return false


func _new_world() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	room = tutorial.get_node("Rooms/Room15")
	# A normal Room15 visit has already opened the preceding room's exit.
	tutorial.cleared[13] = true
	tutorial.call("_set_room", 13, false)
	player.respawn()
	await _step()
	await _enter()


func _enter() -> void:
	_release()
	pad = false
	room.get_node("JumpCrystal").process_mode = Node.PROCESS_MODE_INHERIT
	tutorial.cleared.erase(14)
	tutorial.call("_set_room", 14, false)
	player.respawn()
	await _step(6)
	respawns = 0
	carry_top = INF


func _local() -> Vector2:
	return player.position - room.position


func _move(direction: Vector2) -> void:
	if pad:
		_joy(JOY_AXIS_LEFT_X, direction.x)
		_joy(JOY_AXIS_LEFT_Y, direction.y)
		return
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")


func _grab(value: bool) -> void:
	if pad:
		_joy(JOY_AXIS_TRIGGER_LEFT, 1 if value else 0)
	elif value:
		Input.action_press("wall_grab")
	else:
		Input.action_release("wall_grab")


func _joy(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _jump() -> void:
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")


func _reset_key() -> void:
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


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "wall_grab", "jump", "dash", "reset"]:
		Input.action_release(action)
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_TRIGGER_LEFT]:
		_joy(axis, 0)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		frames += 1
		if is_instance_valid(player) and tutorial.room_index == 14 and player.get_held_object() != null:
			var sprite: AnimatedSprite2D = player.get_held_object().get_node("Visuals/Body")
			var size: Vector2 = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size()
			var rect := Rect2(-size * 0.5 + sprite.offset, size)
			for corner in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
				carry_top = minf(carry_top, sprite.to_global(corner).y)


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial-combo")
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/tutorial-combo/%s.png" % name)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_COMBO_JUMP: %s (position=%s velocity=%s seen=%s)" % [message, _local(), player.velocity, tutorial.seen.keys()])
