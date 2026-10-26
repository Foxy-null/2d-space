extends SceneTree
## Focused behavior checks; fixtures are separate from the normal-input playthrough.

var stage
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	await _step(180)
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	for number in stage.ROOM.ROOM_COUNT:
		stage._load_room(number)
		_check(stage.room.route.size() >= 4 and not stage.room.attack_patterns.is_empty(), "All thirteen rooms have a route and attack selection")
	stage._load_room(11)
	_check(stage.room.spike_blocks.size() == 5, "The added room uses the original four spike blocks and a new route obstacle")
	var spike: SpikeBlock = stage.room.spike_blocks[0]
	stage.player.position = spike.position
	stage.enemy.position = spike.position
	_check(stage._touches_hazard(stage.player, stage.player.position) and not stage._touches_hazard(stage.enemy, stage.enemy.position), "Moving spike blocks hurt the ninja and respect enemy immunity")
	var before := spike.position
	spike.advance(0.5)
	_check(spike.position != before and spike.previous_position == before, "Shared spike motion retains its swept collision segment")
	stage._load_room(0)
	await _perception()
	await _attacks()
	await _mobile_rain()
	await _boss()
	await _capture_retry()
	print("STAGE_6_OVERHAUL_TEST_OK (%d checks)" % checks)
	quit()


func _perception() -> void:
	stage.enemy.position = Vector2(100, -500)
	stage.player.position = Vector2(450, -500)
	stage.enemy.reset_pursuit()
	stage.enemy.position = Vector2(100, -500)
	stage.enemy.active = true
	stage.enemy._update_perception(0.01)
	var remembered: Vector2 = stage.enemy._last_seen
	var count: int = stage.enemy._trail.size()
	_check(count > 0 and stage.enemy.awareness == "pursuit", "Visible movement is remembered")
	var wall: StaticBody2D = stage.room._block(Rect2(600, -900, 40, 700))
	stage.player.position = Vector2(850, -500)
	await _step(2)
	stage.enemy._update_perception(0.1)
	_check(stage.enemy.awareness == "search" and stage.enemy._last_seen == remembered and stage.enemy._trail.size() == count, "An unseen player does not add secret breadcrumbs")
	stage.enemy.position = remembered
	stage.enemy._update_perception(2.6)
	_check(stage.enemy.awareness == "patrol", "Search finishes instead of tracking through a wall forever")
	var noise := Vector2(720, -500)
	stage.enemy.hear_switch(noise)
	_check(stage.enemy.awareness == "search" and stage.enemy._last_seen == noise - Vector2(0, 26) and stage.enemy._last_seen != stage.player.position, "A switch sound directs search to the switch without exposing the hidden player")
	wall.free()
	await _step(2)
	stage.enemy._update_perception(0.01)
	_check(stage.enemy.awareness == "pursuit" and stage.enemy._last_seen == stage.player.position, "Real sight reacquires the player")


func _attacks() -> void:
	stage.room._block(Rect2(-1000, -2000, 2000, 40))
	stage.room.visible_area = Rect2()
	stage.enemy.active = true
	for kind in [0, 1, 2]:
		stage.room.attack_patterns.assign([kind])
		stage.enemy.position = Vector2(-600, -2026)
		stage.player.position = Vector2(-200, -2026)
		await _step(2)
		stage.enemy._update_perception(0.0)
		stage.enemy._needle_cooldown = 0.0
		stage.enemy._needle_recovery = 0.0
		stage.enemy._technique_wait.fill(0.0)
		stage.enemy._update_needle_attack(0.01)
		_check(stage.enemy._needle_warning > 0.0, "Every selected attack announces a warning")
		if kind == 1:
			var cover: StaticBody2D = stage.room._block(Rect2(-150, -2500, 20, 500))
			await _step(2)
			stage.enemy._cache_warning_spans()
			_check(stage.enemy._warning_spans.size() == 10 and stage.enemy._warning_spans.all(func(point): return point.x <= -149.9), "All five warning rays stop at actual terrain")
			cover.free()
			await _step(2)
		stage.enemy._update_needle_attack(1.11)
		if kind == 0:
			for delta in [0.01, 0.21, 0.21]:
				stage.enemy._update_needle_attack(delta)
		_check(stage.room.needles.get_child_count() == [3, 5, 6][kind], "The selected volley emits its complete real projectile count")
		_check(stage.enemy._needle_recovery > 0.0 and not stage.enemy.can_capture(), "Recovery remains a capture-free counterattack window")
		for needle in stage.room.needles.get_children():
			needle.free()
	stage.enemy._needle_warning = -1.0
	stage.enemy._volley_left = 0
	stage.enemy.position = stage.player.position
	stage.enemy._needle_recovery = 0.5
	stage._immunity_left = 0.0
	stage._hit_grace = 0.0
	stage._respawn_grace = 0.0
	stage._update_capture(0.01)
	_check(stage.enemy.capture_windup < 0.0, "Touching during recovery does not start capture")
	stage.enemy._needle_recovery = 0.0
	stage._update_capture(0.01)
	_check(stage.enemy.capture_windup > 0.0, "A close grab announces a windup")
	stage.player.position.x += 180
	stage._update_capture(0.26)
	_check(not stage._capture_pending and stage.enemy.capture_recovery > 0.0, "Moving away causes a grab whiff")


