extends "res://tests/tower_upper_requirements_test.gd"

const KINDS := ["12_new_wall", "13_wall", "13_refill", "13_spring", "14_launch", "14_bumper", "14_spring", "15_boot_a", "15_boot_b", "15_companion", "15_wall", "16_wall", "16_companion", "16_refill", "17_launch", "17_bumper", "17_boot", "17_companion", "17_spring", "18_boot", "18_companion", "18_wall", "18_spring", "18_refill"]


func _run() -> void:
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): selected = arg.trim_prefix("--only=")
	var late_only := OS.get_cmdline_user_args().has("--late-resource-only")
	var plain_only := OS.get_cmdline_user_args().has("--no-dash-only")
	for kind in KINDS:
		if selected != "" and selected != kind and not kind.begins_with(selected + "_"): continue
		if late_only:
			if kind != "17_bumper": continue
			for direction in _directions():
				await _missing(kind,direction,65)
				if failed:
					quit(1)
					return
			print("TOWER_MORE_REQUIREMENT ",kind,": 8 late companion-jump/dash directions")
			continue
		if plain_only:
			await _missing(kind,Vector2.ZERO,-1)
			if failed:
				quit(1)
				return
			print("TOWER_MORE_REQUIREMENT ",kind,": ordinary jump without dash")
			continue
		for direction in _directions():
			for timing in [16, 24, 40]:
				await _missing(kind, direction, timing)
				if failed:
					quit(1)
					return
		print("TOWER_MORE_REQUIREMENT ", kind, ": 24 directions/timings")
	_check(attempts > 0, "The selected new requirement is known")
	_release()
	print("TOWER_MORE_REQUIREMENTS_TEST_", "FAILED" if failed else "OK", " attempts=", attempts)
	quit(1 if failed else 0)


func _missing(kind: String, direction: Vector2, timing: int) -> void:
	var section := int(kind.split("_")[0]) - 1
	await _fresh(section)
	var target := Vector2.ZERO
	var airborne := false
	match kind:
		"12_new_wall":
			await _boot_transfer(460, "SummitBoot", 800, -10006)
			_disable("SummitDash")
			_horizontal(1080)
			await _await_launch()
			airborne = true
			target = Vector2(512,-10726)
		"13_wall":
			player.wall_actions_enabled = false
			await _more_walk(380)
			target = Vector2(660, -11326)
		"13_refill", "13_spring":
			await _more_walk(390)
			await _more_climb("More13Wall")
			if kind == "13_refill":
				_disable("More13Dash")
				await _more_walk(700)
				target = Vector2(700, -11826)
			else:
				await _more_refill("More13Dash", 700, Vector2(700, -11800))
				_disable("More13Spring")
				await _more_walk(1900)
				target = Vector2(1450, -12486)
		"14_launch", "14_bumper", "14_spring":
			target = Vector2(800, -13626)
			if kind == "14_spring":
				await _more_bounce(1300, "More14Bumper", Vector2(800, -13600))
				_disable("More14Spring")
				await _more_walk(-800)
				target = Vector2(300, -14286)
			elif kind == "14_bumper":
				_disable("More14Bumper")
				_horizontal(1300)
				await _await_launch_long()
				airborne = true
			else:
				_disable("More14Launch")
				await _more_walk(1300)
		"15_boot_a", "15_boot_b", "15_companion", "15_wall":
			if kind != "15_companion": await _more_grab("More15Companion")
			target = Vector2(900, -14826)
			if kind in ["15_boot_b", "15_wall"]:
				await _more_boot(350, "More15BootA", Vector2(900, -14800))
			if kind == "15_wall":
				await _more_boot(1350, "More15BootB", Vector2(850, -15340))
				await _more_walk(600)
				_release()
				await _step(2)
				player.wall_actions_enabled = false
				target = Vector2(230, -15966)
			elif kind == "15_boot_b":
				_disable("More15BootB")
				await _more_walk(1350)
				target = Vector2(850, -15366)
			else:
				if kind == "15_boot_a": _disable("More15BootA")
				await _more_walk(350)
		"16_wall":
			await _more_walk(650)
			target = Vector2(686, -17166)
		"16_companion":
			await _more_wall_rest(false)
			await _more_walk(750)
			target = Vector2(1050, -17606)
		"16_refill":
			await _more_air_rest()
			_disable("More16Dash")
			await _more_walk(1400)
			target = Vector2(1200, -18106)
		"17_launch", "17_bumper", "17_boot", "17_companion", "17_spring":
			if kind != "17_companion": await _more_grab("More17Companion")
			target = Vector2(500, -19246)
			if kind in ["17_boot", "17_companion", "17_spring"]:
				await _more_bounce(1050, "More17Bumper", Vector2(500, -19220))
				if kind == "17_spring":
					await _more_boot(200, "More17Boot", Vector2(900, -19760))
					_disable("More17Spring")
					await _more_walk(1600)
					target = Vector2(1300, -20446)
				else:
					if kind == "17_boot": _disable("More17Boot")
					await _more_walk(200)
					target = Vector2(900, -19786)
			elif kind == "17_bumper":
				_disable("More17Bumper")
				_horizontal(1050)
				await _await_launch_long()
				airborne = true
			else:
				_disable("More17Launch")
				await _more_walk(1050)
		"18_boot", "18_companion", "18_wall", "18_spring", "18_refill":
			if kind != "18_companion": await _more_grab("More18Companion")
			target = Vector2(800, -20986)
			if kind in ["18_wall", "18_spring", "18_refill"]:
				await _more_boot(1200, "More18Boot", Vector2(800, -20960))
				await _more_walk(450)
				if kind == "18_wall":
					_release()
					await _step(2)
					player.wall_actions_enabled = false
					target = Vector2(200, -21586)
				else:
					await _more_climb("More18Wall", true)
					target = Vector2(-100, -22346)
					if kind == "18_spring":
						_disable("More18Spring")
						await _more_walk(230)
					else:
						_disable("More18Dash")
						_horizontal(230)
						await _await_launch_long()
						airborne = true
			else:
				if kind == "18_boot": _disable("More18Boot")
				await _more_walk(1200)
	if failed: return
	_release()
	if player.get_held_object() != null: Input.action_press("wall_grab")
	if not airborne: await _upper_pulse("jump")
	var reached := false
	for frame in 240:
		if not player.is_dashing():
			_horizontal(target.x)
			if kind in ["16_wall", "12_new_wall"]:
				# Try a hands-free climb too, while deliberately omitting wall kicks.
				Input.action_press("wall_grab")
				Input.action_press("move_up")
		if frame in ([45] if timing >= 60 and airborne else [20,40]) and not player.is_on_wall() and (player.is_air_jump_ready() or player.get_available_extra_jump_count() > 0): await _upper_pulse("jump")
		if frame == timing:
			_direction(direction)
			await _upper_pulse("dash")
		await _step()
		reached = reached or stage.checkpoint_index > section or stage.completed or (player.is_on_floor() and player.position.y <= target.y + 3)
		if kind == "18_spring": reached = reached or not stage.get_node("Items/More18Dash").visible
		if respawns > 0: break
	_check(not reached, "Omitting %s cannot reach %s, direction=%s frame=%d at=%s" % [kind,target,direction,timing,player.position])
	attempts += 1
	_release()
