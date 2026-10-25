extends "res://tests/stage_4_playthrough.gd"

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_expansion_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	for strength in [1.0, 0.85]:
		steering_strength = strength
		await _new_stage()
		await _enter(6)
		for section in range(6, 9):
			var before := deaths
			var started := Engine.get_physics_frames()
			actions.clear()
			_check(await traverse(section, true), "Reach a safe rest with the original companion")
			_hold()
			await step(12)
			var rest := player.position
			await step(180)
			_check(player.position.distance_to(rest) < 2 and player.is_dash_ready() and player.get_available_extra_jump_count() == 1, "The broad rest restores both resources and remains safe for three seconds")
			if OS.get_cmdline_user_args().has("--screenshots") and strength == 1.0:
				await _capture("room_%d_rest" % (section+1))
			_check(await traverse(section), "The new carry course reaches its next checkpoint: room %d" % (section+1))
			_check(deaths == before + 1, "The successful course never dies")
			_check(actions.has("creature_jump") and not actions.has("climb"), "The held companion performs its actual additional jump")
			if section == 7:
				_check(actions.has("wall_jump"), "The shaft uses real wall kicks while carrying")
			var seconds := (Engine.get_physics_frames()-started)/60.0
			_check(seconds < 30, "The next checkpoint stays within thirty seconds including rest")
			print("EXPANSION_ROOM_%d %.2fs strength=%.2f actions=%s" % [section+1, seconds, strength, actions])
			release()
			await step(25)
		_check(stage.room_index == 9 and not stage.completed, "The old ninth room leads to the new course")
		if OS.get_cmdline_user_args().has("--screenshots") and strength == 1.0:
			await _capture("room_9_exit")
	steering_strength = 1.0
	await _new_stage()
	if not OS.get_cmdline_user_args().has("--positive"):
		await _timing_window()
		for section in range(6, 9):
			await _without_action(section)
			await _contact_retry(section)
	await _scroll_route(progress)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	release()
	print("CORRIDOR_EXPANSION_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _new_stage() -> void:
	change_scene_to_file("res://scenes/stage_4.tscn")
	await step(5)
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): deaths += 1)
	player.movement_action.connect(func(action): actions[action] = actions.get(action, 0) + 1)


func _enter(section: int, wait: int = 0) -> void:
	release()
	Input.action_release("reset")
	stage.room_index = section
	stage._set_checkpoint()
	player.respawn()
	await step(5 + wait)
	actions.clear()


func _hold() -> void:
	release()
	Input.action_press("wall_grab")


func _drive(direction: Vector2) -> void:
	_hold()
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")


func _pulse(action: String) -> void:
	Input.action_press(action)
	await step()
	Input.action_release(action)


func _without_action(section: int) -> void:
	var room: Node2D = stage.rooms.get_child(section)
	var creature: Grabbable = room.get_node("Items/JumpCreature")
	for hazard in room.get_node("Hazards").get_children():
		if not hazard.ceiling_strip:
			hazard.set_physics_process(false)
	player.wall_actions_enabled = section != 7
	for launch in [185, 218]:
		for delay in [12, 28, 44]:
			for direction in [Vector2.RIGHT, Vector2(1,-1), Vector2.UP, Vector2(-1,-1), Vector2.LEFT, Vector2(-1,1), Vector2.DOWN, Vector2(1,1)]:
				await _enter(section)
				if launch == 185 and section != 7:
					await _pulse("jump")
					for frame in 100:
						release()
						steer_to(175 - _x())
						await step()
						if player.is_on_floor() and player.position.y + 26 < room.entrance_top - 40:
							break
					_check(player.is_on_floor() and player.position.y + 26 < room.entrance_top - 40, "The raised shortcut physically stands on the free companion")
					_hold()
				else:
					_drive(Vector2.RIGHT)
					for frame in 60:
						if _x() >= launch:
							break
						await step()
				var before := deaths
				await _pulse("jump")
				_check(player.get_held_object() == creature, "Each negative attempt holds the room's real companion")
				var reached := false
				for frame in 180:
					_drive(direction if frame == delay else Vector2.RIGHT)
					if section != 7:
						creature.consume_extra_jump()
					if frame == delay:
						await _pulse("dash")
					if (section == 7 and frame == 20) or (player.is_on_wall() and frame % 12 == 0):
						await _pulse("jump")
					await step()
					reached = reached or (player.is_on_floor() and absf(player.position.y + 26 - room.walls[0].position.y) < 5 and _x() > room.walls[0].position.x)
					if deaths != before or stage.room_index != section:
						break
				_check(not reached and stage.room_index == section and not actions.has("wall_jump" if section == 7 else "creature_jump"), "Without the required action, eight-way Dash and wall attempts do not reach the first rest")
	player.wall_actions_enabled = true
	for hazard in room.get_node("Hazards").get_children():
		hazard.set_physics_process(true)


func _timing_window() -> void:
	for strength in [1.0, 0.85]:
		for extra in [16, 20, 24]:
			for dash in [16, 20, 24]:
				await _enter(8)
				var before := deaths
				_check(await island_leap(extra, dash, strength, 8) and deaths == before, "The high wind accepts several companion-jump and Dash timings at full and weak input")
	for launch in [185, 205, 218]:
		await _enter(6)
		_drive(Vector2.RIGHT)
		while _x() < launch:
			await step()
		var before := deaths
		_check(await traverse(6, true) and deaths == before, "The first high transfer accepts several real takeoff positions")


