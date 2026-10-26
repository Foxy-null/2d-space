extends SceneTree
## Regression fixtures for slow decisions, crowded landings and explicit retry.
var stage
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	var contours: Array = []
	for number in stage.ROOM.ROOM_COUNT:
		stage._load_room(number)
		_check(stage.room.size.x >= 5600 and stage.room.size.y >= 1680, "Every room has at least the final arena's dimensions")
		var wall: StaticBody2D = stage.room.entrance_wall
		_check(wall.position.x == 14 and stage.room.enemy_spawn.x < 0, "The entrance belongs to the enclosing wall, with the enemy outside")
		await _step(2)
		var ray := PhysicsRayQueryParameters2D.create(Vector2(-60, stage.room.spawn.y), Vector2(70, stage.room.spawn.y), 1)
		_check(not stage.room.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "An intact enclosing wall physically closes the entrance")
		stage.room.set_entrance_intact(false)
		await _step(2)
		_check(stage.room.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "Breaching the wall creates a physical opening into the course")
		if number != stage.ROOM.FINAL_ROOM:
			var main: Array = stage.room.passage_route
			var branch: Array = stage.room.branch_route
			_check(main.front() == branch.front() and main.back() == branch.back(), "The two routes reconnect at both ends")
			_check(main != branch and not contours.has(main), "Each switched route has a distinct contour and an actual detour")
			contours.append(main.duplicate())
	stage._load_room(0)
	await _step(2)
	# A slow player may face many volleys before leaving the first landing.
	for volley in 20:
		for slot in 9:
			var needle = _shoot(stage.room.spawn + Vector2((slot - 4) * 24, -200), Vector2.DOWN, volley % 4)
			needle.advance(1.0, stage.player)
		await _step()
	_check(stage.room.needles.get_children().all(func(needle): return not needle.stuck or not needle.is_dangerous() or not stage.room.entrance_area.has_point(needle.tip_position())), "Twenty volleys cannot leave a dangerous fence across the entry landing")
	stage._retry_room()
	var wall: StaticBody2D = stage.room._block(Rect2(1100, 200, 24, 450))
	await _step(2)
	for volley in 20:
		for slot in 6:
			var needle = _shoot(Vector2(900, 340 + slot * 5), Vector2.RIGHT, volley % 4)
			needle.neutral_left = 0.0
			needle.tracking_left = 0.0
			needle.advance(1.0, stage.player)
		await _step()
	var remaining: int = stage.room.needles.get_child_count()
	_check(remaining <= 4, "Repeated mixed attacks keep only a small group on the same landing")
	for needle in stage.room.needles.get_children():
		_check(needle.anchor == wall, "The crowd test uses real impacts against terrain")
		if needle.variant in [1, 3]:
			var support: StaticBody2D = needle.get_child(1)
			_check((support.collision_layer & stage.player.collision_mask) == 0 and (support.collision_layer & stage.enemy.collision_mask) != 0, "Needle footholds support only the spike-immune enemy and cannot block the ninja")
		needle.advance(13.0, stage.player)
	await _step(2)
	_check(stage.room.needles.get_child_count() == 0, "Every kind of unpinned needle disappears after its lifetime")
	for kind in 4:
		var fragment = _shoot(Vector2(900, 260 + kind * 90), Vector2.RIGHT, kind)
		fragment.neutral_left = 0.0
		fragment.tracking_left = 0.0
		fragment.advance(1.0, stage.player)
		_check(fragment.stuck, "Each projectile variant really embeds in terrain")
		fragment.advance(7.0, stage.player)
		_check(fragment.is_queued_for_deletion(), "Each unpinned variant expires without a retry")
		await _step(2)
	var gate: StaticBody2D = stage.room.passage_gate
	var embedded = _shoot(gate.position + Vector2(-100, 0), Vector2.RIGHT, 0)
	embedded.advance(1.0, stage.player)
	_check(embedded.stuck and embedded.anchor == gate, "The gate receives an actual incoming needle")
	stage.room.open_passage()
	embedded.advance(0.01, stage.player)
	_check(embedded.is_queued_for_deletion() and gate.collision_layer == 0, "Opening a gate removes its embedded needles instead of leaving invisible spike anchors")
	await _step(2)
	_shoot(Vector2(500, 300), Vector2.RIGHT, 0)
	stage._spawn_ash_cloud(Vector2(500, 300), Vector2(800, 700), Vector2.DOWN)
	stage.player.position = Vector2(900, stage.room.size.y + 200)
	stage._intro_left = 0.0
	stage._physics_process(0.0)
	_check(stage._game_over_pending and paused and stage._game_over_panel.visible, "Falling presents a real game-over choice")
	var clock: float = stage.room._elapsed
	var failed_at: Vector2 = stage.player.position
	await _step(180)
	_check(stage.player.position == failed_at and stage.room._elapsed == clock, "Waiting at game over cannot cause another death or automatic restart")
	var cancel := InputEventAction.new()
	cancel.action = "pause_game"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await _step()
	_check(not stage.get_node("PauseMenu").overlay.visible, "Pause cannot cover the retry decision")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	await _step()
	accept = InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = false
	Input.parse_input_event(accept)
	await _step(3)
	_check(not paused and not stage._game_over_pending and stage.player.position == stage.room.spawn, "The ordinary UI accept input retries the room")
	_check(stage.room.needles.get_child_count() == 0 and stage.room.get_node("AshClouds").get_child_count() == 0 and not stage.enemy.active, "Retry clears the accumulated attacks and restores the enemy departure")
	var items: Array = stage.room.get_node("Items").get_children().filter(func(item): return item.get_meta("supply", -1) == 0)
	stage.room._spawn_item(stage.room.LIGHT, Vector2(800, 300), 0)
	items = stage.room.get_node("Items").get_children().filter(func(item): return item.get_meta("supply", -1) == 0)
	for index in items.size():
		items[index].position = Vector2(600 + index * 200, 300)
		items[index].linear_velocity = Vector2(700, 0)
	stage.room._restock()
	_check(items[0].position == Vector2(600, 300) and items[1].position == Vector2(800, 300), "Restocking cannot teleport a box during a throw")
	stage.player.position = Vector2(600, 350)
	for item in items:
		item.linear_velocity = Vector2.ZERO
	stage.room._restock()
	_check(items[0].position == Vector2(600, 300), "A box beside or beneath the player is not recycled")
	print("STAGE_6_HUMAN_PLAY_TEST_OK (%d checks)" % checks)
	quit()

func _shoot(at: Vector2, direction: Vector2, kind: int):
	var directions: Array[Vector2] = [direction]
	stage._spawn_needles(at, directions, kind)
	return stage.room.needles.get_child(-1)

func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("HUMAN_PLAY: " + message)
		quit(1)
		assert(condition, message)
