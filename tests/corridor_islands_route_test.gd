extends "res://tests/stage_4_playthrough.gd"

var checks := 0
var failed := false
var trials := 0
var actual_superdashes := 0
var room: Node2D
var creature: Grabbable
var hazard_hits := 0
var capture_exit := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/stage_4.tscn")
	await step(5)
	stage = current_scene
	player = stage.player
	room = stage.rooms.get_child(4)
	creature = room.get_node("Items/JumpCreature")
	player.respawned.connect(func(): deaths += 1)
	player.movement_action.connect(func(action): actions[action] = actions.get(action, 0) + 1)
	for hazard in room.get_node("Hazards").get_children():
		hazard.player_hit.connect(func(): hazard_hits += 1)
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _screenshots()
	elif OS.get_cmdline_user_args().has("--footstool-only"):
		await _footstools()
	else:
		await _positive_routes()
		if not failed:
			await _recoveries()
		if not failed and not OS.get_cmdline_user_args().has("--positive-only"):
			await _footstools()
			if not failed: await _without_extra_jump()
			if not failed: await _superdash()
			if not failed: await _high_wall()
	release()
	print("CORRIDOR_ISLANDS_ROUTE_TEST_%s (%d checks, %d negative routes, %d actual Superdash)" % ["FAILED" if failed else "OK", checks, trials, actual_superdashes])
	quit(1 if failed else 0)

func step(count: int = 1) -> void:
	for frame in count:
		await super.step()
		if capture_exit and stage.room_index == 4 and player.is_on_floor() and _x() > 1180:
			_capture("delivery")
			capture_exit = false

func _positive_routes() -> void:
	for extra in [20, 28, 36]:
		for dash in [20, 28, 36]:
			await _enter()
			_check(await island_leap(extra, dash), "Broad full-input timing crosses the wide gap: %d/%d" % [extra, dash])
			_check(deaths == 0 and player.get_held_object() == creature and actions.get("creature_jump", 0) == 1 and actions.get("dash", 0) == 1, "The timing route really uses the carried companion and Dash without dying")
			if failed: return
	for strength in [0.7, 0.85]:
		for extra in ([40, 44] if strength < 0.8 else [28, 36]):
			for dash in ([40, 44] if strength < 0.8 else [28, 36]):
				await _enter()
				_check(await island_leap(extra, dash, strength), "Weaker horizontal input reaches the island: %.2f %d/%d" % [strength, extra, dash])
				_check(deaths == 0 and actions.get("creature_jump", 0) == 1 and player.get_held_object() == creature, "Weaker input keeps the actual companion through the jump")
				if failed: return
	for phase in [63, 70, 77]:
		await _enter(phase, true)
		var started := Engine.get_physics_frames()
		var arrived := await traverse(4)
		var seconds := (Engine.get_physics_frames() - started) / 60.0
		_check(arrived and stage.room_index == 5 and deaths == 1 and hazard_hits == 0, "The live island room delivers its companion without a death: phase=%d" % phase)
		_check(actions.get("creature_jump", 0) > 0 and actions.get("dash", 0) > 0 and seconds < 30, "The live checkpoint interval uses the intended actions and stays below thirty seconds")
		print("ISLAND_LIVE_SECONDS %.2f phase=%d actions=%s" % [seconds, phase, actions])
		if failed: return
		await step(25)
	await _enter(70, true)
	_check(await traverse(4, true), "Reach the broad island before resting")
	_move(Vector2.ZERO)
	var before := player.position
	await step(180)
	_check(deaths == 0 and player.is_on_floor() and player.position.distance_to(before) < 2 and player.get_held_object() == creature, "The island provides a safe three-second rest with the companion")
	_check(player.is_dash_ready() and creature.extra_jump_count() == 1, "The island restores Dash and the companion's extra jump")
	var arrived := await traverse(4)
	_check(arrived and stage.room_index == 5 and deaths == 1 and hazard_hits == 0, "Resume after the rest and deliver without dying")
	await step(25)
	await _pulse("reset")
	release()
	await step(5)
	_check(stage.room_index == 5 and player.position.distance_to(Vector2(6510, 594)) < 3, "R after delivery keeps the next checkpoint")

func _recoveries() -> void:
	await _enter(70, true)
	_check(await traverse(4, true), "Reach the live island for a real R retry")
	await _pulse("reset")
	release()
	await step(5)
	_check(_reset_state(), "R from the island restores the entrance, companion and resources")
	await _enter()
	_move(Vector2.RIGHT, false)
	for frame in 200:
		await step()
		if deaths > 0: break
	release()
	await step(5)
	_check(deaths == 1 and hazard_hits == 0 and _reset_state(), "Walking into the gap with patrols stopped retries from the current entrance")
	await _enter(0, true)
	var arrived := await island_leap()
	release()
	await step(5)
	_check(not arrived and deaths == 1 and hazard_hits == 1 and _reset_state(), "An actual mistimed route hits a patrol and restores the checkpoint")

func _reset_state() -> bool:
	return stage.room_index == 4 and player.position.distance_to(Vector2(5230, 594)) < 3 and player.get_held_object() == null and player.is_dash_ready() and creature.extra_jump_count() == 1 and creature.position.distance_to(Vector2(175, 580)) < 15

func _screenshots() -> void:
	await _enter(63, true)
	_capture("entrance")
	_check(await traverse(4, true) and deaths == 0, "Render an actual live leap to the island")
	_capture("rest")
	capture_exit = true
	_check(await traverse(4) and stage.room_index == 5 and deaths == 1, "Render the real delivery and next checkpoint")
	_check(not capture_exit, "The delivery screenshot shows the player standing at the exit")

func _capture(label: String) -> void:
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/corridor-islands")
	root.get_texture().get_image().save_png("res://docs/screenshots/corridor-islands/%s.png" % label)

