extends "res://tests/tutorial_launch_scroll_test.gd"

func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://tutorial_refill_carry_%d.cfg" % OS.get_process_id()
	_clear_progress()
	await _new_tutorial()
	for index in [4, 10]:
		for axis in [1.0,0.8]:
			for gap in [16,20,24]:
				if OS.get_cmdline_user_args().has("--screenshots") and (axis != 1.0 or gap != 20): continue
				_clear_progress()
				await _new_tutorial()
				await _enter(index)
				tutorial.set_hints_visible(not OS.get_cmdline_user_args().has("--screenshots") or OS.get_cmdline_user_args().has("--hints"))
				strength = axis
				monitor_launch = true
				Input.action_press("move_right",axis)
				_check(is_equal_approx(Input.get_axis("move_left","move_right"),axis),"The actual horizontal Input axis matches the strong or weak profile")
				_release()
				await _new_shot("entrance")
				var started := Engine.get_physics_frames()
				if index == 4: await _refill_touch(gap)
				else: await _box_touch(gap)
				if failed: return
				await _until(func(): return progress.has_scroll("tutorial", "refill_loft_07" if index == 4 else "box_loft_08"), 180, "The new upper shelf confirms the actual scroll")
				_release()
				await _step(180)
				await _new_shot("rest")
				_check(player.is_on_floor() and respawns == 0, "The optional upper shelf provides three seconds of rest")
				await _new_return(index,gap)
				await _new_shot("return")
				_check((Engine.get_physics_frames()-started)/60.0 < 30, "The optional round trip including rest remains below thirty seconds")
				print("NEW_BRANCH room=",index+1," axis=",axis," gap=",gap," p=",_local()," seconds=",(Engine.get_physics_frames()-started)/60.0)
				await _new_goal(index)
				await _new_shot("goal")
				monitor_launch = false
	_clear_progress()
	await _close_fixture()
	print("TUTORIAL_REFILL_CARRY_SCROLL_OK (",checks," checks)")
	quit(1 if failed else 0)

func _refill_touch(delay: int) -> void:
	var before := respawns
	await _move_to(245)
	Input.action_press("move_right",strength)
	await _pulse("jump")
	await _step(delay + (8 if strength < 1 else 0))
	Input.action_press("move_up",strength)
	await _pulse("dash")
	Input.action_release("move_up")
	await _until(func(): return tutorial.seen.has("dash_refill"), 100, "The first real airborne dash receives the native crystal")
	_release()
	await _step(4)
	Input.action_press("move_up",strength)
	await _pulse("dash")
	Input.action_release("move_up")
	for frame in 180:
		_steer(590)
		await _step()
		if _on_loft(): break
	_check(_on_loft() and respawns == before, "The refilled upward dash reaches the optional shelf")
	_release()
	await _new_shot("turn")
	await _pulse("jump")
	await _step(delay)
	Input.action_press("move_up",strength)
	await _pulse("dash")
	Input.action_release("move_up")
	for frame in 180:
		_steer(540)
		await _step()
		if _scroll()._follower == player or progress.has_scroll("tutorial","refill_loft_07" if tutorial.room_index == 4 else "box_loft_08"):
			_release()
			await _new_shot("pending")
			return
	_check(false,"The optional refill route touches its real scroll")

func _box_touch(delay: int) -> void:
	var before := respawns
	await _jump_to(330)
	await _move_to(335)
	Input.action_press("wall_grab")
	await _step(4)
	var heavy: Grabbable = tutorial.rooms.get_child(10).get_node("Heavy")
	_check(player.get_held_object() == heavy, "The actual Heavy is acquired")
	await _held_move(600)
	await _step(12)
	Input.action_release("wall_grab")
	Input.action_press("move_left",strength)
	await _step(18)
	_release()
	await _step(40)
	var target: float = heavy.position.x
	await _jump_to(target)
	_check(_on_object(heavy) and player.get_held_object() == null, "A real upward support collision places the player on the transported Heavy")
	print("REAL_BOX_SUPPORT ",_local()," heavy=",heavy.position," size=",heavy.collider.shape.get_rect())
	await _pulse("jump")
	await _step(delay)
	Input.action_press("move_up",strength)
	await _pulse("dash")
	Input.action_release("move_up")
	for frame in 180:
		_steer(600)
		await _step()
		if _on_loft(): break
	_check(_on_loft() and respawns == before, "The transported box supports a real jump to the upper shelf")
	_release()
	await _new_shot("turn")
	await _pulse("jump")
	await _step(delay)
	Input.action_press("move_up",strength)
	await _pulse("dash")
	Input.action_release("move_up")
	for frame in 180:
		_steer(600)
		await _step()
		if _scroll()._follower == player or progress.has_scroll("tutorial","refill_loft_07" if tutorial.room_index == 4 else "box_loft_08"):
			_release()
			await _new_shot("pending")
			return
	_check(false,"The box route touches its real scroll")

