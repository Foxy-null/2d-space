extends "res://tests/stage_2_test.gd"

var launches := 0
var dashes := 0
var air_jumps := 0
var creature_jumps := 0
var crystals := 0
var companion: Grabbable
var captured_ascent := false
var captured_crystals := false


func _run() -> void:
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	await _setup()
	if not screenshots:
		await _without_spring()
		await _without_crystals()
		await _crystal_retry(false)
		await _crystal_retry(true)
	await _remove_stage()
	for spring_delay in ([40] if screenshots else [36, 40, 44]):
		for jump_delay in ([20] if screenshots else [16, 20, 24]):
			await _setup()
			_capture("entrance")
			await _finale_course(spring_delay, jump_delay)
			_check(launches == 1 and dashes == 2 and air_jumps == 1 and crystals == 2 and respawns == 0, "The finale really combines one spring, both crystals, an extra jump, and two dashes")
			_capture("arrival")
			await _pulse("reset")
			await _step(6)
			_check(stage.checkpoint_index == 6 and player.position.distance_to(Vector2(360, -3706)) < 2, "R after the original finale retains CP07")
			_check(stage.get_node("Items/Item12").visible and stage.get_node("Items/Item13").visible, "R restores the finale crystals")
			await _remove_stage()
	if not screenshots:
		for route in ["dash", "jump"]:
			await _setup()
			stage.get_node("Items/Item13" if route == "dash" else "Items/Item12").collision_mask = 0
			await _finale_course(40, 20, route)
			_check(crystals == 1 and launches == 1 and respawns == 0, "Either crystal can provide the extra height after the spring and first dash")
			_check(air_jumps == (0 if route == "dash" else 1) and dashes == (2 if route == "dash" else 1), "The chosen alternative really uses its own movement resource")
			await _remove_stage()
		await _setup(4)
		await _companion_course()
		_check(launches == 0 and player.is_on_floor() and stage.checkpoint_index == 5, "The prior section lands safely without automatically firing the entrance spring")
		await _step(60)
		_check(launches == 0 and player.is_on_floor(), "The entrance permits a stationary observation before launch")
		var carried := player.get_held_object()
		_check(carried == stage.get_node("Items/Item20"), "The previous section supplies a real carried companion")
		await _finale_course()
		_check(player.get_held_object() == carried and respawns == 0, "The previous companion stays held through final arrival")
		await _remove_stage()
	print("TOWER_FINALE_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)


func _setup(checkpoint: int = 5) -> void:
	stage = load("res://scenes/stage_2.tscn").instantiate()
	root.add_child(stage)
	player = stage.player
	companion = stage.get_node("Items/Item21")
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action: String):
		if action == "dash": dashes += 1
		if action == "air_jump": air_jumps += 1
		if action == "creature_jump": creature_jumps += 1)
	stage.get_node("Items/Item11").launched.connect(func(_body: PlayerController): launches += 1)
	for name in ["Item12", "Item13"]:
		stage.get_node("Items/" + name).collected.connect(func(_body: PlayerController): crystals += 1)
	stage._set_checkpoint(checkpoint)
	player.respawn()
	await _step(6)
	_clear_counts()
	captured_ascent = false
	captured_crystals = false


func _remove_stage() -> void:
	_release()
	stage.queue_free()
	await _step(2)


func _enter() -> void:
	_release()
	stage._set_checkpoint(5)
	player.respawn()
	await _step(6)
	_clear_counts()


func _clear_counts() -> void:
	respawns = 0
	launches = 0
	dashes = 0
	air_jumps = 0
	creature_jumps = 0
	crystals = 0


func _without_spring() -> void:
	stage.get_node("Items/Item11").collision_mask = 0
	for mode in ["ground", "held", "step", "step_pickup"]:
		var count := 0
		for start_x in ([800, 860, 900] if mode == "ground" else [900]):
			for air_frame in ([16, 20, 24] if mode in ["held", "step_pickup"] else [-1]):
				for direction in _directions():
					for dash_frame in [-1, 0, 12, 20, 28, 40]:
						await _spring_bypass(mode, start_x, air_frame, direction, dash_frame)
						count += 1
		print("TOWER_FINALE_WITHOUT_SPRING mode=%s: %d attempts" % [mode, count])
	stage.get_node("Items/Item11").collision_mask = 1


