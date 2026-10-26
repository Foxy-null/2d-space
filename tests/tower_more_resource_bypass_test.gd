extends "res://tests/tower_more_requirements_test.gd"


func _run() -> void:
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): selected = arg.trim_prefix("--only=")
	if selected in ["", "steps"]:
		for section in [14,16,17]:
			for direction in _directions():
				await _boot_step(section,direction)
				if failed:
					quit(1)
					return
			print("TOWER_MORE_BOOT_STEP ",section + 1,": 8 directions")
	if selected in ["", "throws"]:
		for stepped in [false,true]:
			for extra in [false,true]:
				for direction in _directions():
					await _wall_throw(stepped,extra,direction)
					if failed:
						quit(1)
						return
		print("TOWER_MORE_WALL_THROW: 32 real throw/step/extra directions")
	if selected in ["", "branch"]:
		for direction in _directions():
			await _branch_shortcut(direction)
			if failed:
				quit(1)
				return
		print("TOWER_MORE_BRANCH_REQUIREMENT: 8 actual wall-top directions")
	_check(attempts > 0,"A known resource-bypass group ran")
	_release()
	print("TOWER_MORE_RESOURCE_BYPASS_TEST_", "FAILED" if failed else "OK"," attempts=",attempts)
	quit(1 if failed else 0)


func _stand_on(companion: Grabbable, floor_y: float) -> void:
	Input.action_release("wall_grab")
	await _step(30)
	await _upper_pulse("jump")
	for frame in 120:
		_horizontal(companion.position.x)
		await _step()
		if player.is_on_floor() and player.position.y < floor_y - 45: break
	_check(player.is_on_floor() and player.position.y < floor_y - 45, "The bypass genuinely stands on the native companion")


func _boot_step(section: int,direction: Vector2) -> void:
	await _fresh(section)
	var target := Vector2(900,-14826)
	var floor_y := -14286.0
	match section:
		14:
			await _more_grab("More15Companion")
			_disable("More15BootA")
			await _more_walk(350)
		16:
			await _more_grab("More17Companion")
			await _more_bounce(1050,"More17Bumper",Vector2(500,-19220))
			_disable("More17Boot")
			await _more_walk(200)
			target = Vector2(900,-19786)
			floor_y = -19246
		17:
			await _more_grab("More18Companion")
			_disable("More18Boot")
			await _more_walk(1200)
			target = Vector2(800,-20986)
			floor_y = -20446
	var companion: Grabbable = player.get_held_object()
	await _stand_on(companion,floor_y)
	Input.action_press("wall_grab")
	await _upper_pulse("jump")
	_check(player.get_held_object() == companion,"A simultaneous pickup and jump uses the real stepping resource")
	_horizontal(target.x)
	await _step(20)
	await _upper_pulse("jump")
	await _step(20)
	_direction(direction)
	await _upper_pulse("dash")
	var highest := player.position.y
	var reached := false
	for frame in 200:
		if not player.is_dashing(): _horizontal(target.x)
		await _step()
		highest = minf(highest,player.position.y)
		reached = reached or (player.is_on_floor() and player.position.y <= target.y + 3) or stage.checkpoint_index > section
		if respawns > 0:break
	_check(not reached,"A step, pickup, companion jump and dash cannot replace boot %s, direction=%s rise=%s" % [section+1,direction,floor_y-highest])
	attempts += 1
	_release()


func _branch_shortcut(direction: Vector2) -> void:
	await _fresh(16)
	_disable("More17Launch")
	await _more_walk(-50)
	Input.action_press("move_left")
	await _upper_pulse("jump")
	await _step(20)
	await _upper_pulse("dash")
	for frame in 120:
		if not player.is_dashing():
			Input.action_press("wall_grab")
			Input.action_press("move_up")
		await _step()
		if player.is_on_wall():break
	_check(player.is_on_wall(), "The shortcut attempt really reaches the optional wall")
	for frame in 180:
		Input.action_press("wall_grab")
		Input.action_press("move_up")
		await _step()
		if player.is_on_floor() and player.position.y < -18500:break
	_release()
	_check(player.is_on_floor() and player.position.y < -18500, "The shortcut starts on the actual high branch wall")
	await _more_walk(-560)
	stage.get_node("Items/More17Bumper").launched.connect(_on_upper_bounce)
	Input.action_press("move_right")
	await _upper_pulse("jump")
	await _step(20)
	_direction(direction)
	await _upper_pulse("dash")
	var reached := false
	for frame in 240:
		if not player.is_dashing():_horizontal(790)
		await _step()
		reached = reached or upper_bounces > 0 or stage.checkpoint_index > 16 or (player.is_on_floor() and player.position.y < -19243)
		if respawns > 0:break
	_check(not reached,"The high scroll wall cannot replace the main spring: direction=%s" % direction)
	attempts += 1
	_release()


func _wall_throw(stepped: bool,extra: bool,direction: Vector2) -> void:
	await _fresh(15)
	await _more_grab("More16Companion")
	await _more_walk(650)
	var companion: Grabbable = player.get_held_object()
	if stepped:
		await _stand_on(companion,-15966)
		Input.action_press("wall_grab")
		await _upper_pulse("jump")
		_check(player.get_held_object() == companion,"The thrown companion was genuinely recovered from its stepping position")
	else:
		await _upper_pulse("jump")
	await _step(20)
	if extra:
		await _upper_pulse("jump")
		await _step(20)
	_direction(direction)
	Input.action_press("dash")
	Input.action_release("wall_grab")
	await _step()
	Input.action_release("dash")
	_check(player.get_held_object() == null,"Dash release actually throws the companion")
	var reached := false
	for frame in 440:
		if not player.is_dashing():
			_horizontal(686)
			Input.action_press("wall_grab")
			Input.action_press("move_up")
		await _step()
		reached = reached or stage.checkpoint_index > 15 or (player.is_on_floor() and player.position.y <= -17163)
		if respawns > 0:break
	_check(kicks == 0 and not reached,"Throw, optional step/extra jump and an unheld climb cannot replace the long wall kicks: stepped=%s extra=%s direction=%s" % [stepped,extra,direction])
	attempts += 1
	_release()
