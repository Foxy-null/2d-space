extends SceneTree

var checks := 0
var boundaries := 0
var failed := false
var stage: Node2D
var player: PlayerController


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var progress: Node = root.get_node("CollectionProgress")
	progress.save_path = "user://room_transition_camera_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	for number in [4, 5]:
		await _open_stage(number)
		var count: int = stage.rooms.get_child_count() - 1
		for source in count:
			await _transition(number, source)
			if failed: return
		print("ROOM_TRANSITION_CAMERA stage=", number, " boundaries=", count)
	current_scene.queue_free()
	await _step(4)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("ROOM_TRANSITION_CAMERA_TEST_OK boundaries=", boundaries, " checks=", checks)
	quit()


func _open_stage(number: int) -> void:
	change_scene_to_file("res://scenes/stage_%d.tscn" % number)
	await _step(4)
	stage = current_scene
	player = stage.player
	stage.set_hints_visible(OS.get_cmdline_user_args().has("--hints"))


func _transition(number: int, source: int) -> void:
	_release_inputs()
	stage.room_index = source
	stage._set_checkpoint()
	player.respawn()
	await _step(2)
	# This controller fixture starts at the native exit; it does not prove the main route.
	var exit: StaticBody2D = stage.rooms.get_child(source).get_node("Exit")
	var collision: CollisionShape2D = exit.find_children("*", "CollisionShape2D", false, false)[0]
	player.global_position = Vector2(exit.global_position.x, collision.to_global(collision.shape.get_rect().position).y - 26)
	stage.camera.position = stage._camera_position()
	var respawns := [0]
	var count_respawn := func(): respawns[0] += 1
	player.respawned.connect(count_respawn)
	stage._transition_to_next()
	var room: Node2D = stage.rooms.get_child(source + 1)
	var checkpoint: Vector2 = Vector2(room.position.x + room.entrance_x, room.entrance_top - 26) if number == 4 else room.get_node("Spawn").global_position
	var camera_position: Vector2 = stage._camera_position()
	_check(stage.room_index == source + 1 and respawns[0] == 1 and player.position == checkpoint, "The transition synchronously updates the room and resets to its real checkpoint")
	_check(stage.transitioning and not player.controls_enabled, "The room changes before its input lock finishes")
	_check(stage.camera.position == camera_position, "The camera synchronously reaches the new checkpoint: stage%d room%d camera=%s target=%s" % [number, source + 2, stage.camera.position, camera_position])
	_check(stage.get_node("HUD/Info/Rows/Title").text.contains("%02d / %02d" % [source + 2, stage.rooms.get_child_count()]), "The HUD synchronously names the destination room")
	if failed: return
	var companions: Array[Grabbable] = []
	for item in get_nodes_in_group("grabbable"):
		if room.is_ancestor_of(item) and item.global_position.distance_to(checkpoint) < 200:
			companions.append(item)
	if number == 4:
		_check(companions.has(room.get_node("Items/JumpCreature")), "The actual entrance companion is included in the visibility check")
	Input.action_press("move_right")
	Input.action_press("jump")
	var locked_frames := 0
	while stage.transitioning and locked_frames < 30:
		_check(not player.controls_enabled and player.position == checkpoint and stage.camera.position == camera_position and respawns[0] == 1, "The checkpoint and camera remain fixed throughout the input lock")
		await _step()
		locked_frames += 1
		if locked_frames == 8: _release_inputs()
		_check_visible(player)
		for companion in companions: _check_visible(companion)
		if failed: return
	_release_inputs()
	_check(locked_frames >= 16 and locked_frames <= 18, "At fixed 60 fps, the existing 0.28-second input lock lasts approximately seventeen frames")
	_check(not stage.transitioning and player.controls_enabled and stage.room_index == source + 1 and respawns[0] == 1, "The next room becomes controllable without another reset")
	player.respawned.disconnect(count_respawn)
	boundaries += 1


func _check_visible(body: Node2D) -> void:
	var sprite: AnimatedSprite2D = body.get_node("Visuals/Body")
	var size := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size()
	var bounds: Rect2 = sprite.get_global_transform_with_canvas() * Rect2(-size * 0.5, size)
	_check(root.get_visible_rect().encloses(bounds), "The complete entrance artwork stays in the viewport: room%d %s %s" % [stage.room_index + 1, body.name, bounds])
	for path in ["Info", "PauseButton", "Hint"]:
		var panel: Control = stage.get_node("HUD/" + path)
		_check(not panel.is_visible_in_tree() or not panel.get_global_rect().intersects(bounds), "The entrance artwork stays outside visible HUD: room%d %s %s artwork=%s panel=%s" % [stage.room_index + 1, body.name, path, bounds, panel.get_global_rect()])


func _release_inputs() -> void:
	for action in ["move_left", "move_right", "jump", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)
		quit(1)
