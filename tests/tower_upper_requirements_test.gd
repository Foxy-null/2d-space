extends "res://tests/stage_2_test.gd"

var attempts := 0
var kicks := 0
var creature_jumps := 0


func _run() -> void:
	var selected := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			selected = argument.trim_prefix("--only=")
	for kind in ["wall", "refill", "spring_out", "spring_return", "boot_first", "boot_return", "boot_companion", "companion", "wind_spring", "wind_bumper", "summit_spring", "summit_refill"]:
		if selected != "" and selected != kind:
			continue
		for direction in _directions():
			for dash_frame in [16, 24, 40]:
				await _attempt(kind, direction, dash_frame)
				if failed:
					quit(1)
					return
		print("TOWER_UPPER_REQUIREMENT ", kind, ": 24 directions/timings")
	if selected in ["", "throws"]:
		for stepped in [false, true]:
			for extra in [false, true]:
				for direction in _directions():
					await _throw_bypass(stepped, extra, direction)
					if failed:
						quit(1)
						return
	_check(selected in ["", "alternatives", "stepping", "throws"] or attempts > 0, "The selected requirement test is known")
	if selected in ["", "stepping"]:
		await _stepping_resource_bypasses()
	if selected in ["", "alternatives"]:
		await _carry_alternatives()
	print("TOWER_UPPER_REQUIREMENTS_TEST_", "FAILED" if failed else "OK", " attempts=", attempts)
	quit(1 if failed else 0)


func _fresh(checkpoint: int) -> void:
	_release()
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(5)
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action: String):
		if action == "wall_jump": kicks += 1
		if action == "creature_jump": creature_jumps += 1)
	stage._set_checkpoint(checkpoint)
	player.respawn()
	await _step(6)
	respawns = 0
	kicks = 0
	creature_jumps = 0
	upper_bounces = 0


func _directions() -> Array[Vector2]:
	return [Vector2.UP, Vector2(-1, -1), Vector2(1, -1), Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2(-1, 1), Vector2(1, 1)]


