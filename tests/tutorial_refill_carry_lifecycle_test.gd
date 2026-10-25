extends "res://tests/tutorial_refill_carry_scroll_test.gd"

var original_heavy_position := Vector2.ZERO

func _run() -> void:
	progress = root.get_node("CollectionProgress")
	var shared := OS.get_environment("TUTORIAL_REFILL_CARRY_FIXTURE")
	progress.save_path = shared if not shared.is_empty() else "user://tutorial_refill_carry_lifecycle_%d.cfg" % OS.get_process_id()
	if OS.get_cmdline_user_args().has("--reload"):
		progress._collected.clear()
		progress.load_progress()
		_check(progress.get_count("tutorial") == 8,"A separate process reloads the eight actually collected native scrolls")
		for id in ["jump_turn_01","wall_loft_01","gravity_return_01","glide_updraft_01","spring_loft_05","reflection_loft_06","refill_loft_07","box_loft_08"]:
			_check(progress.has_scroll("tutorial",id),"A separate process preserves the actual native scroll identity: "+id)
		await _selection(8)
		if OS.get_cmdline_user_args().has("--screenshots"):
			await process_frame
			RenderingServer.force_draw()
			DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial_refill_carry")
			_check(root.get_texture().get_image().save_png("res://docs/screenshots/tutorial_refill_carry/stage_selection_8.png") == OK,"The separate-process eight-scroll selection is drawn natively")
		_clear_progress()
		await _close_fixture()
		print("TUTORIAL_REFILL_CARRY_RELOAD_OK (",checks," checks)")
		quit(1 if failed else 0)
		return
	for index in [4,10]:
		for axis in [1.0,0.8]:
			strength = axis
			for mode in ["R","death","leave"]:
				_clear_progress()
				await _fresh(index)
				await _touch_new(index)
				_check(_scroll()._follower == player and not progress.has_scroll("tutorial",_new_id(index)),"The new actual airborne scroll starts genuinely pending")
				if mode == "R":
					await _retry()
				elif mode == "death":
					await _new_death(index,true)
				else:
					tutorial.get_node("PauseMenu").return_to_select()
					await _step(5)
					await _fresh(index)
				_check(not progress.has_scroll("tutorial",_new_id(index)) and _scroll()._follower == null and _scroll().global_position == _scroll()._origin,"The interrupted pending pickup returns to its original native location without saving: "+mode)
				print("NEW_LIFECYCLE_CANCEL room=",index+1," axis=",axis," mode=",mode)
			_clear_progress()
			await _fresh(index)
			await _touch_new(index)
			await _secure_new(index)
			await _new_return(index,20)
			await _new_goal(index)
			await _new_seam(index)
			await _fresh(index)
			_check(_scroll().modulate.a < 1 and _scroll()._follower == null,"A confirmed scroll is a faint native marker on a fresh revisit")
			await _retry()
			_check(progress.has_scroll("tutorial",_new_id(index)),"R preserves the saved new scroll")
			await _touch_new(index)
			await _until(func(): return _on_loft(),180,"The revisit physically reaches the same static shelf")
			await _new_death(index,false)
			_check(progress.has_scroll("tutorial",_new_id(index)),"A real death retains the confirmed scroll")
			tutorial.get_node("PauseMenu").return_to_select()
			await _step(5)
			await _selection(1)
			progress._collected.clear()
			progress.load_progress()
			_check(progress.has_scroll("tutorial",_new_id(index)) and progress.get_count("tutorial") == 1,"The new scroll survives actual save reload and accessible selection before tutorial completion")
			print("NEW_LIFECYCLE_CONFIRMED room=",index+1," axis=",axis)
	await _all_six()
	await _new_tutorial()
	for index in [4,10]:
		await _enter(index)
		await _touch_new(index)
		await _secure_new(index)
		await _new_return(index,20)
	_check(progress.get_count("tutorial") == 8,"All eight native real-input routes save eight distinct identities")
	await _selection(8)
	if OS.get_cmdline_user_args().has("--keep-save"):
		print("TUTORIAL_REFILL_CARRY_SAVED_PATH=",progress.save_path)
	else:
		_clear_progress()
	await _close_fixture()
	print("TUTORIAL_REFILL_CARRY_LIFECYCLE_OK (",checks," checks)")
	quit(1 if failed else 0)

func _fresh(index: int) -> void:
	await _new_tutorial()
	await _enter(index)
	tutorial.set_hints_visible(true)
	if index == 10: original_heavy_position = tutorial.rooms.get_child(index).get_node("Heavy").global_position

func _new_id(index: int) -> String:
	return "refill_loft_07" if index == 4 else "box_loft_08"

func _touch_new(index: int) -> void:
	if index == 4: await _refill_touch(20)
	else: await _box_touch(20)

func _secure_new(index: int) -> void:
	await _until(func(): return progress.has_scroll("tutorial",_new_id(index)) and _on_loft(),180,"The real static shelf confirms the new scroll")
	var stopped := player.position
	_release()
	await _step(180)
	_check(_on_loft() and player.position.distance_to(stopped) < 2 and respawns == 0,"The confirmed shelf provides three seconds of actual rest")

func _new_death(index: int, pending: bool) -> void:
	var before := respawns
	var spike_hits := [0]
	if index == 10:
		tutorial.rooms.get_child(index).get_node("ScrollDetour/UpperWallSpikes").player_hit.connect(func(): spike_hits[0] += 1,CONNECT_ONE_SHOT)
	if not pending and index == 10:
		Input.action_press("move_right",strength)
		await _pulse("jump")
		await _step(20)
		await _pulse("dash")
	for frame in 480:
		if respawns != before: break
		_steer(800 if index == 4 else 900)
		if pending and player.is_on_floor(): await _pulse("jump")
		if pending: _check(not progress.has_scroll("tutorial",_new_id(index)),"Immediate actual takeoff keeps an unsafe pickup pending until death")
		await _step()
	_release()
	await _step(6)
	_check(respawns == before+1 and player.is_on_floor() and player.position.distance_to(player._spawn_position) < 3 and player.is_dash_ready(),"A real fall or spike contact restores the safe native checkpoint and resources exactly once")
	if index == 10:
		_check(spike_hits[0] == 1,"The box branch death comes from actual contact with its visible upper spike fence")
		var heavy: Grabbable = tutorial.rooms.get_child(index).get_node("Heavy")
		_check(heavy.global_position.distance_to(original_heavy_position) < 3 and player.get_held_object() == null,"A real death restores the transported box to its original native position")

func _new_seam(index: int) -> void:
	Input.action_press("move_right")
	await _until(func(): return tutorial.room_index == index+1 and not tutorial.transitioning,200,"The actual cleared right boundary reaches the following original lesson")
	_release()
	Input.action_press("move_left")
	await _until(func(): return tutorial.room_index == index and not tutorial.transitioning,200,"The original following lesson returns through the real left boundary")
	_release()
	await _retry()
	_check(progress.has_scroll("tutorial",_new_id(index)) and player.is_on_floor() and player.position.distance_to(player._spawn_position) < 6,"Real adjacent-room travel and R retain the new saved scroll")
