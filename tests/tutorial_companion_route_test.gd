extends SceneTree

var tutorial: Node
var player: PlayerController
var failed := false
var checks := 0
var respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _ordinary_jump()
	await _safe_retry()
	for delay in [12, 16, 20]:
		await _course(delay)
	await _dash_alternative()
	_release()
	print("TUTORIAL_COMPANION_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _ordinary_jump() -> void:
	await _enter()
	await _pulse("jump")
	await _walk_to(360)
	await _step(5)
	await _pulse("jump")
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await _walk_to(500)
	Input.action_release("move_right")
	await _step(80)
	_check(player.is_on_floor() and absf(_local().y - 614) < 2, "A normal jump and wall Grab cannot climb the first platform")
	_check(player.get_held_object() == null and not tutorial.seen.has("climb") and not tutorial.seen.has("creature_jump"), "The platform cannot substitute a wall climb for the extra jump")


func _safe_retry() -> void:
	await _enter()
	await _grab()
	await _walk_to(320)
	await _pulse("jump")
	await _walk_to(500)
	Input.action_release("move_right")
	await _step(80)
	_check(respawns == 0 and player.is_on_floor() and absf(_local().y - 614) < 2, "A missed extra jump lands on the safe recovery floor")
	_check(player.get_held_object() == _room().get_node("Creature") and player.get_available_extra_jump_count() == 1, "The companion stays held and ready after a miss")
	await _pulse("jump")
	await _step(16)
	await _pulse("jump")
	await _step(70)
	_check(player.is_on_floor() and absf(_local().y - 434) < 2, "The first platform can be retried vertically from the recovery floor")
	_release()
	await _pulse("reset")
	await _step(5)
	_check(_local().x < 100 and player.get_held_object() == null, "Reset returns to the safe entrance and clears held state")
	_check(_room().get_node("Creature").position.distance_to(Vector2(150, 607.1)) < 4, "Reset restores the companion next to the entrance")


func _course(delay: int) -> void:
	await _enter()
	_capture("entrance")
	await _grab()
	await _walk_to(320)
	await _pulse("jump")
	await _step(delay)
	await _pulse("jump")
	await _walk_to(500)
	Input.action_release("move_right")
	await _step(70)
	_check(player.is_on_floor() and absf(_local().y - 434) < 2, "The companion's extra jump reaches the wide first platform")
	_check(player.get_available_extra_jump_count() == 1 and tutorial.seen.has("creature_landed"), "Resting on the first platform restores the companion jump")
	_capture("rest")
	await _step(60)
	_check(player.is_on_floor() and absf(_local().y - 434) < 2, "The first platform allows an unhurried rest")
	await _walk_to(580)
	await _pulse("jump")
	await _step(delay)
	await _pulse("jump")
	await _walk_to(740)
	Input.action_release("move_right")
	await _step(70)
	_check(player.is_on_floor() and absf(_local().y - 254) < 2, "A refilled companion jump reaches the second platform")
	_check(player.get_available_extra_jump_count() == 1, "The second platform restores the companion again")
	_capture("second")
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.cleared.has(12):
			break
		Input.action_release("jump")
		if _local().x >= 880:
			Input.action_release("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_check(tutorial.cleared.has(12) and respawns == 0, "The second platform leads to the real goal without dying")
	_check(not tutorial.seen.has("dash") and not tutorial.seen.has("climb"), "The complete companion route needs no dash or wall climb")
	_capture("cleared")
	Input.action_press("move_right")
	for frame in 180:
		if tutorial.room_index == 13 and not tutorial.transitioning:
			break
		await _step()
	_check(tutorial.room_index == 13 and player.controls_enabled, "The goal leads into the next room")


func _dash_alternative() -> void:
	await _enter()
	await _walk_to(320)
	await _pulse("jump")
	await _step(16)
	Input.action_press("move_up")
	await _pulse("dash")
	Input.action_release("move_up")
	await _walk_to(500)
	Input.action_release("move_right")
	await _step(60)
	_check(player.get_held_object() == null and player.is_on_floor() and absf(_local().y - 434) < 2, "A previously learned dash remains an alternative to the first companion jump")
	await _walk_to(580)
	await _pulse("jump")
	await _step(16)
	Input.action_press("move_up")
	await _pulse("dash")
	Input.action_release("move_up")
	await _walk_to(740)
	Input.action_release("move_right")
	await _step(70)
	_check(player.is_on_floor() and absf(_local().y - 254) < 2, "Dash also reaches the second platform; the companion is not physically mandatory")
	_check(not tutorial.cleared.has(12) and not tutorial.seen.has("creature_jump"), "Using dash alone does not satisfy the existing companion lesson")


func _enter() -> void:
	_release()
	if is_instance_valid(tutorial):
		tutorial.free()
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	tutorial.call("_set_room", 12, false)
	player.respawn()
	await _step(6)
	respawns = 0


func _grab() -> void:
	Input.action_press("wall_grab")
	await _step(3)
	_check(player.get_held_object() == _room().get_node("Creature"), "The companion can be grabbed from the entrance without walking")


func _room() -> Node:
	return tutorial.rooms.get_child(12)


func _walk_to(x: float) -> void:
	Input.action_press("move_right")
	for frame in 350:
		if _local().x >= x:
			return
		await _step()
	_check(false, "Walking to %s timed out" % x)


func _local() -> Vector2:
	return player.global_position - tutorial.rooms.get_child(12).global_position


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_COMPANION_ROUTE: %s (position=%s velocity=%s seen=%s)" % [message, _local(), player.velocity, tutorial.seen.keys()])


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/tutorial-companion-%s.png" % name)