func _spring_bypass(mode: String, start_x: int, air_frame: int, direction: Vector2, dash_frame: int) -> void:
	await _enter()
	if mode.begins_with("step"):
		await _stand_on_companion()
	else:
		for frame in 90:
			var dx := start_x - player.position.x
			if absf(dx) < 10 and player.is_on_floor(): break
			_set_direction(Vector2(signf(dx), 0))
			await _step()
		_set_direction(Vector2.ZERO)
		await _step(10)
		_check(player.is_on_floor() and absf(player.position.x - start_x) < 35, "The no-spring attempt reaches a real launch point")
	var held := mode in ["held", "step_pickup"]
	if held: Input.action_press("wall_grab")
	await _pulse("jump")
	_check(not held or player.get_held_object() == companion, "The no-spring attempt really carries its companion")
	var highest := player.position.y
	for frame in 180:
		Input.action_release("jump")
		_set_direction(Vector2(740 - player.position.x, -1))
		if held or player.position.distance_to(companion.position) > 110:
			Input.action_press("wall_grab")
		else:
			Input.action_release("wall_grab")
		if frame == air_frame:
			await _pulse("jump")
		if frame == dash_frame:
			_set_direction(direction)
			await _pulse("dash")
		if player.is_on_wall() and frame % 18 == 0:
			Input.action_press("jump")
		await _step()
		if respawns > 0: break
		highest = minf(highest, player.position.y)
	_check(launches == 0 and crystals == 0 and highest > -3650 and not stage.completed, "Without the spring, floor/companion/step/dash/wall routes cannot reach either crystal or the final platform: mode=%s air=%d direction=%s dash=%d" % [mode, air_frame, direction, dash_frame])
	_release()


func _without_crystals() -> void:
	for name in ["Item12", "Item13"]:
		stage.get_node("Items/" + name).collision_mask = 0
	for stepped in [false, true]:
		for direction in _directions():
			for dash_frame in [-1, 0, 12, 24, 36, 48]:
				await _enter()
				if stepped: await _stand_on_companion()
				await _spring_launch()
				var highest := player.position.y
				var reached := false
				for frame in 180:
					_set_direction(Vector2(360 - player.position.x, -1))
					if player.position.distance_to(companion.position) > 110:
						Input.action_press("wall_grab")
					else:
						Input.action_release("wall_grab")
					Input.action_release("jump")
					if player.is_on_wall() and frame % 18 == 0:
						Input.action_press("jump")
					if frame == dash_frame:
						_set_direction(direction)
						await _pulse("dash")
					await _step()
					if respawns > 0: break
					highest = minf(highest, player.position.y)
					reached = reached or (player.is_on_floor() and player.position.y < -3650)
				_check(launches >= 1 and crystals == 0 and creature_jumps == 0 and not reached and not stage.completed, "A spring and one ordinary dash need additional mobility to reach the summit: stepped=%s direction=%s frame=%d highest=%.2f" % [stepped, direction, dash_frame, highest])
		print("TOWER_FINALE_WITHOUT_CRYSTALS stepped=%s: 48 attempts" % stepped)
	for name in ["Item12", "Item13"]:
		stage.get_node("Items/" + name).collision_mask = 1


func _stand_on_companion() -> void:
	await _pulse("jump")
	for frame in 100:
		var dx := companion.position.x - player.position.x
		_set_direction(Vector2(signf(dx) if absf(dx) > 8 else 0.0, 0))
		await _step()
		if player.is_on_floor() and player.position.y < -3020: break
	_set_direction(Vector2.ZERO)
	await _step(4)
	_check(player.is_on_floor() and player.position.y < -3020, "A live jump stands on the companion before the bypass")


func _spring_launch() -> void:
	_set_direction(Vector2.LEFT)
	for frame in 120:
		await _step()
		if launches > 0: break
	_check(launches == 1 and player.velocity.y < -1000, "A real movement enters the entrance spring")


func _crystal_retry(reset: bool) -> void:
	await _enter()
	await _spring_launch()
	for frame in 40:
		if player.position.x <= 780: Input.action_release("move_left")
		await _step()
	_set_direction(Vector2.UP)
	await _pulse("dash")
	for frame in 90:
		if not player.is_dashing():
			_set_direction(Vector2.LEFT if player.position.x > 680 else Vector2.ZERO)
		await _step()
		if crystals == 2: break
	_check(crystals == 2 and player.is_air_jump_ready(), "The recovery starts immediately after real crystal contact")
	_release()
	if reset:
		await _pulse("reset")
	else:
		Input.action_press("move_right")
	for frame in 240:
		await _step()
		if respawns > 0: break
	_release()
	await _step(8)
	_check(respawns == 1 and stage.checkpoint_index == 5 and player.is_on_floor() and player.position.distance_to(Vector2(900, -2986)) < 4, "Crystal recovery returns to safe CP06")
	_check(stage.get_node("Items/Item12").visible and stage.get_node("Items/Item13").visible, "Both crystals reappear after a fall or immediate R")
	_check(player.is_dash_ready() and not player.is_air_jump_ready(), "Recovery restores dash and clears the unused extra jump")


func _directions() -> Array:
	return [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]


func _set_direction(direction: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if absf(direction.x) > 0.1:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if absf(direction.y) > 0.1:
		Input.action_press("move_down" if direction.y > 0 else "move_up")


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _release() -> void:
	super._release()
	Input.action_release("move_down")
	Input.action_release("reset")


func _capture(label: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/tower-finale-%s.png" % label)


func _step(count: int = 1) -> void:
	await super._step(count)
	if is_instance_valid(player) and not captured_crystals and launches > 0 and player.position.y < -3360:
		captured_crystals = true
		_capture("crystals")
	if is_instance_valid(player) and not captured_ascent and crystals == 2:
		captured_ascent = true
		_capture("ascent")
