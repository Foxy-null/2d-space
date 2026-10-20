extends SceneTree
## Input-driven traversal, with the opponent paused to isolate course reachability.

var stage
var ticks := 0
var jumps := 0
var failures := 0
var _jump_left := 0
var _dash_left := 0
var _hold := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	var arguments := OS.get_cmdline_user_args()
	var selected := int(arguments[0]) if arguments.size() else -1
	for number in 12:
		if selected >= 0 and selected != number:
			continue
		var passed := false
		for attempt in 8:
			_release()
			_jump_left = 0
			_dash_left = 0
			stage._load_room(number)
			stage.enemy.set_physics_process(false)
			stage.enemy.controls_enabled = false
			await _step(3 + attempt * 23)
			print("TRAVERSE_BEGIN ", number + 1, " attempt=", attempt + 1)
			passed = await _play_room(number)
			if passed:
				break
			failures += 1
		if not passed:
			push_error("Input traversal failed in room %d" % (number + 1))
			quit(1)
			return
		print("TRAVERSE_OK ", number + 1)
	print("STAGE_6_PLAYTHROUGH_OK inputs=%d jumps=%d retries=%d" % [ticks, jumps, failures])
	_release()
	for child in stage.room.arrival.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	current_scene.queue_free()
	await _step(3)
	OS.delay_msec(50) # Let the audio thread release the final arrival chime before shutdown.
	quit()

func _play_room(number: int) -> bool:
	# Solve the mandatory weight puzzles using the same carry/drop inputs.
	for door in stage.room.doors:
		if door.closes:
			continue
		var heavy: bool = door.button.required_weight > 2.0
		var supply: Vector2 = stage.room.supplies.filter(func(entry): return entry.scene == (stage.room.HEAVY if heavy else stage.room.LIGHT))[0].at
		if number in [2, 11]:
			for point: Vector2 in stage.room.route:
				if point.x > stage.player.position.x + 60 and point.x < supply.x - 50:
					if not await _navigate(point, 600):
						return false
		if not await _navigate(supply + Vector2(-30, 14), 500):
			return false
		_hold = true
		Input.action_press("wall_grab")
		await _step(4)
		if stage.player.get_held_object() == null:
			print("Pilot did not acquire a weight")
			return false
		if not stage.player.is_on_floor() and stage.player._coyote_left > 0.0:
			Input.action_press("jump")
			await _step()
			Input.action_release("jump")
			_jump_left = 14
		if number == 11 and heavy:
			_release_movement()
			await _step(45)
			Input.action_press("move_right")
			Input.action_press("jump")
			await _step()
			Input.action_release("jump")
			await _step(16)
			_hold = false
			Input.action_release("wall_grab")
			await _step()
			_release_movement()
			Input.action_press("move_left")
			await _step(10)
			_release_movement()
			await _step(50)
			if not door.button.is_pressed():
				return false
			_jump_left = 0
			_dash_left = 0
			continue
		if number == 2:
			for point: Vector2 in stage.room.route:
				if point.x > stage.player.position.x + 60 and point.x < door.button.position.x - 50:
					if not await _navigate(point, 600):
						return false
		if not await _navigate(door.button.position - Vector2(0, 26), 800):
			return false
		_release_movement()
		await _step(20)
		_hold = false
		Input.action_release("wall_grab")
		if not await _navigate(stage.player.position + Vector2(100, 0), 120):
			return false
		await _step(25)
		Input.action_press("jump")
		await _step()
		Input.action_release("jump")
	if number in [3, 7, 8, 10]:
		var kind: String = "PARACHUTE" if number in [3, 10] else "JUMP"
		for item in stage.room.get_node("Items").get_children():
			if item.carry_name != kind:
				continue
			if not await _navigate(item.position + Vector2(-25, 18), 600):
				return false
			_hold = true
			Input.action_press("wall_grab")
			await _step(4)
			break
	var route: Array = stage.room.route.duplicate()
	# Weight puzzles have already traversed the opening section.
	while route.size() and route[0].x < stage.player.position.x + 60 and number not in [7]:
		route.pop_front()
	for point: Vector2 in route:
		if not await _navigate(point, 1000):
			return false
	if not await _navigate(stage.room.exit_position - Vector2(0, 118), 600):
		return false
	_release_movement()
	await _step(45)
	if not stage.completed and stage.room_index == number:
		print("Exit did not advance room %d at %s" % [number + 1, stage.player.position])
		return false
	return true

