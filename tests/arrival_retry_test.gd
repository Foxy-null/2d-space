extends SceneTree

var failed := false
var checks := 0
var stage: Node
var player: PlayerController
var scene_name := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for scene in ["stage_2", "stage_3", "stage_4", "stage_5"]:
		scene_name = scene
		stage = load("res://scenes/%s.tscn" % scene).instantiate()
		root.add_child(stage)
		player = stage.player
		if scene_name == "stage_4":
			# Isolate arrival retries from the carry course's moving hazards.
			for room in stage.rooms.get_children():
				for spike in room.get_node("Hazards").get_children():
					spike.set_physics_process(false)
		await _step(4)
		var goal: ArrivalSwitch
		match scene:
			"stage_2": goal = stage.get_node("Goal")
			"stage_3": goal = stage.get_node("Rooms/Room1/Goal")
			"stage_4":
				stage.room_index = stage.rooms.get_child_count() - 1
				stage._set_checkpoint()
				goal = stage.rooms.get_child(stage.room_index).get_node("Goal")
			"stage_5":
				stage.room_index = stage.rooms.get_child_count() - 1
				stage._set_checkpoint()
				goal = stage.goal
		player.respawn()
		await _step(4)
		var checkpoint: Vector2 = player._spawn_position
		var activations := [0]
		goal.activated.connect(func(): activations[0] += 1)
		await _prepare_goal()
		await _land_on(goal)
		await _step(3)
		_check(goal.pressing and not goal.is_pressed() and goal.cap.position.y > 0 and goal.cap.position.y < ArrivalSwitch.TRAVEL, "A real landing starts an unfinished press")
		await _reset_input()
		await _step(25)
		_check(not goal.pressing and not goal.is_pressed() and goal.cap.position.y == 0, "R cancels and raises the unfinished cap")
		_check(not _done() and activations[0] == 0, "The empty arrival never completes after retry")
		_check(player.global_position.distance_to(checkpoint) < 4, "R leaves the player at the entrance")
		await _prepare_goal()
		await _land_on(goal)
		await _step(30)
		_check(goal.is_pressed() and _done() and activations[0] == 1, "Returning to the arrival completes a new physical press")
		await _reset_input()
		await _step(25)
		_check(goal.is_pressed() and goal.cap.position.y == ArrivalSwitch.TRAVEL and _done() and activations[0] == 1, "R preserves a completed arrival without replaying activation")
		for sound in stage.find_children("*", "AudioStreamPlayer", true, false):
			sound.stop()
			sound.stream = null
		stage.queue_free()
		await _step(3)
	print("ARRIVAL_RETRY_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _prepare_goal() -> void:
	if scene_name == "stage_4":
		var creature: Grabbable = stage.rooms.get_child(stage.room_index).get_node("Items/JumpCreature")
		player.global_position = creature.global_position
		Input.action_press("wall_grab")
		_check(player.try_begin_grab(creature), "The delivery fixture carries the actual companion")
	await _step(2)


func _land_on(goal: ArrivalSwitch) -> void:
	var collider: CollisionShape2D = goal.get_node("Cap/Collision")
	var top := collider.to_global(collider.shape.get_rect().position).y
	player.global_position = Vector2(goal.global_position.x, top - 80)
	player.velocity = Vector2.ZERO
	player.set("_contacts_valid", false)
	for frame in 60:
		if goal.pressing or goal.is_pressed():
			return
		await _step()
	_check(false, "Landing on the real cap must begin pressing")


func _reset_input() -> void:
	Input.action_press("reset")
	await _step()
	Input.action_release("reset")
	Input.action_release("wall_grab")


func _done() -> bool:
	if scene_name == "stage_3":
		return stage.cleared.has(0)
	return stage.completed


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("ARRIVAL_RETRY: %s (%s)" % [message, scene_name])
