extends "res://tests/stage_4_playthrough.gd"

var failed := false
var checks := 0
var room: Node2D
var creature: Grabbable
var pause_at_rest := false
var rested := false
var started_carry := false
var dropped_during_route := false
var hazard_hits := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/stage_4.tscn")
	await step(5)
	stage = current_scene
	player = stage.player
	room = stage.rooms.get_child(1)
	creature = room.get_node("Items/JumpCreature")
	for hazard in room.get_node("Hazards").get_children():
		hazard.player_hit.connect(func(): hazard_hits += 1)
	player.respawned.connect(func(): deaths += 1)
	player.movement_action.connect(func(action): actions[action] = actions.get(action, 0) + 1)
	stage.room_index = 1
	stage._set_checkpoint()
	if not OS.get_cmdline_user_args().has("--positive"):
		await _without_kicks()
		await _step_pickup()
	player.wall_actions_enabled = true
	if not OS.get_cmdline_user_args().has("--positive"):
		await _throw_and_climb()
	for wait in [0, 30, 60]:
		await _enter(wait)
		started_carry = false
		dropped_during_route = false
		pause_at_rest = false
		rested = false
		var started := Engine.get_physics_frames()
		var arrived := await traverse(1)
		release()
		var seconds := (Engine.get_physics_frames() - started) / 60.0
		_check(arrived and stage.room_index == 2 and deaths == 1, "The live canyon reaches Room3 without a death: wait=%d" % wait)
		_check(actions.get("wall_jump", 0) > 0 and actions.get("creature_jump", 0) > 0 and not actions.has("climb"), "Actual wall kicks and the companion cross the canyon without wall climbing")
		_check(started_carry and not dropped_during_route, "The original companion stays held until delivery")
		_check(seconds < 30, "The room stays under thirty seconds including its rest")
		_check(not pause_at_rest or rested, "The normal route really stops on the broad rest")
		print("CORRIDOR_WALL_SECONDS %.2f wait=%d actions=%s" % [seconds, wait, actions])
		await step(25)
		stage.room_index = 1
		stage._set_checkpoint()
	await _enter(30)
	pause_at_rest = true
	rested = false
	var reached_rest := await traverse(1, true)
	_check(reached_rest and rested and stage.room_index == 1 and deaths == 0, "The canyon offers a safe three-second rest before the next transfer")
	pause_at_rest = false
	await _hazard_and_fall_retry()
	await _retry()
	release()
	print("CORRIDOR_WALL_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)

func _enter(wait: int = 0) -> void:
	release()
	stage.room_index = 1
	stage._set_checkpoint()
	player.respawn()
	await super.step(5 + wait)
	deaths = 0
	hazard_hits = 0
	actions.clear()
	samples.clear()

func _without_kicks() -> void:
	player.wall_actions_enabled = false
	for hazard in room.get_node("Hazards").get_children():
		if not hazard.ceiling_strip:
			hazard.set_physics_process(false)
	for launch in [70, 170, 210]:
		for extra_frame in [16, 20, 24]:
			for direction in _directions():
				for dash_frame in [0, 16, 24, 40]:
					await _enter()
					Input.action_press("wall_grab")
					await step(2)
					_check(player.get_held_object() == creature, "The no-kick attempt holds the real companion")
					for frame in 100:
						var x := player.position.x - room.position.x
						if absf(x - launch) < 8 and player.is_on_floor():
							break
						_drive(Vector2(signf(launch - x), 0))
						await step()
					_drive(Vector2.ZERO)
					await step(12)
					_check(player.is_on_floor(), "The no-kick launch starts from a real floor")
					await _pulse("jump")
					var reached := false
					for frame in 180:
						_drive(Vector2(290 - (player.position.x - room.position.x), 0))
						if frame == extra_frame:
							await _pulse("jump")
						if frame == dash_frame:
							_drive(direction)
							await _pulse("dash")
						await step()
						reached = reached or _reached_rest()
						if deaths > 0:
							break
					_check(not reached and stage.room_index == 1 and actions.get("wall_jump", 0) == 0, "Normal/extra jump and eight-way dash cannot replace wall kicks: x=%d extra=%d dash=%d direction=%s" % [launch, extra_frame, dash_frame, direction])
		print("CORRIDOR_WALL_WITHOUT_KICKS x=%d: 96 attempts" % launch)

func _step_pickup() -> void:
	for extra_frame in [16, 20, 24]:
		for direction in _directions():
			await _enter()
			await _pulse("jump")
			for frame in 100:
				_drive(Vector2(175 - (player.position.x - room.position.x), 0))
				await step()
				if player.is_on_floor() and player.position.y < 1640:
					break
			_drive(Vector2.ZERO)
			await step(3)
			_check(player.is_on_floor() and player.position.y < 1640, "The shortcut physically stands on the free companion")
			Input.action_press("wall_grab")
			await _pulse("jump")
			_check(player.get_held_object() == creature, "Simultaneous Grab/Jump lifts the companion from its back")
			await step(extra_frame)
			await _pulse("jump")
			await step(20)
			_drive(direction)
			await _pulse("dash")
			var reached := false
			for frame in 180:
				_drive(Vector2(290 - (player.position.x - room.position.x), 0))
				await step()
				reached = reached or _reached_rest()
				if deaths > 0: break
			_check(not reached and stage.room_index == 1 and actions.get("wall_jump", 0) == 0, "The companion step and simultaneous Grab/Jump cannot bypass the canyon")
	for hazard in room.get_node("Hazards").get_children():
		if not hazard.ceiling_strip:
			hazard.set_physics_process(true)

func _throw_and_climb() -> void:
	for hazard in room.get_node("Hazards").get_children():
		if not hazard.ceiling_strip:
			hazard.set_physics_process(false)
	for stepped in [false, true]:
		for throw_frame in [0, 4, 8]:
			await _enter()
			if stepped:
				await _pulse("jump")
				for frame in 100:
					_drive(Vector2(175 - (player.position.x - room.position.x), 0))
					await step()
					if player.is_on_floor() and player.position.y < 1640: break
				_drive(Vector2.ZERO)
				await step(3)
				_check(player.is_on_floor() and player.position.y < 1640, "The thrown shortcut physically starts on the companion")
			else:
				Input.action_press("wall_grab")
				Input.action_press("move_right")
				while player.position.x < room.position.x + 200: await step()
				_drive(Vector2.ZERO)
				await step(12)
			Input.action_press("wall_grab")
			await _pulse("jump")
			await step(20)
			await _pulse("jump")
			await step(20)
			_drive(Vector2.UP)
			await _pulse("dash")
			await step(throw_frame)
			Input.action_release("wall_grab")
			await step()
			_check(player.get_held_object() == null and creature.linear_velocity.y < -1000, "The shortcut really throws its companion upward during the dash")
			_drive(Vector2.RIGHT)
			await step(16)
			Input.action_press("wall_grab")
			Input.action_press("move_up")
			var highest_creature := creature.position.y
			var highest_player := player.position.y
			var climbed := false
			var reached := false
			for frame in 300:
				if deaths > 0: break
				highest_creature = minf(highest_creature, creature.position.y)
				highest_player = minf(highest_player, player.position.y)
				climbed = climbed or (player.is_wall_grabbing() and player.velocity.y < -100)
				reached = reached or _reached_rest()
				await step()
			_check(climbed and actions.get("wall_jump", 0) == 0, "The thrown shortcut really climbs unheld without a wall kick")
			_check(not reached and stage.room_index == 1 and highest_creature > 300 and highest_player > 300, "Throw, unheld climbing, and re-grabbing cannot reach the rest with or without the companion step")
			print("CORRIDOR_THROW_CLIMB step=%s frame=%d creature_y=%.2f player_y=%.2f" % [stepped, throw_frame, highest_creature, highest_player])
	for hazard in room.get_node("Hazards").get_children():
		if not hazard.ceiling_strip:
			hazard.set_physics_process(true)


func _hazard_and_fall_retry() -> void:
	await _enter(90)
	var arrived := await traverse(1)
	_check(not arrived and deaths == 1 and hazard_hits == 1 and stage.room_index == 1 and actions.get("wall_jump", 0) > 0, "A real carried route into a patrol retries without advancing the room")
	release()
	await step(5)
	_check(player.position.distance_to(Vector2(1390, 1674)) < 2 and player.get_held_object() == null and creature.extra_jump_count() == 1, "Patrol contact restores the safe entrance and companion")
	await _enter()
	Input.action_press("wall_grab")
	Input.action_press("move_right")
	for frame in 240:
		await step()
		if deaths > 0: break
	release()
	await step(5)
	_check(deaths == 1 and hazard_hits == 0 and stage.room_index == 1 and player.position.distance_to(Vector2(1390, 1674)) < 2 and player.is_dash_ready(), "Walking off the entrance safely retries below the taller room")


func _retry() -> void:
	await _enter()
	_check(player.position.distance_to(Vector2(1390, 1674)) < 2 and player.is_on_floor() and player.is_dash_ready() and creature.extra_jump_count() == 1 and player.get_held_object() == null, "R restores the new safe entrance, creature, and abilities")
	_check(stage.camera.position.distance_to(Vector2(1920, 1440)) < 2, "Retry shows the bottom entrance in the taller room")
	Input.action_press("wall_grab")
	await step(2)
	Input.action_press("jump")
	await step()
	Input.action_release("jump")
	await step(16)
	_check(player.get_held_object() == creature, "The R regression begins during a real carried jump")
	await _pulse("reset")
	release()
	await step(5)
	_check(player.position.distance_to(Vector2(1390, 1674)) < 2 and player.is_on_floor() and player.get_held_object() == null and creature.extra_jump_count() == 1, "A real R during motion clears carrying and restores the checkpoint")

func _reached_rest() -> bool:
	return stage.room_index != 1 or (player.is_on_floor() and player.position.y < room.walls[0].position.y)

func _directions() -> Array:
	return [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]

func _drive(direction: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if absf(direction.x) > 1:
		direction.x = signf(direction.x)
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")

func _pulse(action: String) -> void:
	Input.action_press(action)
	await step()
	Input.action_release(action)

func release() -> void:
	super.release()
	Input.action_release("reset")

func step(count: int = 1) -> void:
	await super.step(count)
	if is_instance_valid(player) and stage.room_index == 1:
		if player.get_held_object() == creature:
			started_carry = true
		elif started_carry:
			dropped_during_route = true
		if pause_at_rest and not rested and _reached_rest():
			rested = true
			release()
			Input.action_press("wall_grab")
			await super.step(180)
			_check(player.is_on_floor() and absf(player.position.y - 274) < 2 and player.get_held_object() == creature, "The wide rest permits a real three-second stop with the companion")
			_check(player.is_dash_ready() and creature.extra_jump_count() == 1, "The rest refills dash and the companion")
			Input.action_press("wall_grab")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("CORRIDOR_WALL: " + message)