func _mobile_rain() -> void:
	stage._load_room(3)
	stage.room.visible_area = Rect2()
	stage.enemy.position = Vector2(850, 900)
	stage.player.position = Vector2(1100, 900)
	var umbrella: Grabbable = stage.room.UMBRELLA.instantiate()
	umbrella.position = stage.enemy.position + Vector2(30, 0)
	stage.room.get_node("Items").add_child(umbrella)
	await _step(2)
	stage.enemy._pickup_left = 0.0
	_check(stage.enemy.try_begin_grab(umbrella), "The cloud fixture holds a real umbrella")
	stage.room.attack_patterns.assign([3])
	stage.enemy._update_perception(0.0)
	stage.enemy._needle_variant = 3
	stage.enemy._needle_cooldown = 0.0
	stage.enemy.active = true
	stage.enemy._update_needle_attack(0.01)
	_check(stage.enemy._mobile_cast and stage.enemy._needle_warning > 0.0, "Umbrella flight can announce ash without stopping traversal")
	stage.enemy._physics_process(0.05)
	_check(stage.enemy.get_held_object() == umbrella and stage.enemy._commands.get("wall_grab", false), "Casting preserves the umbrella hold input")
	stage.enemy._update_needle_attack(1.11)
	_check(stage.room.get_node("AshClouds").get_child_count() == 1, "The moving cast creates an actual cloud")


func _boss() -> void:
	stage._load_room(stage.ROOM.FINAL_ROOM)
	await _step(2)
	_check(stage.room.doors.is_empty(), "The final room starts directly in the arena")
	_check(stage.room.exit_position.distance_to(stage.room.cage.get_center()) > 2500, "Sealing and escape are spatially separate")
	_check(stage.room.escape_keys.size() == 2 and stage.room.escape_keys[0].position.distance_to(stage.room.escape_keys[1].position) > 2000, "Escape requires two distant keys")
	var weight: Grabbable = stage.room.HEAVY.instantiate()
	weight.position = stage.room.seal_button.position - Vector2(0, 50)
	stage.room.get_node("Items").add_child(weight)
	await _step(35)
	weight.apply_central_impulse(Vector2(2000, 0))
	await _step(30)
	_check(stage.room.seal_button.is_pressed(), "The recessed power tray resists incidental horizontal pushes")
	stage.enemy.position = stage.room.cage.get_center()
	stage.player.position = Vector2(1800, 1294)
	_check(stage.room.seal_button.is_pressed() and not stage.room.seal_enemy(stage.enemy, stage.player), "A prepared weight alone cannot seal the enemy")
	stage.enemy.position = Vector2(2500, 1294)
	stage.player.position = stage.room.seal_console - Vector2(0, 26)
	stage.player.velocity = Vector2(0, 400)
	stage.player._move_player()
	_check(not stage.room.seal_enemy(stage.enemy, stage.player), "Stepping early cannot seal an empty cage")
	stage.enemy.position = stage.room.cage.get_center()
	_check(not stage.room.seal_enemy(stage.enemy, stage.player), "Camping on the console cannot auto-seal a later arrival")
	stage.player.position.x -= 200
	stage.room.seal_enemy(stage.enemy, stage.player)
	stage.player.position = stage.room.seal_console - Vector2(0, 26)
	stage.player.velocity = Vector2(0, 400)
	stage.player._move_player()
	_check(not stage.room.seal_enemy(stage.enemy, stage.player), "A moving enemy cannot be sealed by a passive console step")
	stage.player.position.x -= 200
	stage.room.seal_enemy(stage.enemy, stage.player)
	stage.enemy.apply_stun(2.0)
	stage.player.position = stage.room.seal_console - Vector2(0, 26)
	stage.player.velocity = Vector2(0, 400)
	stage.player._move_player()
	_check(stage.room.seal_enemy(stage.enemy, stage.player), "Power, a caged enemy and a fresh player step close the cage")
	stage.room.update_escape(true)
	_check(stage.room.arrival.locked, "Waiting alone does not unlock the escape gate")
	for index in 2:
		stage.player.position = stage.room.escape_keys[index].position
		await _step(3)
		_check(stage.room.keys_collected == index + 1, "Each key is collected by a real player overlap")
	stage.room.update_escape(true)
	_check(stage.room.escape_unlocked, "Both distant keys and completed confrontation unlock escape")
	stage.player.respawn()
	await _step(3)
	_check(stage.room.keys_collected == 0 and not stage.room.seal_button.is_pressed() and stage.room.arrival.locked, "Full retry resets the complete boss puzzle")


func _capture_retry() -> void:
	stage.player._wall_stamina = 0.0
	stage._capture()
	_check(stage._game_over_pending, "A failed capture starts the room-loss feedback")
	_check(paused, "A failed capture pauses the world until the player chooses retry")
	stage._retry_button.pressed.emit()
	var generation: int = stage._generation
	await _step(85)
	_check(not stage._game_over_pending and stage.player.controls_enabled and stage._generation == generation, "Manual retry cancels a stale capture timer without a second reset")


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("OVERHAUL: " + message)
		quit(1)
		assert(condition, message)