func _enter(phase := 0, live := false) -> void:
	release()
	stage.room_index = 4
	stage._set_checkpoint()
	player.respawn()
	for hazard in room.get_node("Hazards").get_children():
		if not hazard.ceiling_strip:
			hazard.set_physics_process(live)
	await step(5 + phase)
	deaths = 0
	hazard_hits = 0
	actions.clear()
	samples.clear()

func _move(direction: Vector2, grab := true, strength := 1.0) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if grab: Input.action_press("wall_grab")
	else: Input.action_release("wall_grab")
	if direction.x != 0: Input.action_press("move_right" if direction.x > 0 else "move_left", strength)
	if direction.y != 0: Input.action_press("move_down" if direction.y > 0 else "move_up", strength)

func _pulse(action: String) -> void:
	Input.action_press(action)
	await step()
	Input.action_release(action)

func _x() -> float:
	return player.position.x - room.position.x

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("CORRIDOR_ISLANDS: " + message + " pos=" + str(Vector2(_x(), player.position.y)) + " actions=" + str(actions))

func _walk_to(x: float, grab := true) -> void:
	_move(Vector2(signf(x - _x()), 0), grab)
	for frame in 150:
		if absf(x - _x()) < 5 or deaths > 0: break
		await step()

func _reject(label: String) -> void:
	_move(Vector2.RIGHT)
	var reached := false
	for frame in 220:
		if deaths > 0: break
		if stage.room_index != 4 or (player.is_on_floor() and _x() > room.walls[0].position.x - 20):
			reached = true
			break
		Input.action_release("jump")
		if player.is_on_wall() and not player.is_dashing():
			Input.action_press("jump")
		await step()
	_check(actions.get("creature_jump", 0) == 0, "The bypass does not accidentally consume the extra jump: " + label)
	_check(not reached and stage.room_index == 4, "Terrain rejects a no-extra-jump route: " + label)
	trials += 1

func _directions() -> Array:
	return [Vector2.UP, Vector2(1, -1), Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1)]

func _footstool(walk: int) -> void:
	await _enter()
	await _walk_to(145)
	_move(Vector2.ZERO)
	await step(20)
	_check(player.get_held_object() == creature, "Actually carry the companion before placing it")
	_move(Vector2.LEFT, false)
	for frame in 100:
		await step()
		if _x() < 95: break
	_move(Vector2.ZERO, false)
	await step(20)
	_check(creature.carrier == null and creature.position.x > 160 and creature.position.x < 215, "Actually place the companion near the entrance edge")
	await _pulse("jump")
	await step(10)
	_move(Vector2.RIGHT, false)
	for frame in 100:
		await step()
		if _x() >= creature.position.x - 10:
			_move(Vector2.ZERO, false)
		if player.is_on_floor(): break
	var supported := false
	for index in player.get_slide_collision_count():
		supported = supported or player.get_slide_collision(index).get_collider() == creature
	_check(player.is_on_floor() and supported and player.position.y < 550, "The player physically stands on the free companion")
	if failed: return
	_move(Vector2.RIGHT, false)
	await step(walk)
	_check(player.is_on_floor(), "Walking toward the companion's edge keeps real support")
	Input.action_press("wall_grab")
	await _pulse("jump")
	_check(player.get_held_object() == creature and actions.get("creature_jump", 0) == 0, "Simultaneous Grab and normal Jump picks up the actual footstool")

func _footstools() -> void:
	for walk in [0, 4, 8]:
		for delay in [8, 16, 24, 32, 40, 48]:
			for direction in [Vector2.UP, Vector2(1, -1), Vector2.RIGHT]:
				await _footstool(walk)
				if failed: return
				await step(delay)
				_move(direction)
				await _pulse("dash")
				await _reject("placed companion walk=%d delay=%d direction=%s" % [walk, delay, direction])
				if failed: return
		print("ISLAND_FOOTSTOOL_OK walk=%d" % walk)

func _without_extra_jump() -> void:
	for launch in [225, 255]:
		for delay in [0, 8, 16, 24, 32, 40, 48, 56]:
			for direction in _directions():
				await _enter()
				await _walk_to(launch)
				await _pulse("jump")
				_check(actions.get("jump", 0) == 1 and actions.get("creature_jump", 0) == 0 and player.get_held_object() == creature, "The no-extra attempt starts with a real normal or coyote jump")
				await step(delay)
				_move(direction)
				await _pulse("dash")
				await _reject("launch=%d delay=%d direction=%s" % [launch, delay, direction])
				if failed: return
		print("ISLAND_NO_EXTRA_OK launch=%d" % launch)

func _superdash() -> void:
	for delay in [0, 3, 6]:
		await _enter()
		await _walk_to(175)
		await _pulse("dash")
		await step(delay)
		await _pulse("jump")
		actual_superdashes += actions.get("superdash", 0)
		await _reject("ground Superdash delay=%d" % delay)
	_check(actual_superdashes > 0, "The negative inputs include actual Superdash actions")

func _high_wall() -> void:
	for delay in [0, 16, 32]:
		for direction in _directions():
			await _enter()
			_move(Vector2.LEFT, false)
			for frame in 100:
				await step()
				if _x() < 65: break
			_move(Vector2(-1, -1))
			for frame in 240:
				await step()
				if player.is_wall_grabbing() and player.position.y < 110: break
			_check(player.is_wall_grabbing() and player.position.y < 110 and _x() < 75, "Actually climb the left wall before the high takeoff")
			if failed: return
			_move(Vector2.RIGHT)
			await _pulse("jump")
			await step(delay)
			_move(direction)
			await _pulse("dash")
			await _reject("bare high wall delay=%d direction=%s" % [delay, direction])
			if failed: return
