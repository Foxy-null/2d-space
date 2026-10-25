extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Isolate exit behavior from the already-tested bumper traversal.
	var first := await _room(0)
	var final_index: int = first.rooms.get_child_count() - 1
	for index in final_index:
		for airborne in [false, true]:
			var stage := await _room(index)
			var player: PlayerController = stage.player
			var exit: Node2D = stage.rooms.get_child(index).get_node("Exit")
			var collider: CollisionShape2D = exit.get_node("Collision")
			var top := collider.to_global(collider.shape.get_rect().position).y
			var left: bool = stage.rooms.get_child(index).get_meta("exit_left", false)
			var direction := "move_left" if left else "move_right"
			player.global_position = Vector2(exit.global_position.x + ((-55 if left else 55) if airborne else 0), exit.global_position.y - 100 if airborne else top - 30)
			player.velocity = Vector2.ZERO
			player._contacts_valid = false
			if airborne:
				Input.action_press(direction)
				Input.action_press("dash")
			await _step(8)
			Input.action_release(direction)
			Input.action_release("dash")
			_check(stage.room_index == index + 1, "Room %d advances after one %s" % [index + 1, "airborne exit" if airborne else "exit landing"])
			await _step(25)
			_check(stage.room_index == index + 1 and not stage.transitioning, "The same clear advances exactly one room")
			_check(stage.next_bumper == 0 and player.position.distance_to(stage.rooms.get_child(index + 1).get_node("Spawn").global_position) < 8, "The next room starts at its own checkpoint")
	var entrance := await _room(0)
	await _step(8)
	_check(entrance.room_index == 0, "The entrance platform cannot clear a room")
	var final_room := await _room(final_index)
	final_room.player.position = Vector2(-15, 900) + Vector2(final_index * 1280, 0)
	final_room.player.velocity = Vector2(-900, 0)
	await _step(8)
	_check(final_room.room_index == final_index and not final_room.completed, "The final room still requires the actual arrival switch")
	var arrival := await _room(final_index)
	arrival.player.position = arrival.goal.global_position - Vector2(0, 100)
	await _step(80)
	_check(arrival.completed and arrival.next_bumper == 0, "The final switch accepts physical arrival without history")
	print("STAGE_5_EXIT_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _room(index: int) -> Node2D:
	change_scene_to_file("res://scenes/stage_5.tscn")
	await _step(3)
	var stage: Node2D = current_scene
	stage.room_index = index
	stage.call("_set_checkpoint")
	stage.player.respawn()
	await _step(3)
	return stage


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("STAGE_5_EXIT: " + message)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
