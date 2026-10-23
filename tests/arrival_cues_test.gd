extends SceneTree

var failed := false
var checks := 0
var tutorial: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	await _step(4)
	# Display fixtures use fixed poses; arrival_switch_test covers the physical press.
	tutorial.set_physics_process(false)
	tutorial.player.set_physics_process(false)
	for index in 17:
		tutorial.completed = false
		tutorial._set_room(index, false)
		tutorial.seen.clear()
		tutorial._update_lesson()
		tutorial.camera.position = tutorial._camera_position()
		var room: Node2D = tutorial.rooms.get_child(index)
		var goal: ArrivalSwitch = room.get_node("Goal")
		goal.set_physics_process(false)
		goal.cap.sync_to_physics = false
		var total: int = tutorial.STEPS[index].size()
		for state in (["ready", "cleared"] if total == 0 else ["locked", "ready", "cleared"]):
			if state == "ready":
				for key in tutorial.STEPS[index]:
					tutorial._mark(key)
				await _step(32)
			elif state == "cleared":
				tutorial._on_arrival(index)
				await _step(1)
			tutorial.player.position = goal.global_position + Vector2(0, -147.741 if state == "locked" else -115.532 + goal.cap.position.y)
			tutorial.player.velocity = Vector2.ZERO
			var expected := "のこり %d/%d" % [total, total] if state == "locked" else ("乗ろう ↓" if state == "ready" else "完了 ✓")
			var objective: String = goal.get_node("Bubble/Objective").text
			for details in [false, true]:
				tutorial.set_hints_visible(details)
				await _step(2)
				if total == 0:
					_check(not goal.locked and not goal.get_node("Bubble").visible, "Terrain-led arrival stays ready without a mission bubble in either hint mode")
					_check(goal.is_pressed() == (state == "cleared") and goal.cap.position.y == (32 if state == "cleared" else 0), "Terrain-led ready and cleared states preserve their physical cap")
					_check(room.get_node("ExitBarrier/Collision").disabled == (state == "cleared"), "Terrain-led exit opens only after arrival")
					_check(tutorial.get_node("HUD/Margin/Panel/Rows/Objective").visible == details, "Terrain-led optional guidance follows the hint preference")
					continue
				var bounds := goal.get_hint_rect()
				var room_bounds := Rect2(goal.position + goal.get_node("Bubble").position + bounds.position, bounds.size)
				_check(Rect2(0, 0, 1280, 720).encloses(room_bounds), "Cue stays in the room")
				_check(bounds.size == (Vector2(300, 136) if details else Vector2(160, 64)), "Only optional details use the larger frame")
				_check(goal.get_node("Bubble/Progress").visible and goal.get_node("Bubble/Progress").text == expected, "Each state retains a short non-color cue")
				_check(goal.get_node("Bubble/Objective").visible == details and goal.get_node("Bubble/Objective").text == objective, "Existing hints reveal the preserved objective")
				var progress: Label = goal.get_node("Bubble/Progress")
				_check(bounds.encloses(progress.get_rect()) and progress.size.x >= progress.get_minimum_size().x, "The complete status line fits the frame")
				_check(not details or bounds.encloses(goal.get_node("Bubble/Objective").get_rect()), "The full optional objective fits the frame")
				var body: CollisionShape2D = tutorial.player.get_node("CollisionShape2D")
				var player_bounds := Rect2(tutorial.player.position - room.position + body.position + body.shape.get_rect().position, body.shape.get_rect().size)
				_check(not room_bounds.intersects(player_bounds), "Cue leaves the player visible on the case or cap")
				_check(room_bounds.end.y < goal.position.y - 121.7, "Cue leaves the case, cap, and landing surface visible")
				_check(goal.locked == (state == "locked") and goal.is_pressed() == (state == "cleared") and goal.cap.position.y == (32 if state == "cleared" else 0), "Hint toggles preserve the lock, pressed state, and cap position")
				if OS.get_cmdline_user_args().has("--screenshots"):
					await _capture("room_%02d_%s_%s" % [index + 1, state, "details" if details else "compact"])
	# The optional room is also reachable while the existing completion card is open.
	tutorial._set_room(16, false)
	tutorial.completed = true
	tutorial.set_hints_visible(false)
	var optional_goal: ArrivalSwitch = tutorial.rooms.get_child(16).get_node("Goal")
	var optional_bounds := Rect2(optional_goal.position + optional_goal.get_node("Bubble").position + optional_goal.get_hint_rect().position, optional_goal.get_hint_rect().size)
	var completion: Control = tutorial.get_node("HUD/Completion").card
	_check(completion.visible and not optional_bounds.intersects(completion.get_rect()), "Compact cue remains visible beside the existing completion card")
	tutorial.set_hints_visible(true)
	_check(tutorial.get_node("HUD/Margin/Panel/Rows/Objective").visible, "Detailed objective remains available after main completion")
	print("ARRIVAL_CUES_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	for sound in tutorial.find_children("*", "AudioStreamPlayer", true, false):
		sound.stop()
		sound.stream = null
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _capture(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/arrival-cues-screenshots")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/arrival-cues-screenshots/%s.png" % name)


func _step(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("ARRIVAL_CUES: %s (room %d)" % [message, tutorial.room_index + 1])
