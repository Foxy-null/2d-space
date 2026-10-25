extends SceneTree

var tutorial: Node
var player: PlayerController
var progress: Node
var failed := false
var checks := 0
var respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--30hz"):
		Engine.physics_ticks_per_second = 30
	elif OS.get_cmdline_user_args().has("--120hz"):
		Engine.physics_ticks_per_second = 120
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://tutorial_scroll_route_test_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _new_tutorial()
	_check(tutorial.rooms.get_child_count() == 17 and tutorial.MAIN_ROOM_COUNT == 16, "Optional scroll branches keep the existing room count")
	await _jump_branch()
	_check(_scroll()._follower == player and not progress.has_scroll("tutorial", "jump_turn_01"), "The jump branch touches the real scroll before safe-landing confirmation")
	await _retry()
	_check(_scroll()._follower == null and not progress.has_scroll("tutorial", "jump_turn_01"), "R cancels an unsecured branch scroll")
	await _jump_branch()
	player.respawn()
	await _step(6)
	_check(_scroll()._follower == null and not progress.has_scroll("tutorial", "jump_turn_01"), "Death cancels an unsecured branch scroll")
	await _jump_branch()
	tutorial.get_node("PauseMenu").return_to_select()
	await _step(5)
	_check(not progress.has_scroll("tutorial", "jump_turn_01"), "Returning from an unfinished branch does not save its pending scroll")
	await _new_tutorial()
	var before := respawns
	var started := Engine.get_physics_frames()
	await _jump_branch()
	await _until(func(): return progress.has_scroll("tutorial", "jump_turn_01"), 40, "The jump branch secures its scroll on the upper shelf")
	_check(not player.wall_actions_enabled and not player.dash_enabled and not tutorial.cleared.has(0), "The first detour uses only unlocked jumping and leaves main arrival unfinished")
	_check(tutorial.camera.position.y < 360, "The camera follows the upper jump branch")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _capture("jump_loft")
	await _move_to(175)
	await _until(func(): return player.is_on_floor() and _local().y > 580, 150, "The jump branch descends to the original entrance floor")
	var jump_seconds := float(Engine.get_physics_frames() - started) / Engine.physics_ticks_per_second
	_check(respawns == before and jump_seconds < 30, "The jump detour and return keep a short retry interval without dying")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _capture("jump_entrance")
	await _retry()
	_check(progress.has_scroll("tutorial", "jump_turn_01") and _scroll().modulate.a < 1, "R preserves the confirmed jump scroll")
	tutorial._set_room(1, false)
	player.respawn()
	await _step(6)
	await _jump_to(105)
	await _jump_to(205)
	await _step(30)
	_check(_local().y > 400 and not progress.has_scroll("tutorial", "wall_loft_01"), "Ordinary jumping alone cannot bridge the wall branch's tall rest gap")
	await _retry()
	before = respawns
	started = Engine.get_physics_frames()
	await _wall_branch()
	await _until(func(): return progress.has_scroll("tutorial", "wall_loft_01"), 50, "The wall branch secures its scroll on the final shelf")
	_check(player.wall_actions_enabled and not player.dash_enabled, "The wall detour uses the first unlocked wall actions without requiring Dash")
	_check(not tutorial.cleared.has(1) and not tutorial.completed, "The optional wall branch leaves its main arrival and tutorial completion unfinished")
	_check(tutorial.camera.position.y < 0 and _local().y < -200, "The tall branch scrolls beyond the original screen without triggering retry")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _capture("wall_loft")
	await _move_to(184)
	await _until(func(): return player.is_on_floor() and _local().y > 580, 180, "The open center allows a safe descent past all rest shelves")
	await _move_to(300)
	var wall_seconds := float(Engine.get_physics_frames() - started) / Engine.physics_ticks_per_second
	_check(respawns == before and tutorial.room_index == 1 and wall_seconds < 30, "The wall detour returns to the main course within a short retry interval")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _capture("wall_entrance")
	player.respawn()
	await _step(6)
	_check(progress.get_count("tutorial") == 2, "Confirmed scrolls survive death independently of main progress")
	tutorial.get_node("PauseMenu").return_to_select()
	await _step(5)
	_check(current_scene.get_node("Margin/Content/Stages/Stage1/Content/Collection/Count").text == "2 / 2", "Stage selection shows the two actual tutorial collectibles")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("tutorial") == 2, "Leaving the unfinished tutorial keeps its saved scrolls")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	_release()
	print("TUTORIAL_SCROLL_ROUTE_TEST_%s (%d checks, %dHz, jump %.2fs, wall %.2fs)" % ["FAILED" if failed else "OK", checks, Engine.physics_ticks_per_second, jump_seconds, wall_seconds])
	quit(1 if failed else 0)