func _on_object(body: Node) -> bool:
	if not player.is_on_floor(): return false
	for index in player.get_slide_collision_count():
		var hit: KinematicCollision2D = player.get_slide_collision(index)
		if hit.get_collider() == body and hit.get_normal().dot(Vector2.UP) > 0.8: return true
	return false

func _on_loft() -> bool:
	return _on_object(tutorial.rooms.get_child(tutorial.room_index).get_node("ScrollDetour/Loft"))


func _new_return(index: int, delay: int) -> void:
	if index == 4:
		Input.action_press("move_right",strength)
		await _pulse("jump")
		await _step(delay)
		await _pulse("dash")
		for frame in 240:
			_steer(1000)
			await _step()
			if _on_object(tutorial.rooms.get_child(index).get_node("Landing")): break
		_check(_on_object(tutorial.rooms.get_child(index).get_node("Landing")) and respawns == 0, "The optional refill branch naturally returns to the original main landing")
	else:
		await _move_to(750)
		await _until(func(): return player.is_on_floor() and _local().y > 580,180,"The optional box branch descends naturally to the original main floor")
		_check(respawns == 0,"The box detour returns without death or R")
	_release()

func _new_goal(index: int) -> void:
	if index == 10:
		var heavy: Grabbable = tutorial.rooms.get_child(index).get_node("Heavy")
		for frame in 180:
			Input.action_press("wall_grab")
			_steer(heavy.position.x)
			await _step()
			if player.get_held_object() == heavy: break
		_check(player.get_held_object() == heavy,"The same real transported box is recovered for the original Button task")
		await _held_move(745)
		await _step(12)
		Input.action_release("wall_grab")
		Input.action_press("move_left",strength)
		await _step(18)
		_release()
		await _until(func(): return tutorial.rooms.get_child(index).get_node("Button").is_pressed(),120,"The recovered Heavy physically powers the original Button")
	await _launch_main_goal(index)
	_check(respawns == 0 and tutorial.rooms.get_child(index).get_node("Goal").is_pressed(),"The original arrival completes without death")

func _new_shot(phase: String) -> void:
	if phase == "rest":
		var index: int = tutorial.room_index
		var collision: CollisionShape2D = tutorial.rooms.get_child(index).get_node("Landing/Collision" if index == 4 else "Floor/Collision")
		var surface: Rect2 = collision.get_global_transform_with_canvas() * collision.shape.get_rect()
		_check(root.get_visible_rect().encloses(surface),"The full original return surface is visible before leaving the safe optional shelf")
		for path in ["HUD/Margin/Panel","HUD/PauseButton"]:
			var panel: Control = tutorial.get_node(path)
			_check(not panel.is_visible_in_tree() or not panel.get_global_rect().intersects(surface),"The visible return surface is outside the actual HUD")
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial_refill_carry")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/tutorial_refill_carry/room%d_%s%s.png" % [tutorial.room_index+1,phase,"_hints" if tutorial.hints_visible else ""]) == OK,"The native real-input phase image is saved")
	if phase == "rest": print("NEW_BRANCH_HUD ",tutorial.get_node("HUD/Margin/Panel").get_global_rect())

func _close_fixture() -> void:
	monitor_launch = false
	_release()
	for node in root.find_children("*","",true,false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D: node.stop()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await _step(4)

func _step(count: int = 1) -> void:
	for frame in count:
		await super._step()
		if not monitor_launch or not is_instance_valid(tutorial) or tutorial.transitioning or not player.controls_enabled: continue
		var object: Grabbable = player.get_held_object()
		if object == null: continue
		var bounds: Rect2 = object.collider.get_global_transform_with_canvas() * object.collider.shape.get_rect()
		_check(root.get_visible_rect().encloses(bounds),"The full actually held object stays inside the viewport")
		for path in ["HUD/Margin/Panel","HUD/PauseButton"]:
			var panel: Control = tutorial.get_node(path)
			_check(not panel.is_visible_in_tree() or not panel.get_global_rect().intersects(bounds),"The actual held object stays outside the visible HUD")
