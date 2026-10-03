extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	await _step(5)
	# Every room, including the four elevated goals, has a physical locked lid.
	for index in 17:
		await _enter(index)
		var goal := _goal()
		player.global_position = goal.global_position + Vector2(0, -120)
		player.velocity = Vector2.ZERO
		player.set("_contacts_valid", false)
		await _step(30)
		_check(goal.locked and not goal.is_pressed(), "Locked case cannot activate in room %d" % (index + 1))
		_check(player.is_on_floor() and absf(player.global_position.y - goal.global_position.y + 104) < 1, "Case supports the player in room %d" % (index + 1))
		_check(not _room().get_node("ExitBarrier/Collision").disabled, "Locked exit remains solid")
	await _enter(6)
	var goal := _goal()
	var events := [0, 0]
	goal.unlocked.connect(func(): events[0] += 1)
	goal.activated.connect(func(): events[1] += 1)
	tutorial.call("_mark", "floor_spring")
	_check(goal.get_node("Bubble/Progress").text == "のこり 2/3", "Fraction shows remaining rather than completed steps")
	_check(goal.get_node("Bubble/Objective").text == tutorial.STEP_LABELS["wall_spring"], "Bubble shows the next incomplete objective")
	player.global_position = goal.global_position + Vector2(0, -120)
	player.velocity = Vector2.ZERO
	player.set("_contacts_valid", false)
	await _step(30)
	var case_height := player.global_position.y
	tutorial.call("_mark", "wall_spring")
	tutorial.call("_mark", "spring_dash")
	_check(not goal.locked and events == [1, 0], "Completing all missions unlocks exactly once")
	_check(goal.get_node("UnlockSound").playing, "Unlock starts the audible reward")
	_check(not tutorial.cleared.has(6), "Unlocking the case alone cannot open the exit")
	await _step(2)
	_check(not tutorial.cleared.has(6), "Exit stays locked before the deep press finishes")
	await _step(40)
	_check(goal.is_pressed() and tutorial.cleared.has(6) and events == [1, 1], "Player waiting on the case falls onto and activates the switch")
	_check(absf(goal.cap.position.y - 44) < 0.1 and absf(player.global_position.y - case_height - 66) < 1, "Player follows the full deep press without sinking into the floor")
	_check(player.is_on_floor() and _room().get_node("ExitBarrier/Collision").disabled, "Pressed platform supports player and opens exit")
	for i in 3:
		tutorial.call("_update_lesson")
	await _step(5)
	_check(events == [1, 1], "Refreshing progress does not repeat audiovisual feedback")
	player.respawn()
	await _step(5)
	_check(goal.is_pressed() and not goal.locked and goal.cap.position.y == 44 and _room().get_node("ExitBarrier/Collision").disabled, "Retry preserves a pressed switch and open exit")
	# Reset before pressing re-locks; reset during the travel cancels completion.
	await _enter(1)
	goal = _goal()
	_complete_steps()
	await _step(3)
	_check(not goal.locked, "Unpressed switch can be unlocked")
	player.respawn()
	await _step(3)
	_check(goal.locked and goal.cap.position.y == 0 and not goal.is_pressed(), "Retry before pressing restores locked case")
	_complete_steps()
	player.global_position = goal.global_position + Vector2(0, -90)
	player.velocity = Vector2.ZERO
	player.set("_contacts_valid", false)
	for frame in 40:
		if goal.pressing:
			break
		await _step()
	_check(goal.pressing and not goal.is_pressed(), "Deep press has an intermediate physical state")
	await _step(5)
	_check(goal.cap.position.y > 15 and goal.cap.position.y < 30 and not goal.is_pressed(), "At about 0.1 seconds the cap is midway through its travel")
	player.respawn()
	await _step(25)
	_check(goal.locked and not goal.is_pressed() and not tutorial.cleared.has(1), "Retry during a press cancels pending exit unlock")
	# A jump during the descent retains the ordinary jump impulse.
	_complete_steps()
	player.global_position = goal.global_position + Vector2(0, -90)
	player.velocity = Vector2.ZERO
	player.set("_contacts_valid", false)
	for frame in 40:
		if goal.pressing:
			break
		await _step()
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")
	_check(player.velocity.y < -620, "Descending platform does not weaken the player's jump")
	await _step(20)
	_check(goal.is_pressed(), "Once started, the switch finishes even if the player jumps away")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _screenshots()
	print("ARRIVAL_SWITCH_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	for sound in tutorial.find_children("*", "AudioStreamPlayer", true, false):
		sound.stop()
		sound.stream = null
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _enter(index: int) -> void:
	tutorial.call("_set_room", index, false)
	player.respawn()
	await _step(4)


func _complete_steps() -> void:
	for key in tutorial.STEPS[tutorial.room_index]:
		tutorial.call("_mark", key)


func _room() -> Node:
	return tutorial.rooms.get_child(tutorial.room_index)


func _goal() -> ArrivalSwitch:
	return _room().get_node("Goal")


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _screenshots() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/arrival")
	for index in [0, 5, 7, 12, 14, 16]:
		await _enter(index)
		await _capture("room_%d_locked" % (index + 1))
	tutorial.cleared.erase(8)
	await _enter(8)
	# A fresh room is used because a pressed latch deliberately never rises.
	tutorial.call("_mark", "wind_walk")
	await _capture("locked")
	_complete_steps()
	await _step(8)
	await _capture("unlocking")
	await _step(40)
	await _capture("unlocked")
	var goal := _goal()
	player.global_position = goal.global_position + Vector2(0, -110)
	player.velocity = Vector2.ZERO
	player.set("_contacts_valid", false)
	await _step(40)
	await _capture("pressed")
	goal.get_node("UnlockSound").stream.save_to_wav("res://docs/screenshots/arrival/unlock.wav")
	goal.get_node("PressSound").stream.save_to_wav("res://docs/screenshots/arrival/press.wav")


func _capture(name: String) -> void:
	await _step(2)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/arrival/%s.png" % name)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("ARRIVAL_SWITCH: " + message + " (room=%d player=%s cap=%s)" % [tutorial.room_index + 1, player.global_position, _goal().cap.position])