func _contact_retry(section: int) -> void:
	await _enter(section)
	_drive(Vector2.RIGHT)
	await step(12)
	var creature: Grabbable = stage.rooms.get_child(section).get_node("Items/JumpCreature")
	_check(player.get_held_object() == creature, "The contact-death attempt carries its original companion")
	var hazard: SpikeBlock = stage.rooms.get_child(section).get_node("Hazards/Spike1")
	var hits := [0]
	hazard.player_hit.connect(func(): hits[0] += 1, CONNECT_ONE_SHOT)
	player.global_position = hazard.global_position + Vector2(-80, -60)
	player.velocity = Vector2.ZERO
	player._contacts_valid = false
	var before := deaths
	_drive(Vector2(1, 1))
	await _pulse("dash")
	for frame in 15:
		await step()
		if deaths != before:
			release()
			break
	_check(hits[0] == 1 and deaths == before + 1, "A real diagonal Dash into the patrol produces one physical spike death")
	release()
	await step(5)
	_check(player.position.distance_to(player._spawn_position) < 2 and player.is_dash_ready() and player.get_held_object() == null and creature.extra_jump_count() == 1, "Contact death restores the entrance, companion and abilities")
	await _pulse("jump")
	await _pulse("reset")
	release()
	await step(5)
	_check(player.position.distance_to(player._spawn_position) < 2 and player.get_held_object() == null, "An actual R input restores the current room after a jump")


func _scroll_route(progress: Node) -> void:
	await _enter(6)
	await _branch_touch()
	await _pulse("reset")
	release()
	await step(5)
	_check(not progress.has_scroll("companion", "relay_left_01"), "R before a safe landing cancels the branch scroll")
	await _branch_touch()
	player.respawn()
	await step(5)
	_check(not progress.has_scroll("companion", "relay_left_01"), "Death before confirmation cancels the branch scroll")
	await _branch_touch()
	stage.get_node("PauseMenu").return_to_select()
	await step(4)
	_check(not progress.has_scroll("companion", "relay_left_01"), "Leaving before confirmation does not save the branch scroll")
	await _new_stage()
	await _enter(6)
	var before := deaths
	var started := Engine.get_physics_frames()
	await _branch_touch()
	_hold()
	await step(30)
	_check(progress.has_scroll("companion", "relay_left_01") and stage._carry_requirement_met(), "A safe branch landing saves the scroll while retaining the companion")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _capture("scroll_loft")
	await _move_to(480)
	for frame in 100:
		if player.is_on_floor() and absf(player.position.y + 26 - 800) < 5:
			break
		await step()
	_check(deaths == before and player.is_on_floor() and absf(player.position.y + 26 - 800) < 5 and stage._carry_requirement_met(), "The optional left branch returns safely to the same main rest with its companion")
	_check((Engine.get_physics_frames()-started)/60.0 < 30, "The scroll detour keeps a short retry interval")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _capture("scroll_return")
	await _pulse("reset")
	release()
	await step(5)
	player.respawn()
	await step(5)
	_check(progress.get_count("companion") == 1 and stage.rooms.get_child(6).get_node("Scroll").modulate.a < 1, "Confirmed collection survives R and death without being counted again")
	stage.get_node("PauseMenu").return_to_select()
	await step(4)
	_check(current_scene.get_node("Margin/Content/Stages/Stage4/Content/Collection/Count").text == "1 / 3", "Stage selection shows the actual companion scroll count")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.has_scroll("companion", "relay_left_01"), "Unfinished-stage return retains the saved scroll")


func _branch_touch() -> void:
	_check(await traverse(6, true), "Reach the main rest before the optional left branch")
	var cooldown := 0
	for frame in 150:
		_hold()
		steer_to(180 - _x())
		cooldown = maxi(0, cooldown - 1)
		if player.is_on_floor() and player.position.y > 700 and cooldown == 0:
			Input.action_press("jump")
			cooldown = 10
		elif not player.is_on_floor() and player.velocity.y > -40 and player.get_available_extra_jump_count() > 0 and cooldown == 0:
			Input.action_press("jump")
			cooldown = 10
		await step()
		if stage.rooms.get_child(6).get_node("Scroll")._follower == player:
			return
	_check(false, "A real companion jump touches the upper-left scroll")


func _move_to(target: float) -> void:
	for frame in 180:
		_hold()
		steer_to(target - _x())
		await step()
		if absf(target-_x()) < 5 and absf(player.velocity.x) < 20:
			_hold()
			return
	_check(false, "Real horizontal input reaches its target")


func _x() -> float:
	return player.position.x - stage.room_index * 1280


func _capture(label: String) -> void:
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/corridor-expansion")
	root.get_texture().get_image().save_png("res://docs/screenshots/corridor-expansion/%s.png" % label)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("CORRIDOR_EXPANSION: %s pos=%s actions=%s" % [message, player.position - stage.rooms.get_child(stage.room_index).position, actions])
		quit(1)