func _navigate(point: Vector2, maximum: int) -> bool:
	var initial_gravity: int = stage.player.gravity_direction
	var floor_query := PhysicsRayQueryParameters2D.create(point + stage.player.get_gravity_vector() * 5, point + stage.player.get_gravity_vector() * 80, 1, [stage.player.get_rid(), stage.enemy.get_rid()])
	var require_floor: bool = not stage.player.get_world_2d().direct_space_state.intersect_ray(floor_query).is_empty()
	for frame in maximum:
		if stage.completed:
			return true
		var actor: PlayerController = stage.player
		var delta := point - actor.position
		if actor.gravity_direction != initial_gravity and delta.length() < 220.0:
			_release_movement()
			return true
		var floating := actor.get_held_object() != null and is_finite(actor.get_held_object().fall_speed_limit()) and not actor._winds.is_empty()
		if (delta.length() < 38.0 and (not require_floor or actor.is_on_floor())) or (actor.is_on_floor() and absf(delta.dot(actor.get_walk_axis())) < 35.0 and delta.dot(actor.get_gravity_vector()) > 0.0 and delta.dot(actor.get_gravity_vector()) < 100.0) or (floating and absf(delta.dot(actor.get_walk_axis())) < 55.0 and delta.dot(actor.get_gravity_vector()) > -40.0):
			_release_movement()
			return true
		var tangent := actor.get_walk_axis()
		var down := actor.get_gravity_vector()
		var climbing := delta.dot(down) < -18.0
		var along := delta.dot(tangent)
		var danger: bool = stage.room.hazard_ahead(actor, along)
		var rising_target := climbing and absf(along) < 210.0
		var movement := tangent * signf(along) if absf(along) > 12.0 else Vector2.ZERO
		_jump_left -= 1
		_dash_left -= 1
		var jump := false
		var dash := false
		var grab := _hold
		if actor.is_on_wall() and climbing and not _hold:
			grab = true
			movement -= down
		if _jump_left <= 0 and (((actor.is_on_floor() or actor._coyote_left > 0.0) and (rising_target or danger or absf(along) > 180)) or (actor.is_on_wall() and climbing and _hold) or (not actor.is_on_floor() and (climbing or danger) and actor.velocity.dot(down) > -50 and actor.get_available_extra_jump_count() > 0)):
			jump = true
			jumps += 1
			_jump_left = 14
		if not jump and _dash_left <= 0 and actor.is_dash_ready() and not actor.is_on_floor() and actor.velocity.dot(down) > (-350.0 if danger else -150.0) and (climbing or danger or absf(along) > 260):
			dash = true
			movement = (-down if climbing and absf(along) < 70.0 else (tangent * signf(along) - down).normalized()) if danger else (delta.normalized() if climbing else tangent * signf(along))
			_dash_left = 20
		_input("move_left", movement.x < -0.1)
		_input("move_right", movement.x > 0.1)
		_input("move_up", movement.y < -0.1)
		_input("move_down", movement.y > 0.1)
		_input("jump", jump)
		_input("dash", dash)
		_input("wall_grab", grab)
		var previous_position := actor.position
		var generation: int = stage._generation
		await _step()
		if stage._generation != generation:
			print("PILOT_RETRY from=", previous_position, " target=", point)
			return false
		if frame > 0 and actor.position.distance_to(stage.room.spawn) < 2.0:
			failures += 1
		if frame > 0 and frame % 240 == 0:
			print("PILOT ", stage.room_index + 1, " target=", point, " pos=", actor.position, " gravity=", actor.gravity_direction, " held=", actor.get_held_object() != null, " weights=", stage.room.doors.map(func(entry): return entry.button.total_weight))
	print("Pilot stalled in room %d: target=%s position=%s gravity=%d" % [stage.room_index + 1, point, stage.player.position, stage.player.gravity_direction])
	return false

func _input(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _release_movement() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash"]:
		Input.action_release(action)

func _release() -> void:
	_release_movement()
	Input.action_release("wall_grab")
	_hold = false

func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		ticks += 1
