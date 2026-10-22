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
	var rows := tutorial.get_node("HUD/Margin/Panel/Rows")
	var pause := tutorial.get_node("PauseMenu")
	_check(not tutorial.hints_visible and pause.menu.get_node("Hints").visible, "Detailed hints start off and remain available from pause")
	for index in tutorial.rooms.get_child_count():
		tutorial._set_room(index, false)
		tutorial.player.respawn()
		await _step(3)
		var room: Node = tutorial.rooms.get_child(index)
		var bubble_bounds := Rect2(room.get_node("Goal").position + ArrivalSwitch.BUBBLE + Vector2(-150, -84), Vector2(300, 144))
		var guide_count := 0
		for guide in room.get_children():
			if guide is Label and guide.visible:
				guide_count += 1
				var bounds: Rect2 = guide.get_rect()
				_check(bounds.position.x >= 0 and bounds.end.x <= 1280 and bounds.end.y <= 720, "Local guide fits room %d: %s" % [index + 1, guide.name])
				_check(not bounds.intersects(bubble_bounds), "Goal mission does not cover a local guide in room %d: %s" % [index + 1, guide.name])
		_check(guide_count >= 3 and room.get_node("Goal/Bubble").visible, "Local guides and the goal mission stay visible in room %d" % (index + 1))
		for name in ["Controls", "WallControls", "Objective", "Gravity", "Carry", "StaminaLabel"]:
			_check(not rows.get_node(name).visible, "Default HUD avoids duplicate details: " + name)
		_check(rows.get_node("Resources").visible == (index >= 2), "Dash lessons retain a compact non-color readiness cue")
		_check(rows.get_node("Stamina").visible == (index in [1, 8]), "Wall lessons retain their stamina meter")
		if OS.get_cmdline_user_args().has("--screenshots"):
			await _capture("room_%02d" % (index + 1))
		pause.open()
		pause.toggle_hints()
		_check(paused and tutorial.hints_visible and rows.get_node("Controls").text == tutorial.CONTROLS[index], "Pause enables the original detailed controls without unpausing")
		_check(rows.get_node("Controls").visible and rows.get_node("Objective").visible, "Detailed controls and mission progress are visible on demand")
		pause.retry()
		await _step(3)
		_check(not paused and tutorial.hints_visible, "Retry preserves the hint choice")
		if index == 0 and OS.get_cmdline_user_args().has("--screenshots"):
			await _capture("room_01_details")
		tutorial.set_hints_visible(false)
	tutorial.hud._on_resources_changed(3.0, 3.0, false, false)
	_check(rows.get_node("Resources").text == "ダッシュ ○", "Spent dash has an empty marker without depending on outfit color")
	tutorial.hud._on_resources_changed(3.0, 3.0, true, false)
	_check(rows.get_node("Resources").text == "ダッシュ ●", "Ready dash has a filled marker")
	# Changing the display must preserve the room, checkpoint, and mission progress.
	tutorial._set_room(6, true)
	tutorial.player.respawn()
	tutorial._mark("floor_spring")
	var checkpoint: Vector2 = tutorial.player._spawn_position
	tutorial.set_hints_visible(true)
	_check(tutorial.room_index == 6 and tutorial.player._spawn_position == checkpoint and tutorial.seen.has("floor_spring"), "Toggling details preserves the right entrance and mission progress")
	_check(tutorial.get_node("Rooms/Room7/Goal/Bubble/Objective").text == tutorial.STEP_LABELS["wall_spring"], "The next required action remains available at the goal")
	tutorial._set_room(7, false)
	_check(tutorial.hints_visible and rows.get_node("Controls").visible, "The next room retains the detail preference")
	print("TUTORIAL_GUIDANCE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _capture(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial-guidance")
	await _step(2)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/tutorial-guidance/%s.png" % name)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_GUIDANCE: " + message)
