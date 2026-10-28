extends "res://tests/pause_menu_test.gd"

var stage: Node2D
var player: PlayerController
var labels: Array[Label] = []
var winds: Dictionary = {}


func _run() -> void:
	var progress: Node = root.get_node("CollectionProgress")
	progress.save_path = "user://canyon_hint_labels_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	await _new_stage()
	_check(not stage.hints_visible, "A fresh stage starts with optional hints disabled")
	_verify_state(false)
	if failed: return
	for index in stage.rooms.get_child_count():
		await _enter(index)
		for enabled in [false, true, false]:
			stage.set_hints_visible(enabled)
			await _step()
			_verify_state(enabled)
			if failed: return
	var wind: Area2D = winds.keys()[0]
	var before: float = wind._time
	await _step(3)
	_check(wind._time != before, "The visible wind fan and flowing arrows keep animating with hints OFF")
	await _pause_controls()
	# Controller-call fixtures cover changing hints during the lock, not the main route.
	for enabled in [true, false]:
		await _enter(0)
		stage.set_hints_visible(not enabled)
		stage._transition_to_next()
		_check(stage.room_index == 1 and stage.transitioning and not player.controls_enabled, "The fixture enters the actual room-transfer input lock")
		await _key(KEY_ESCAPE)
		await _click(stage.get_node("PauseMenu").menu.get_node("Hints"))
		_verify_state(enabled)
		var camera_position: Vector2 = stage.camera.position
		await _step(20)
		_check(paused and stage.transitioning and stage.camera.position == camera_position, "Changing hints during a paused transfer preserves the frozen transition")
		await _click(stage.get_node("PauseMenu").menu.get_node("Resume"))
		await _step(25)
		_check(not paused and not stage.transitioning and player.controls_enabled and stage.room_index == 1, "Resume completes the same actual transfer")
		_verify_state(enabled)
		if failed: return
	await _key(KEY_ESCAPE)
	var pause_menu: CanvasLayer = stage.get_node("PauseMenu")
	await _click(pause_menu.menu.get_node("Return"))
	await _click(pause_menu.confirmation.get_node("Return"))
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "The actual pause menu returns to stage selection")
	await _click(current_scene.get_node("Margin/Content/Stages/Stage5"))
	await _step(4)
	stage = current_scene
	player = stage.player
	_collect_targets()
	_check(stage.room_index == 0 and not stage.hints_visible and not paused, "Actual re-entry starts at the first room with hints OFF")
	_verify_state(false)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	labels.clear()
	winds.clear()
	current_scene.queue_free()
	await _step(4)
	print("CANYON_HINT_LABELS_TEST_OK rooms=34 labels=30 checks=", checks)
	quit()


func _new_stage() -> void:
	change_scene_to_file("res://scenes/stage_5.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	_collect_targets()


func _collect_targets() -> void:
	labels.clear()
	winds.clear()
	var entrances := 0
	var directions := 0
	_check(stage.rooms.get_child_count() == 34, "The regression covers all thirty-four native rooms")
	for room in stage.rooms.get_children():
		var entrance: Label = room.get_node_or_null("EntranceLabel")
		if entrance != null:
			labels.append(entrance)
			entrances += 1
		for wind: Area2D in room.get_node("Winds").get_children():
			winds[wind] = _wind_state(wind)
			var direction: Label = wind.get_node_or_null("Direction")
			if direction != null:
				labels.append(direction)
				directions += 1
	_check(entrances == 12 and directions == 18 and labels.size() == 30, "Twelve entrance labels and eighteen wind labels remain present as optional hints")


func _enter(index: int) -> void:
	stage.room_index = index
	stage._set_checkpoint()
	player.respawn()
	await _step(4)


func _verify_state(enabled: bool) -> void:
	_check(stage.hints_visible == enabled and stage.get_node("HUD/Hint").visible == enabled, "The stage and HUD share the selected hint state")
	for label in labels:
		_check(label.is_visible_in_tree() == enabled, "Only enabled hints show the optional label: " + str(stage.get_path_to(label)))
		if failed: return
	for room in stage.rooms.get_children():
		_check(room.get_node("Route").visible == enabled and room.get_node("ExitLabel").visible == enabled, "Existing optional route lines and exit labels retain their hint behavior")
	for bumper in stage._bumpers().get_children():
		_check(bumper.get_node("Number").visible == enabled, "The current room's existing bumper numbers retain their hint behavior")
	_check(stage.target_marker.visible == enabled, "The existing target marker follows the same hint state")
	for wind: Area2D in winds:
		_check(wind.is_visible_in_tree() and wind.is_processing() and _wind_state(wind) == winds[wind], "Hints preserve the real wind, collision, direction, outline and procedural fan/arrows: " + str(stage.get_path_to(wind)))


func _wind_state(wind: Area2D) -> Array:
	var collision: CollisionShape2D = wind.get_node("CollisionShape2D")
	var outline: CanvasItem = wind.get_node_or_null("Outline")
	return [wind.wind_direction, wind.wind_acceleration, wind.max_wind_speed, wind.area_size, collision.shape, collision.shape.size, collision.disabled, wind.collision_layer, wind.collision_mask, wind.monitoring, wind.monitorable, outline.visible if outline != null else true]


func _pause_controls() -> void:
	await _enter(0)
	stage.set_hints_visible(false)
	await _key(KEY_ESCAPE)
	var pause_menu: CanvasLayer = stage.get_node("PauseMenu")
	await _click(pause_menu.menu.get_node("Hints"))
	_check(paused, "The actual Hints button changes optional labels while paused")
	_verify_state(true)
	await _click(pause_menu.menu.get_node("Retry"))
	_check(not paused and player.position.distance_to(stage.rooms.get_child(0).get_node("Spawn").global_position) < 5, "The actual Retry button restores the native checkpoint")
	_verify_state(true)
	await _key(KEY_ESCAPE)
	await _click(pause_menu.menu.get_node("Hints"))
	await _click(pause_menu.menu.get_node("Resume"))
	_check(not paused, "The actual Resume button returns to gameplay")
	_verify_state(false)


func _check(value: bool, message: String) -> void:
	super._check(value, message)
	if not value: quit(1)
