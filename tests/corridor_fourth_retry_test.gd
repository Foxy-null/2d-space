extends "res://tests/corridor_fourth_route_test.gd"

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_fourth_retry_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	for section in range(18, 24):
		await _new_stage()
		await _enter(section)
		observe_fourth_view = true
		_check(await traverse_fourth(section, true), "The retry begins after the actual first native operation")
		if failed: return
		var before := deaths
		await _pulse("reset")
		release()
		await step(6)
		_check(deaths == before + 1, "R triggers exactly one retry")
		_check_restored(section)
		await _actual_left_spike()
		_check_restored(section)
		observe_fourth_view = true
		_check(await traverse_fourth(section), "R and real contact death still allow the entire native route to its next checkpoint or Goal")
		if failed: return
		print("FOURTH_RETRY room=", section + 1)
	for previous in [17, 22]:
		observe_fourth_view = false
		await _new_stage()
		await _enter(previous)
		var foreign: Grabbable = stage.rooms.get_child(previous).get_node("Items/JumpCreature")
		_check(await traverse(previous), "The previous room actually carries its original companion to the next room")
		release()
		await step(25)
		_check(stage.room_index == previous + 1 and player.get_held_object() == null and foreign.carrier == null, "A real transition leaves the previous room's companion behind")
		_check(foreign.global_position.distance_to(foreign._spawn_transform.origin) < 15 and not stage._carry_requirement_met(), "The previous carrier resets and cannot satisfy the next room's local delivery")
		_check(await traverse_fourth(previous + 1, true) and player.get_held_object() == stage.rooms.get_child(previous + 1).get_node("Items/JumpCreature"), "The next room's real route starts by reacquiring its own local companion")
		if failed: return
	await _spring_retry(18, "Spring", 205)
	await _red_reacquire()
	if failed: return
	observe_fourth_view = false
	release()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fourth_cleanup()
	print("CORRIDOR_FOURTH_RETRY_TEST_OK checks=", checks)
	quit()


func _check_restored(section: int) -> void:
	var room: Node2D = stage.rooms.get_child(section)
	_check(stage.room_index == section and player.position.distance_to(Vector2(room.position.x + 110, room.entrance_top - 26)) < 2 and player.is_on_floor(), "Retry restores the same real checkpoint and safe floor")
	_check(player.gravity_direction == 1 and player.is_dash_ready() and player.get_held_object() == null, "Retry restores normal gravity, Dash and a free holding slot")
	for name in (["JumpCreature", "ParachuteCreature"] if section == 23 else ["JumpCreature"]):
		var creature: Grabbable = room.get_node("Items/" + name)
		_check(creature.carrier == null and creature.global_position.distance_to(creature._spawn_transform.origin) < 15, "Retry restores each local carryable to its real spawn")
	_check(room.get_node("Items/JumpCreature").extra_jump_count() == 1, "Retry restores the companion's actual extra jump")


func _actual_left_spike() -> void:
	observe_fourth_view = false
	var before := deaths
	var hits: Array[bool] = []
	stage.rooms.get_child(stage.room_index).get_node("Hazards/LeftEdgeSpikes").player_hit.connect(func(): hits.append(true), CONNECT_ONE_SHOT)
	_drive(Vector2.LEFT)
	await _pulse("dash")
	for frame in 60:
		if deaths != before: break
		await step()
	release()
	await step(6)
	_check(deaths == before + 1 and hits.size() == 1, "The retry follows actual swept spike contact rather than forced respawn")


func _spring_retry(section: int, spring_name: String, launch_x: float) -> void:
	observe_fourth_view = false
	await _new_stage()
	await _enter(section)
	if section == 23:
		_check(await traverse_fourth(section, true) and await fourth_choose_red(), "The Spring retry first selects the actual red alternative")
	var spring: Area2D = stage.rooms.get_child(section).get_node(spring_name)
	var launches: Array[bool] = []
	spring.launched.connect(func(_body): launches.append(true))
	for attempt in 2:
		for frame in 240:
			more_drive(launch_x - _more_x())
			await step()
			if launches.size() == attempt + 1: break
		_check(launches.size() == attempt + 1 and player.velocity.y < -800, "Real contact activates the Spring after retry, without a custom Spring reset")
		if failed: return
		await _pulse("reset")
		release()
		await step(6)
		_check_restored(section)
		if section == 23:
			_check(await traverse_fourth(section, true) and await fourth_choose_red(), "After R both real objects can be selected again")


func _red_reacquire() -> void:
	await _spring_retry(23, "ChoiceSpring", 1100)
	if failed: return
	var before := deaths
	var hits: Array[bool] = []
	stage.rooms.get_child(23).get_node("Hazards/LeftEdgeSpikes").player_hit.connect(func(): hits.append(true), CONNECT_ONE_SHOT)
	for frame in 600:
		more_drive(-1000)
		await step()
		if deaths != before: break
	release()
	await step(6)
	_check(deaths == before + 1 and hits.size() == 1, "A red carrier really falls into the native left spikes")
	_check_restored(23)
	observe_fourth_view = true
	_check(await traverse_fourth(23, true) and await fourth_right_finish(), "After real red death, reacquisition still completes the actual alternative Goal")
