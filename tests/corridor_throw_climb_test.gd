extends "res://tests/stage_4_playthrough.gd"

var checks := 0
var failed := false
var trials := 0
var climb_trials := 0
var tested_room := 7


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_throw_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	if OS.get_cmdline_user_args().has("--new-shaft"): tested_room = 13
	if OS.get_cmdline_user_args().has("--wide-shaft"): tested_room = 17
	if OS.get_cmdline_user_args().has("--fourth-shaft"): tested_room = 22
	change_scene_to_file("res://scenes/stage_4.tscn")
	await step(5)
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): deaths += 1)
	player.movement_action.connect(func(action): actions[action] = actions.get(action, 0) + 1)
	for live in ([false] if tested_room in [13, 17, 22] else [false, true]):
		for stepped in [false, true]:
			for side in [1, -1]:
				for delay in [0, 4, 8]:
					await _throw_and_climb(stepped, side, delay, live)
					if failed: return
	_check(climb_trials > 0, "The comparisons include real unheld upward climbing")
	release()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CORRIDOR_THROW_CLIMB_TEST_%s (%d checks, %d routes, %d climbs)" % ["FAILED" if failed else "OK", checks, trials, climb_trials])
	quit(1 if failed else 0)


func _throw_and_climb(stepped: bool, side: int, delay: int, live: bool) -> void:
	release()
	stage.room_index = tested_room
	stage._set_checkpoint()
	player.wall_actions_enabled = true
	player.respawn()
	await step(5)
	deaths = 0
	actions.clear()
	var room: Node2D = stage.rooms.get_child(tested_room)
	var creature: Grabbable = room.get_node("Items/JumpCreature")
	var target: Rect2 = room.walls[1 if tested_room in [17, 22] else 0]
	for hazard in room.get_node("Hazards").get_children():
		if not hazard.ceiling_strip:
			hazard.set_physics_process(live)
	if tested_room in [17, 22]:
		_check(await island_leap(20, 20, 1.0, tested_room) and await more_walk(1310), "The new shaft comparison starts after the actual wind and safe island")
		if failed: return
		actions.clear()
		if stepped:
			Input.action_release("wall_grab")
			await step(30)
	if stepped:
		await _pulse("jump")
		for frame in 100:
			_move(Vector2(creature.global_position.x - player.global_position.x if tested_room in [17, 22] else 175 - _x(), 0))
			await step()
			if player.is_on_floor() and player.position.y < (room.walls[0].position.y if tested_room in [17, 22] else room.entrance_top) - 60: break
		_move(Vector2.ZERO)
		await step(3)
		var supported := false
		for index in player.get_slide_collision_count():
			supported = supported or player.get_slide_collision(index).get_collider() == creature
		_check(player.is_on_floor() and supported, "The raised launch physically stands on the free companion")
	elif tested_room not in [17, 22]:
		Input.action_press("wall_grab")
		_move(Vector2.RIGHT)
		for frame in 100:
			if _x() >= 200: break
			await step()
		_move(Vector2.ZERO)
		await step(12)
	Input.action_press("wall_grab")
	await _pulse("jump")
	await step(20)
	await _pulse("jump")
	await step(20)
	_move(Vector2.UP)
	await _pulse("dash")
	await step(delay)
	Input.action_release("wall_grab")
	await step()
	_check(player.get_held_object() == null and creature.linear_velocity.y < -1000 and actions.get("creature_jump", 0) == 1, "A real carried Jump and Dash throw the original companion upward")
	_move(Vector2(side, 0))
	await step(16)
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	var reached := false
	var climbed := false
	var retrieved := false
	for frame in 360:
		if deaths > 0: break
		climbed = climbed or (player.is_wall_grabbing() and player.velocity.y < -100)
		reached = reached or (player.is_on_floor() and player.position.y < target.position.y and _x() > target.position.x and player.get_held_object() == creature)
		if reached: break
		if player.is_on_floor() and player.position.y < target.position.y and player.get_held_object() == null:
			_move(Vector2.LEFT)
		if player.global_position.distance_to(creature.global_position) < 100 and creature.linear_velocity.y > 0 and not retrieved:
			Input.action_release("wall_grab")
			await step()
			Input.action_press("wall_grab")
			await step()
			retrieved = player.get_held_object() == creature
			if retrieved:
				player.wall_actions_enabled = false
				_move(Vector2.RIGHT)
				await _pulse("jump")
		await step()
	_check(not reached and stage.room_index == tested_room and actions.get("wall_jump", 0) == 0, "Throw, unheld climb and re-grab cannot replace the shaft's wall kicks: step=%s side=%d delay=%d live=%s" % [stepped, side, delay, live])
	if climbed: climb_trials += 1
	if deaths > 0:
		release()
		await step(5)
		_check(player.position.distance_to(player._spawn_position) < 2 and player.get_held_object() == null and player.is_dash_ready() and creature.extra_jump_count() == 1, "An actual failed shortcut restores the entrance, companion and resources")
	trials += 1


func _x() -> float:
	return player.position.x - stage.rooms.get_child(stage.room_index).position.x


func _move(direction: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if direction.x != 0: Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0: Input.action_press("move_down" if direction.y > 0 else "move_up")


func _pulse(action: String) -> void:
	Input.action_press(action)
	await step()
	Input.action_release(action)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("CORRIDOR_THROW_CLIMB: " + message)
		quit(1)
