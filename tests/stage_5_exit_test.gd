extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Isolate exit behavior from the already-tested bumper traversal.
	for index in 11:
		for airborne in [false, true]:
			var stage := await _room(index, true)
			var player: PlayerController = stage.player
			player.position = Vector2(index * 1280 + (1265 if airborne else 1210), 520 if airborne else 570)
			player.velocity = Vector2.ZERO
			if airborne:
				Input.action_press("move_right")
				Input.action_press("dash")
			await _step(8)
			Input.action_release("move_right")
			Input.action_release("dash")
			_check(stage.room_index == index + 1, "Room %d advances after one %s" % [index + 1, "airborne exit" if airborne else "exit landing"])
			await _step(25)
			_check(stage.room_index == index + 1 and not stage.transitioning, "The same clear advances exactly one room")
			_check(stage.next_bumper == 0 and player.position.x < (index + 1) * 1280 + 110, "The next room starts at its own checkpoint")
	# History is optional in the first room; other rooms still require their route.
	var first := await _room(0, false)
	first.player.position = Vector2(1210, 570)
	await _step(8)
	_check(first.room_index == 1, "The first exit accepts a landing without reflection history")
	var locked := await _room(1, false)
	locked.player.position = Vector2(1280 + 1210, 570)
	await _step(8)
	_check(locked.room_index == 1, "Other rooms retain their sequence lock until their geometry is improved")
	var entrance := await _room(0, true)
	await _step(8)
	_check(entrance.room_index == 0, "The entrance platform cannot clear a room")
	var final_room := await _room(11, true)
	final_room.player.position = Vector2(1295, 520) + Vector2(11 * 1280, 0)
	final_room.player.velocity = Vector2(900, 0)
	await _step(8)
	_check(final_room.room_index == 11 and not final_room.completed, "The final room still requires the actual arrival switch")
	print("STAGE_5_EXIT_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _room(index: int, unlocked: bool) -> Node2D:
	change_scene_to_file("res://scenes/stage_5.tscn")
	await _step(3)
	var stage: Node2D = current_scene
	stage.room_index = index
	stage.call("_set_checkpoint")
	stage.player.respawn()
	await _step(3)
	if unlocked:
		stage.next_bumper = stage.call("_bumpers").get_child_count()
		stage.call("_update_route")
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