func _new_tutorial() -> void:
	change_scene_to_file("res://scenes/tutorial.tscn")
	await _step(4)
	tutorial = current_scene
	player = tutorial.player
	player.respawned.connect(func(): respawns += 1)
	await _step(6)


func _jump_branch() -> void:
	await _move_to(300)
	await _jump_to(380)
	await _move_to(390)
	await _jump_to(565)
	await _move_to(565)
	await _jump_to(665)
	await _move_to(650)
	await _jump_to(490)
	await _move_to(480)
	await _jump_to(310)
	await _until(func(): return _scroll()._follower == player, 6, "The final jump makes real contact after Area synchronization")


func _wall_branch() -> void:
	await _jump_to(105)
	_drive("move_right", true)
	await _pulse("jump")
	await _until(func(): return _local().y < 65, 180, "Wall climbing reaches above the middle rest")
	await _move_to(100)
	await _until(func(): return player.is_on_floor(), 60, "The middle shelf restores wall stamina")
	_check(player.get_wall_stamina() > 2.9 and _local().y < 140, "The wall branch has a genuine midway rest")
	_drive("move_right", true)
	await _pulse("jump")
	await _until(func(): return _local().y < -295, 180, "Climb to the upper scroll without a Dash")
	_release()
	Input.action_press("wall_grab")
	Input.action_press("move_left")
	await _pulse("jump")
	await _move_to(92)
	await _until(func(): return player.is_on_floor(), 120, "A wall kick lands on the upper scroll shelf")


func _jump_to(target: float) -> void:
	_release()
	Input.action_press("jump")
	var left_floor := false
	for frame in 100:
		_steer(target)
		await _step()
		Input.action_release("jump")
		left_floor = left_floor or not player.is_on_floor()
		if left_floor and player.is_on_floor():
			_release()
			return
	_check(false, "An ordinary jump lands toward x=%s" % target)
	_release()


func _move_to(target: float) -> void:
	_release()
	for frame in 180:
		_steer(target)
		await _step()
		if absf(target - _local().x) < 2 and absf(player.velocity.x) < 10:
			_release()
			return
	_check(false, "Real movement reaches x=%s" % target)
	_release()


func _steer(target: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	var offset := target - _local().x
	Input.action_press("move_right" if offset > 0 else "move_left", minf(absf(offset) / 45.0, 1))


func _drive(direction: String, climb: bool = false) -> void:
	_release()
	Input.action_press(direction)
	if climb:
		Input.action_press("wall_grab")
		Input.action_press("move_up")


func _retry() -> void:
	_release()
	await _pulse("reset")
	await _step(6)


func _local() -> Vector2:
	return player.global_position - tutorial.rooms.get_child(tutorial.room_index).global_position


func _scroll() -> Area2D:
	return tutorial.rooms.get_child(tutorial.room_index).get_node("ScrollDetour/Scroll")


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _until(condition: Callable, limit: int, message: String) -> void:
	for frame in roundi(float(limit) * Engine.physics_ticks_per_second / 60):
		if condition.call():
			return
		if OS.get_cmdline_user_args().has("--trace") and frame % 30 == 0:
			print("%s frame=%d pos=%s velocity=%s stamina=%s grab=%s floor=%s" % [message, frame, _local(), player.velocity, player.get_wall_stamina(), player.is_wall_grabbing(), player.is_on_floor()])
		await _step()
	_check(false, message)


func _capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial_scrolls")
	root.get_texture().get_image().save_png("res://docs/screenshots/tutorial_scrolls/%s.png" % label)


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("TUTORIAL_SCROLL: %s pos=%s" % [message, _local() if is_instance_valid(tutorial) else Vector2.ZERO])