func _direction(value: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if value.x != 0:
		Input.action_press("move_right" if value.x > 0 else "move_left")
	if value.y != 0:
		Input.action_press("move_down" if value.y > 0 else "move_up")


func _disable(item: String) -> void:
	stage.get_node("Items/" + item).collision_mask = 0


func _attempt(kind: String, direction: Vector2, dash_frame: int) -> void:
	var target := Vector2.ZERO
	match kind:
		"wall":
			await _fresh(6)
			player.wall_actions_enabled = false
			await _walk_to(960)
			target = Vector2(1100, -4306)
		"refill":
			await _fresh(6)
			await _upper_wall_rest()
			_disable("UpperDash")
			target = Vector2(900, -4666)
		"spring_out":
			await _fresh(7)
			_disable("TurnLaunch")
			target = Vector2(420, -5226)
		"spring_return":
			await _fresh(7)
			Input.action_press("move_right")
			await _await_launch()
			_horizontal(420)
			await _step(46)
			await _upper_pulse("dash")
			await _land_on(420, -5226)
			_disable("TurnReturn")
			target = Vector2(360, -5626)
		"boot_first":
			await _fresh(8)
			await _grab_boot_companion()
			_disable("BootRight")
			await _walk_to(480)
			target = Vector2(800, -6166)
		"boot_return":
			await _fresh(8)
			await _grab_boot_companion()
			_disable("BootLeft")
			await _boot_transfer(480, "BootRight", 800, -6166)
			await _walk_to(790)
			target = Vector2(450, -6706)
		"boot_companion":
			await _fresh(8)
			await _walk_to(480)
			target = Vector2(800, -6166)
		"companion":
			await _fresh(9)
			await _upper_companion_rest()
			_check(player.get_held_object() == null, "The unheld wall kicks do not silently acquire a companion")
			await _walk_to(690)
			target = Vector2(900, -8426)
		"wind_spring":
			await _fresh(9)
			await _upper_course(9)
			_disable("WindLaunch")
			stage.get_node("Items/WindBumper").launched.connect(_on_upper_bounce)
			await _walk_to(820)
			target = Vector2(560, -9566)
		"wind_bumper":
			await _fresh(9)
			await _upper_course(9)
			_disable("WindBumper")
			_horizontal(780)
			await _await_launch()
			target = Vector2(360, -9566)
		"summit_spring":
			await _fresh(9)
			await _upper_course(9)
			await _upper_course(10)
			await _boot_transfer(460, "SummitBoot", 800, -10006)
			_disable("SummitLaunch")
			target = Vector2(850, -10560)
		"summit_refill":
			await _fresh(11)
			await _boot_transfer(460, "SummitBoot", 800, -10006)
			_check(player.get_held_object() == null, "The mandatory-refill case is deliberately empty handed")
			_disable("SummitDash")
			_horizontal(1080)
			await _await_launch()
			target = Vector2(500, -10726)
	_release()
	# The carried companion is deliberately available in the upper synthesis cases.
	if player.get_held_object() != null:
		Input.action_press("wall_grab")
	if kind not in ["wind_bumper", "summit_refill"]:
		await _upper_pulse("jump")
	var reached := false
	var first_checkpoint: int = stage.checkpoint_index
	for frame in 220:
		if not player.is_dashing():
			_horizontal(target.x)
			if kind == "wall":
				Input.action_press("wall_grab")
				Input.action_press("move_up")
		if frame == 20 and (player.get_held_object() != null or player.is_air_jump_ready()):
			await _upper_pulse("jump")
		if frame == dash_frame:
			_direction(direction)
			await _upper_pulse("dash")
		await _step()
		reached = reached or (player.is_on_floor() and player.position.y <= target.y + 3) or stage.checkpoint_index > first_checkpoint
		if kind == "wind_spring":
			reached = reached or upper_bounces > 0
		if kind == "summit_spring":
			reached = reached or not stage.get_node("Items/SummitDash").visible
		if respawns > 0:
			break
	_check(not reached, "Omitting %s cannot reach %s, direction=%s frame=%d at=%s" % [kind, target, direction, dash_frame, player.position])
	attempts += 1
	_release()


func _throw_bypass(stepped: bool, extra: bool, direction: Vector2) -> void:
	await _fresh(9)
	var companion: Grabbable = stage.get_node("Items/UpperCompanion")
	await _walk_to(companion.position.x - 70)
	if stepped:
		Input.action_press("wall_grab")
		await _step(2)
		await _walk_to(610)
		Input.action_release("wall_grab")
		await _step(30)
		await _upper_pulse("jump")
		for frame in 100:
			_horizontal(companion.position.x)
			await _step()
			if player.is_on_floor() and player.position.y < -6730:
				break
		_check(player.is_on_floor() and player.position.y < -6730, "A real jump reaches the companion as a stepping stone")
	Input.action_press("wall_grab")
	await _step(2)
	_check(player.get_held_object() == companion, "The throw case really grabs its companion")
	if not stepped:
		await _walk_to(610)
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
	_check(player.get_held_object() == null, "The dash release actually throws the companion: step=%s extra=%s direction=%s p=%s" % [stepped, extra, direction, player.position])
	for frame in 440:
		if not player.is_dashing():
			_horizontal(740)
			Input.action_press("move_up")
			Input.action_press("wall_grab")
		await _step()
		if respawns > 0:
			break
	_check(kicks == 0 and stage.checkpoint_index == 9 and player.position.y > -7980, "A throw/step/extra-jump and unheld climb cannot skip the tall companion wall: step=%s extra=%s direction=%s" % [stepped, extra, direction])
	attempts += 1
	_release()


func _carry_alternatives() -> void:
	# The real companion may be thrown onto the wall, then recovered after climbing.
	await _fresh(4)
	await _companion_course()
	await _finale_course()
	var carried: Grabbable = player.get_held_object()
	await _walk_to(300)
	Input.action_press("move_right")
	await _upper_pulse("jump")
	await _step(20)
	await _upper_pulse("jump")
	Input.action_release("wall_grab")
	await _step(91)
	await _upper_wall_rest()
	for frame in 120:
		_horizontal(carried.position.x)
		if frame % 3 == 0:
			Input.action_release("wall_grab")
		else:
			Input.action_press("wall_grab")
		await _step()
		if player.get_held_object() == carried:
			break
	_check(player.get_held_object() == carried, "A real throw and climb recover the companion on the wall's rest")
	await _upper_pulse("jump")
	await _land_on(player.position.x, -4306)
	_check(carried.extra_jump_count() == 1, "A fresh landing restores the transported companion")
	_disable("UpperDash")
	await _upper_pulse("jump")
	_horizontal(900)
	await _step(20)
	await _upper_pulse("jump")
	await _step(20)
	await _upper_dash()
	await _land_on(900, -4666)
	_check(stage.checkpoint_index == 7 and respawns == 0, "Transporting the companion is an optional air-resource alternative after the wall")
	print("TOWER_UPPER_WALL_CARRY_ALTERNATIVE_OK")

	await _upper_course(7)
	_check(player.get_held_object() == carried, "The actual spring fold keeps the companion transported from the lower tower")
	_disable("BootRight")
	await _walk_to(480)
	await _upper_pulse("jump")
	_horizontal(800)
	await _step(20)
	await _upper_pulse("jump")
	await _step(20)
	await _upper_dash()
	for frame in 180:
		if not player.is_dashing():
			_horizontal(800)
		await _step()
		if respawns > 0:
			break
	_check(respawns == 1 and stage.checkpoint_index == 8 and stage.get_node("Items/BootRight").visible, "The genuinely transported companion cannot replace the first 540px boot flight")
	print("TOWER_UPPER_TRANSPORTED_BOOT_NEGATIVE_OK")

	await _fresh(9)
	await _upper_course(9)
	await _upper_course(10)
	await _boot_transfer(460, "SummitBoot", 800, -10006)
	_disable("SummitDash")
	_horizontal(1080)
	await _await_launch()
	_horizontal(760)
	await _step(40)
	var jumps_before := creature_jumps
	await _upper_pulse("jump")
	await _step(20)
	await _upper_dash()
	await _land_on(500, -10726, 240)
	_check(respawns == 0 and creature_jumps == jumps_before + 1 and player.is_on_floor(), "Spring plus a genuinely transported companion reaches the summit without the crystal")
	print("TOWER_UPPER_SUMMIT_CARRY_ALTERNATIVE_OK")


func _stepping_resource_bypasses() -> void:
	for kind in ["wind", "summit"]:
		for direction in _directions():
			await _fresh(9)
			await _upper_course(9)
			var floor_y := -8426.0
			if kind == "summit":
				await _upper_course(10)
				await _boot_transfer(460, "SummitBoot", 800, -10006)
				floor_y = -10006.0
				_disable("SummitLaunch")
			else:
				_disable("WindLaunch")
				stage.get_node("Items/WindBumper").launched.connect(_on_upper_bounce)
			var companion: Grabbable = player.get_held_object()
			await _walk_to(900 if kind == "wind" else 850)
			Input.action_release("wall_grab")
			await _step(30)
			await _upper_pulse("jump")
			for frame in 100:
				_horizontal(companion.position.x)
				await _step()
				if player.is_on_floor() and player.position.y < floor_y - 45:
					break
			_check(player.is_on_floor() and player.position.y < floor_y - 45, "The resource bypass genuinely stands on its transported companion")
			_horizontal(player.position.x)
			Input.action_press("wall_grab")
			await _upper_pulse("jump")
			_check(player.get_held_object() == companion, "The stepping case grabs while jumping")
			await _step(20)
			await _upper_pulse("jump")
			await _step(20)
			_direction(direction)
			await _upper_pulse("dash")
			var highest := player.position.y
			for frame in 180:
				if not player.is_dashing():
					_horizontal(560 if kind == "wind" else 850)
				await _step()
				highest = minf(highest, player.position.y)
				if respawns > 0:
					break
			var reached: bool = upper_bounces > 0 if kind == "wind" else not stage.get_node("Items/SummitDash").visible
			_check(not reached, "A transported companion used as step, pickup and extra jump cannot replace the %s spring: direction=%s rise=%s" % [kind, direction, floor_y - highest])
			attempts += 1
			if failed:
				return
		print("TOWER_UPPER_STEP_REQUIREMENT ", kind, ": 8 directions")
