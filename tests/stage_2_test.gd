extends SceneTree

var stage: Node2D
var player: PlayerController
var failed := false
var checks := 0
var captures := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://stage_2_test_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	progress._cleared.clear()
	change_scene_to_file("res://scenes/stage_2.tscn")
	await scene_changed
	if current_scene.has_node("StageIntro"):
		await current_scene.get_node("StageIntro").tree_exited
	stage = current_scene
	player = stage.player
	await _step(6)
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		captures = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(captures)
		await _capture_rooms()
	_check(stage.rooms.get_child_count() == 10 and player.is_on_floor(), "Ten rooms start on a safe floor")
	_check(player.wall_jump_enabled and player.dash_enabled, "Wall kicks and dashes are available from the start")
	_check(root.get_node("CollectionProgress").TOTALS.tower == 4, "The tower has four optional scrolls")
	for index in 10:
		stage._enter_room(index, TowerLandscape.start() if index == 0 else stage.connections[index - 1][5])
		var dimensions := TowerLandscape.size(index)
		_check(dimensions.x >= 1279.99 and dimensions.y >= 719.99, "Every room spans at least one gameplay viewport")
		_check(stage.camera.zoom == Vector2.ONE and player.scale == Vector2.ONE, "Gameplay keeps the normal camera and character scale")
		for corner in [Vector2.ZERO, dimensions * 0.5, dimensions]:
			player.position = TowerLandscape.origin(index) + corner
			stage._update_camera()
			var view := Rect2(stage.camera.position - Vector2(640, 360), Vector2(1280, 720))
			_check(Rect2(TowerLandscape.origin(index), dimensions).grow(0.1).encloses(view), "Camera stays inside the room at both edges and its center")
	for link in stage.connections:
		for side in [0, 3]:
			var destination: int = 3 - side
			stage._enter_room(link[side], link[side + 2])
			await _step(8)
			_check(player.is_on_floor() and (player.global_position - player._spawn_position).length() < 6, "Every entrance and return position is a stable floor: %s/%d" % [link[side], side])
			player.global_position = TowerLandscape.origin(link[side]) + link[side + 1].get_center()
			player.velocity = Vector2.ZERO
			await _step(2)
			_check(stage.room_index == link[destination], "The real exit volume connects both ways")
			await _step(8)
			_check(stage.room_index == link[destination] and player.is_on_floor(), "The destination cannot immediately trigger a return loop")
			var checkpoint := player._spawn_position
			player.global_position += Vector2(30, -80)
			player.respawn()
			await _step(4)
			_check(player.global_position.distance_to(checkpoint) < 6, "Retry returns to the most recently entered side")
	for index in [7, 8, 9]:
		stage._enter_room(index, stage.connections[index - 1][5])
		_check(root.get_node("GameAudio").music.stream == root.get_node("GameAudio").TRACKS.a[1], "All three detours use quiet A")
	var playback = root.get_node("GameAudio").music.get_stream_playback()
	root.get_node("GameAudio").set_quiet(true)
	_check(root.get_node("GameAudio").music.get_stream_playback() == playback, "Repeated quiet updates do not restart the music")
	stage._enter_room(2, TowerLandscape.foothold(2, 83, 127))
	_check(root.get_node("GameAudio").music.stream == root.get_node("GameAudio").TRACKS.a[0], "Returning to the main course restores normal A")
	await _hazards()
	await _planks_and_scroll()
	await _cinematic()
	print("STAGE_2_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	for sound in root.get_node("GameAudio").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.stream = null
	# Let the dummy audio driver release stopped playbacks before quitting.
	OS.delay_msec(120)
	current_scene = null
	stage.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _hazards() -> void:
	stage._enter_room(0, TowerLandscape.start())
	player.global_position = Vector2(33, 84) * TowerLandscape.room_scale(0)
	player.velocity = Vector2.ZERO
	player._contacts_valid = false
	await _step(65)
	_check(player.position.distance_to(player._spawn_position) < 6, "Real spike contact returns the player to the entrance")
	player.global_position = Vector2(125, 140) * TowerLandscape.room_scale(0)
	await _step(65)
	_check(player.position.distance_to(player._spawn_position) < 6, "Falling outside the course returns to the same entrance")


func _planks_and_scroll() -> void:
	stage._enter_room(3, TowerLandscape.foothold(3, 15, 222.6))
	var plank: CrumblingPlatform = stage.rooms.get_child(3).get_children().filter(func(node): return node is CrumblingPlatform)[0]
	player.global_position = plank.global_position + Vector2(plank.size.x * 0.5, plank.size.y + 60)
	player.velocity = Vector2(0, -450)
	player._contacts_valid = false
	await _step(7)
	_check(player.global_position.y >= plank.global_position.y + plank.size.y + TowerLandscape.PLAYER_HALF_HEIGHT - 1 and plank.state == CrumblingPlatform.State.READY, "A jump from below hits the board without triggering collapse")
	player.global_position = plank.global_position + Vector2(plank.size.x * 0.5, -60)
	player.velocity = Vector2.ZERO
	player._contacts_valid = false
	await _until(func(): return plank.state == CrumblingPlatform.State.CRACKING, 40, "Landing on top starts the board countdown")
	var scroll: Area2D = load("res://scenes/scroll_collectible.tscn").instantiate()
	scroll.stage_id = "tower"
	scroll.scroll_id = "crumbling_cavern"
	scroll.position = player.global_position - stage.rooms.get_child(3).global_position
	stage.rooms.get_child(3).add_child(scroll)
	await _step(16)
	_check(is_instance_valid(scroll._follower) and not scroll._secured, "A pending scroll cannot secure on a crumbling board")
	var before := plank.remaining
	stage.get_node("PauseMenu").open()
	await _step(15)
	_check(is_equal_approx(plank.remaining, before), "Pause freezes the collapse timer")
	stage.get_node("PauseMenu").resume()
	player.global_position = TowerLandscape.origin(3) + TowerLandscape.foothold(3, 15, 222.6)
	player.velocity = Vector2.ZERO
	player._contacts_valid = false
	await _step(16)
	_check(scroll._secured, "A permanent safe floor secures the pending scroll after 0.2 seconds")
	await _until(func(): return plank.state == CrumblingPlatform.State.MISSING, 20, "The countdown continues after leaving the board")
	player.set_physics_process(false)
	player.global_position = plank.global_position + plank.size * 0.5
	await _step(125)
	_check(plank.state == CrumblingPlatform.State.MISSING, "A returning board waits while the player overlaps it")
	player.global_position = TowerLandscape.origin(3) + TowerLandscape.foothold(3, 15, 222.6)
	await _step(2)
	_check(plank.state == CrumblingPlatform.State.READY and not plank.collision.disabled, "A clear board returns after its two-second delay")
	player.set_physics_process(true)
	player.global_position = plank.global_position + Vector2(plank.size.x * 0.5, -TowerLandscape.PLAYER_HALF_HEIGHT - 3)
	player.velocity = Vector2.ZERO
	player._contacts_valid = false
	await _step(5)
	player.respawn()
	await _step(2)
	_check(plank.state == CrumblingPlatform.State.READY and player.is_dash_ready(), "Retry restores the board and player resources immediately")
	scroll.queue_free()


func _cinematic() -> void:
	stage._enter_room(6, TowerLandscape.foothold(6, 179, 112))
	await _step(4)
	Input.action_press("move_right")
	await _until(func(): return stage.phase == stage.Phase.WALK, 30, "Approaching the rocket starts automatic boarding")
	Input.action_release("move_right")
	var start: float = player.global_position.x
	await _step(20)
	_check(player.global_position.x > start and not player.controls_enabled, "The ninja walks into the rocket without further input")
	stage.get_node("PauseMenu").open()
	var paused_position := player.position
	await _step(15)
	_check(player.position == paused_position, "Pause freezes automatic boarding")
	stage.get_node("PauseMenu").retry()
	await _step(3)
	_check(stage.phase == stage.Phase.RUN and player.controls_enabled and player.visuals.modulate.a == 1, "Retry cancels boarding and restores the ninja")
	player.global_position = TowerLandscape.origin(6) + TowerLandscape.foothold(6, 188, 114)
	player._contacts_valid = false
	await _until(func(): return stage.phase == stage.Phase.WALK, 20, "The rocket can be approached again")
	await _until(func(): return stage.phase == stage.Phase.CLEAR, 250, "Walking, boarding and fading reach the three-layer clear screen")
	_check(stage.completed and root.get_node("CollectionProgress").is_cleared("tower") and stage._clear_layers.size() == 3, "The rocket saves completion and shows three reusable image layers")
	_capture("clear")
	var jingle = root.get_node("GameAudio").music.get_stream_playback()
	root.get_node("GameAudio").set_quiet(false)
	_check(root.get_node("GameAudio").music.get_stream_playback() == jingle, "A room music update cannot interrupt the clear jingle")
	player.respawn()
	stage.phase = stage.Phase.WALK
	stage.skip_cinematic()
	_check(stage.completed and stage.phase == stage.Phase.CLEAR, "The shared cinematic skip reaches the same completed screen")
	player.respawn()
	_check(not paused and stage.phase == stage.Phase.RUN, "Retry exits the paused clear screen cleanly")


func _capture_rooms() -> void:
	stage.set_physics_process(false)
	player.set_physics_process(false)
	var spawns := [TowerLandscape.start()]
	for link_index in [0, 1, 2, 3, 4, 5, 6, 7, 8]:
		spawns.append(stage.connections[link_index][5])
	for index in 10:
		stage._enter_room(index, spawns[index])
		var dimensions := TowerLandscape.size(index)
		stage.camera.zoom = Vector2.ONE * minf(1280 / dimensions.x, 720 / dimensions.y)
		stage.camera.position = TowerLandscape.origin(index) + dimensions * 0.5
		await _step(2)
		_capture("room-%02d" % (index + 1))
	stage.camera.zoom = Vector2.ONE
	stage._enter_room(0, TowerLandscape.start())
	await _step(2)
	_capture("start-play")
	for view in [[3, TowerLandscape.foothold(3, 145, 130), "ascent-play"], [5, TowerLandscape.foothold(5, 300, 145), "upper-play"]]:
		stage._enter_room(view[0], view[1])
		await _step(2)
		_capture(view[2])
	stage.set_physics_process(true)
	player.set_physics_process(true)
	stage._enter_room(0, TowerLandscape.start())
	await _step(3)


func _capture(name: String) -> void:
	if captures.is_empty():
		return
	RenderingServer.force_draw()
	_check(root.get_texture().get_image().save_png(captures.path_join(name + ".png")) == OK, "Capture " + name)


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _until(predicate: Callable, frames: int, message: String) -> void:
	for frame in frames:
		if predicate.call():
			_check(true, message)
			return
		await _step()
	_check(false, message)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("STAGE_2: " + message)
