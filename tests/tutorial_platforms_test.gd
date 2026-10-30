extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/tutorial.tscn")
	await _step(4)
	var stage := current_scene
	var player: PlayerController = stage.player
	var total := 0
	for room_index in 3:
		stage._enter_room(room_index, false)
		await _step(3)
		var platforms: Array[Rect2] = TutorialLandscape.one_way_platforms(room_index)
		var bodies: Array = stage.rooms.get_child(room_index).get_children().filter(func(node): return str(node.name).begins_with("WoodPlatform"))
		_check(bodies.size() == platforms.size(), "Every drawn plank has exactly one physical platform")
		for index in platforms.size():
			var plank := platforms[index]
			var collision: CollisionShape2D = bodies[index].get_child(0)
			_check(collision.one_way_collision and collision.shape.size == plank.size, "The actual plank collider is one-way and matches the thin artwork")
			player.respawn()
			player.position = Vector2(TutorialLandscape.ORIGINS[room_index] + plank.get_center().x, plank.end.y + 27)
			player.launch_from_spring(Vector2(0, -650))
			var rose_above := false
			var hit_underside := false
			for frame in 90:
				await _step()
				hit_underside = hit_underside or player.is_on_ceiling()
				rose_above = rose_above or player.position.y + 26 < plank.position.y - 1
				if rose_above and player.is_on_floor():
					break
			_check(rose_above and not hit_underside, "The real player passes upward through the plank without a head collision")
			_check(player.is_on_floor() and absf(player.position.y + 26 - plank.position.y) < 1, "The same plank catches the player descending from above")
			await _step(45)
			_check(player.is_on_floor() and absf(player.position.y + 26 - plank.position.y) < 1, "Standing on the plank never drops through it")
			total += 1
	_check(total == 3, "The three thin platforms from the layout are present")
	print("TUTORIAL_PLATFORMS_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_PLATFORMS: " + message)
