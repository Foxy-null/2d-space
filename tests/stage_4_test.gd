extends "res://tests/stage_4_playthrough.gd"

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("STAGE4: " + message)


func _run() -> void:
	screenshot_mode = OS.get_cmdline_user_args().has("--screenshots")
	var searching := OS.get_cmdline_user_args().has("--search")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await step(3)
	current_scene.get_node("Margin/Content/Stages/Stage4").pressed.emit()
	await step(5)
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): deaths += 1)
	player.movement_action.connect(func(action): actions[action] = actions.get(action, 0) + 1)
	check(stage.rooms.get_child_count() == 6 and player.is_on_floor(), "Six rooms and safe entrance")
	for room in stage.rooms.get_children():
		check(not room.has_node("Route"), "No speculative route arrows")
		check(room.has_node("Items/JumpCreature"), "Every room supplies its own companion")
		check(room.has_node("Hazards/CeilingSpikes"), "Upper boundary has visible spikes")
		for hazard in room.get_node("Hazards").get_children():
			if hazard.ceiling_strip:
				continue
			for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
				var at: Vector2 = hazard.origin + hazard.travel * fraction
				var bounds := Rect2(at - Vector2.ONE * hazard.half_size, Vector2.ONE * hazard.half_size * 2)
				for wall in room.walls:
					check(not bounds.intersects(wall), "Patrol stays clear of terrain")
	check(SpikeBlock.segment_hits_box(Vector2(-100, 0), Vector2(100, 0), Vector2(43, 51)), "Swept collision detects a full crossing")
	check(not SpikeBlock.segment_hits_box(Vector2(-100, 70), Vector2(100, 70), Vector2(43, 51)), "Safe clearance remains safe")
	var delays := [21, 112, 42, 182, 497, 581]
	for section in 6:
		var arrived := false
		var used_delay := 0
		for attempt in (100 if searching else 1):
			release()
			player.respawn()
			await step(5)
			actions.clear()
			samples.clear()
			used_delay = attempt * 7 if searching else delays[section]
			await step(used_delay)
			var before := deaths
			arrived = await traverse(section)
			if arrived:
				check(deaths == before + (1 if section < 5 else 0), "Successful route has no death")
				break
			if attempt % 10 == 0:
				print("SEARCH room=", section + 1, " attempt=", attempt, " pos=", player.position, " last=", samples.back() if not samples.is_empty() else Vector2.ZERO, " actions=", actions)
		check(arrived, "Room %d must be traversable with live hazards" % (section + 1))
		if not arrived:
			break
		print("STAGE_4_ROOM_%d_OK delay=%d actions=%s" % [section + 1, used_delay, actions])
		check(not actions.has("climb"), "Carry route never climbs a wall")
		check(not actions.has("dash"), "Can pass without dash")
		check(actions.get("creature_jump", 0) > 0, "Use the carried creature's additional jump")
		var room: Node2D = stage.rooms.get_child(section)
		for hazard in room.get_node("Hazards").get_children():
			if hazard.ceiling_strip:
				continue
			var useful := false
			for sample in samples:
				var start: Vector2 = sample - (room.position + hazard.origin)
				if SpikeBlock.segment_hits_box(start, start - hazard.travel, Vector2(18, 26) + Vector2.ONE * hazard.half_size):
					useful = true
					break
			check(useful, "Room %d %s crosses the actual tested route" % [section + 1, hazard.name])
		release()
		await step(25)
		check(not stage.transitioning and player.controls_enabled, "Transition restores controls")
	if not failed:
		check(stage.completed and stage.get_node("HUD/Completion").visible, "Real final arrival completes stage")
		await verify_retry_and_help()
		await verify_collision()
		await verify_ceiling()
		await verify_carry_gate()
		stage.get_node("PauseMenu").open()
		stage.get_node("PauseMenu").confirm_return()
		stage.get_node("PauseMenu").return_to_select()
		await step(3)
		current_scene.get_node("Margin/Content/Stages/Stage4").pressed.emit()
		await step(5)
		check(current_scene.room_index == 0 and not current_scene.completed, "Re-entry resets progress")
	release()
	current_scene.queue_free()
	await step(10)
	print("STAGE_4_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func verify_retry_and_help() -> void:
	release()
	player.respawn()
	await step(5)
	var hazard: SpikeBlock = stage.rooms.get_child(5).get_node("Hazards/Spike1")
	stage.get_node("PauseMenu").open()
	var before := player.position
	var spike_before := hazard.position
	await step(20)
	check(player.position == before and hazard.position == spike_before, "Help freezes player and patrols")
	stage.get_node("PauseMenu").menu.get_node("Hints").pressed.emit()
	check(stage.get_node("HUD/Hint").visible, "Text hints can be enabled")
	stage.get_node("PauseMenu").menu.get_node("Retry").pressed.emit()
	await step(5)
	check(player.controls_enabled and stage.hints_visible, "Retry preserves hints")
	for y in [-100, 850]:
		player.position.y = y
		await step(4)
		check(stage.room_index == 5 and absf(player.position.x - 6510) < 2, "Falls keep current checkpoint")
		check(player.gravity_direction == 1 and player.is_dash_ready(), "Retry resets resources")
		var creature: Grabbable = stage.rooms.get_child(5).get_node("Items/JumpCreature")
		check(creature.carrier == null and creature.extra_jump_count() == 1 and creature.position.distance_to(Vector2(175, 580)) < 15, "Retry restores creature")
	Input.action_press("reset")
	await step()
	Input.action_release("reset")
	await step(4)
	check(absf(player.position.x - 6510) < 2, "R retries the current room")


func verify_collision() -> void:
	# Focused collision checks can position the player; playthroughs above cannot.
	stage.room_index = 4
	stage._set_checkpoint()
	player.respawn()
	await step(5)
	var hazard: SpikeBlock = stage.rooms.get_child(4).get_node("Hazards/Spike1")
	var at := hazard.position
	await step(20)
	check(hazard.position != at, "Hazards actually travel")
	var before := deaths
	player.global_position = hazard.global_position
	player.velocity = Vector2.ZERO
	await step(4)
	check(deaths == before + 1 and stage.room_index == 4, "Contact causes exactly one immediate retry")
	check(absf(player.position.x - 5230) < 2, "Spike death keeps checkpoint")
	check(hazard.elapsed < 0.1, "Death resets patrols")
	player.global_position = hazard.global_position + Vector2(-65, 0)
	player.velocity = Vector2.ZERO
	before = deaths
	Input.action_press("move_right")
	Input.action_press("dash")
	await step(6)
	release()
	check(deaths == before + 1, "Dash does not bypass lethal spikes")


func verify_carry_gate() -> void:
	for section in 6:
		release()
		stage.room_index = section
		stage.completed = false
		stage._set_checkpoint()
		player.respawn()
		await step(5)
		check(not stage._carry_requirement_met(), "Every room requires its companion")
		if section < 5:
			player.position = Vector2(section * 1280 + 1262, 474)
			await step(10)
			check(stage.room_index == section, "Cannot leave any room empty-handed")
		else:
			stage._on_completed()
			check(not stage.completed, "Cannot complete the last room empty-handed")
		player.respawn()
		await step(5)
		Input.action_press("move_right")
		Input.action_press("wall_grab")
		for frame in 30:
			await step()
			if player.get_held_object() != null:
				break
		release()
		check(stage._carry_requirement_met(), "Holding the room's companion satisfies its gate")
	stage.room_index = 5
	stage.completed = false
	stage._set_checkpoint()
	player.respawn()
	await step(5)
	check(stage.rooms.get_child(5).get_node("Goal").locked, "Final goal requires its creature")


func verify_ceiling() -> void:
	for section in 6:
		stage.room_index = section
		stage._set_checkpoint()
		for x in [80, 640, 1200]:
			release()
			player.respawn()
			await step(5)
			player.position = Vector2(section * 1280 + x, 68)
			player.velocity = Vector2.ZERO
			var before := deaths
			Input.action_press("move_up")
			Input.action_press("dash")
			await step(2)
			release()
			check(deaths == before + 1, "Visible ceiling spikes stop upward movement inside the screen")
			check(stage.room_index == section and absf(player.position.x - (section * 1280 + 110)) < 2, "Ceiling death returns to the same entrance")
