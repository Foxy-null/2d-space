extends "res://tests/corridor_wide_route_test.gd"

const DIRECTIONS := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]
var trials := 0
var real_refill_trials := 0

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_wide_required_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	for entry in [[15, "refill"], [15, "companion"], [15, "step"], [15, "moved_step"], [16, "up"], [17, "wind"], [17, "companion"], [17, "wall"]]:
		await _new_stage()
		for redash_gap in ([12, 28, 40] if entry[0] == 15 and entry[1] in ["companion", "step", "moved_step"] else [12]):
			for delay in [16, 28, 40]:
				for direction in DIRECTIONS:
					await _omit(entry[0], entry[1], delay, direction, redash_gap)
					if failed: return
		print("CORRIDOR_WIDE_OMIT room=%d mode=%s cumulative=%d" % [entry[0]+1, entry[1], trials])
	_check(real_refill_trials > 0, "The no-companion comparisons include actual crystal recovery and re-Dash")
	await _new_stage()
	await _without_down()
	if failed: return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CORRIDOR_WIDE_REQUIRED_TEST_OK (%d checks, %d routes, %d actual refill trials)" % [checks, trials, real_refill_trials])
	quit()


func _omit(section: int, mode: String, delay: int, direction: Vector2, redash_gap: int) -> void:
	await _enter(section)
	var room: Node2D = stage.rooms.get_child(section)
	var creature: Grabbable = room.get_node("Items/JumpCreature")
	player.wall_actions_enabled = true
	if mode == "refill":
		var crystal: Area2D = room.get_node("Items/DashCrystal")
		crystal._available = false
		crystal.set_physics_process(false)
	elif mode == "up":
		room.get_node("Items/UpGate").monitoring = false
		room.get_node("Items/UpGate/CollisionShape2D").disabled = true
	elif mode == "wind":
		room.get_node("HighTailwind").wind_acceleration = 0
	elif mode == "wall":
		_check(await traverse_wide(section, true) and await more_walk(1310), "The wall comparison starts after the actual wind and safe island")
		player.wall_actions_enabled = false
	if failed: return
	if mode in ["step", "moved_step"]:
		if mode == "moved_step":
			_check(await more_walk(430), "The raised comparison carries the original companion below the actual refill column")
			release()
			await step(30)
			_check(player.get_held_object() == null and creature.carrier == null and absf(creature.linear_velocity.y) < 20, "The companion really rests on the entrance after a physical drop")
			if failed: return
		release()
		await more_jump()
		for frame in 120:
			release()
			steer_to(creature.global_position.x - player.global_position.x)
			await step()
			if player.is_on_floor() and player.position.y < room.entrance_top - 60: break
		var supported := false
		for index in player.get_slide_collision_count(): supported = supported or player.get_slide_collision(index).get_collider() == creature
		_check(supported and player.get_held_object() == null, "The shortcut really stands on the physical free companion")
		_hold()
	else:
		_check(await more_walk(430 if section == 15 else (1310 if mode == "wall" else 218)), "The omission starts from the real carried companion and floor")
	if failed: return
	actions.clear()
	var before := deaths
	var target: Rect2 = room.walls[1 if mode == "wall" else 0]
	var reached := false
	var refilled := false
	await more_jump()
	_check(player.get_held_object() == creature and actions.get("jump", 0) == 1, "The attempt really uses normal Jump while holding the original companion")
	for frame in 360:
		if mode in ["companion", "step", "moved_step"]: creature.consume_extra_jump()
		more_drive((430.0 if section == 15 and frame < delay + redash_gap + 10 else target.get_center().x) - _more_x())
		if section == 15 and mode != "refill": refilled = refilled or room.get_node("Items/DashCrystal")._respawn_left > 0
		if frame == 20 and mode not in ["companion", "step", "moved_step"]: await more_jump()
		if frame == delay:
			_drive(direction)
			await _pulse("dash")
		elif frame == delay + redash_gap and player.is_dash_ready():
			_drive(Vector2.UP)
			await _pulse("dash")
		if player.is_on_wall() and mode != "wall" and frame % 12 == 0: await more_jump()
		await step()
		reached = reached or _on_more_rest(target) or (section == 16 and _on_wide_ceiling(target))
		if deaths != before or stage.room_index != section or stage.completed: break
	_check(not reached and stage.room_index == section and not stage.completed, "The omitted action cannot be replaced by this actual eight-way Dash route: room=%d mode=%s delay=%d redash=%d direction=%s" % [section+1, mode, delay, redash_gap, direction])
	if mode in ["companion", "step", "moved_step"]: _check(not actions.has("creature_jump"), "The comparison actually omits companion Jump")
	if mode == "wall": _check(not actions.has("wall_jump"), "The comparison actually omits wall kicks")
	if refilled: real_refill_trials += 1
	trials += 1


func _without_down() -> void:
	for delay in [16, 28, 40]:
		for direction in DIRECTIONS:
			await _enter(16)
			var room: Node2D = stage.rooms.get_child(16)
			_check(await traverse_wide(16, true) and await wide_ceiling_transfer(room.walls[1], 20), "The Down comparison really reaches the second inverted ceiling")
			if failed: return
			room.get_node("Items/DownGate").monitoring = false
			room.get_node("Items/DownGate/CollisionShape2D").disabled = true
			var before := deaths
			more_drive(1900 - _more_x())
			await more_jump()
			for frame in 420:
				more_drive(1900 - _more_x())
				if frame == 20: await more_jump()
				if frame == delay:
					_drive(direction)
					await _pulse("dash")
				await step()
				if deaths != before or stage.room_index != 16 or stage.completed: break
			_check(stage.room_index == 16 and not stage.completed and player.gravity_direction == (-1 if deaths == before else 1), "The inverted route cannot use the exit underside or boundary without Down")
			trials += 1
