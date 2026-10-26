extends "res://tests/gravity_parachute_route_test.gd"


func _run() -> void:
	progress=root.get_node("CollectionProgress")
	progress.save_path="user://gravity_para_scroll_%d.cfg"%OS.get_process_id()
	progress._collected.clear()
	for index in [21,23]:
		for cancellation in ([] if OS.get_cmdline_user_args().has("--capture-only") else ["reset","fall","leave"]):
			await _fresh_para(index)
			await _para_scroll_pickup(index)
			var room: Node2D=stage.rooms.get_child(index)
			var scroll: Area2D=room.get_node("Scroll")
			_check(scroll._follower==player and not scroll._secured and player.get_held_object()==room.get_node("Parachute"),"A real airborne scroll follows while the actual Parachute remains held")
			_check(not progress.has_scroll("gravity",scroll.scroll_id),"Airborne pickup has not reached storage")
			if cancellation=="reset":
				await _retry()
			elif cancellation=="fall":
				monitor_view=false
				_release_inputs()
				await _step()
				_check(player.get_held_object()==null,"The death comparison really releases its held Parachute")
				# Real release, lateral travel away from static supports, and swept spike death.
				if index==21:
					Input.action_press("move_right")
					await _until(func(): return respawns>0,420,"An actual fall reaches the native pit spikes")
				else:
					for frame in 420:
						_para_drive(1355)
						await _step()
						if respawns>0:break
					_check(respawns>0,"Actual travel outside the safe ceiling reaches native top spikes")
			else:
				monitor_view=false
				change_scene_to_file("res://scenes/stage_select.tscn")
				await _step(4)
				await _fresh_para(index)
			if cancellation!="leave":
				_check(scroll._follower==null and not scroll._secured,"Retry or real death returns pending scroll to origin")
				_check(scroll.global_position.is_equal_approx(scroll._origin),"Pending scroll returns to its original native position")
			_check(progress.get_count("gravity")==0,"Pending cancellation never saves progress")
	for strength in ([1.0] if OS.get_cmdline_user_args().has("--capture-only") else [1.0,0.8]):
		para_strength=strength
		for index in [21,23]:
			await _fresh_para(index)
			var room: Node2D=stage.rooms.get_child(index)
			var scroll: Area2D=room.get_node("Scroll")
			if progress.has_scroll("gravity",scroll.scroll_id):
				_check(scroll._secured and scroll.modulate.a<1,"Revisit displays an already-secured native scroll faintly")
				progress._collected.erase("gravity")
				await _fresh_para(index)
				room=stage.rooms.get_child(index)
				scroll=room.get_node("Scroll")
			var branch_start:=Engine.get_physics_frames()
			await _para_scroll_pickup(index)
			await _para_walk(240 if index==21 else 1550)
			await _until(func(): return scroll._secured,30,"Real safe landing secures the follower after 0.2 seconds")
			_check(progress.has_scroll("gravity",scroll.scroll_id),"The actual native ID is saved after landing")
			await _para_capture("room_%d_scroll_secured"%(index+1))
			await _para_branch_return(index)
			_check(respawns==0,"The optional branch naturally returns without R or death")
			var branch_seconds:=float(Engine.get_physics_frames()-branch_start)/60.0
			_check(branch_seconds<30,"The actual optional round trip stays within thirty seconds")
			print("GRAVITY_PARA_SCROLL room=%d axis=%.2f round_trip=%.2fs"%[index+1,para_strength,branch_seconds])
			await _retry()
			_check(scroll._secured and scroll._follower==null,"R keeps the confirmed scroll")
			await _para_course(index)
			_check(respawns==1 and stage.cleared.has(index),"The actual main arrival remains reachable after securing and retry")
			await _retry()
			await _para_scroll_pickup(index,true)
			await _para_walk(240 if index==21 else 1550)
			await _para_branch_return(index)
			_check(scroll._secured and scroll.modulate.a<1 and stage.cleared.has(index),"After the real arrival, the same native branch and natural return remain accessible without recollecting")
			await _para_capture("room_%d_scroll_revisit"%(index+1))
	# Keep both actual new IDs together for a genuinely separate-process reload.
	for index in [21,23]:
		if progress.has_scroll("gravity","parachute_loft_07" if index==21 else "folded_current_08"): continue
		await _fresh_para(index)
		await _para_scroll_pickup(index)
		await _para_walk(240 if index==21 else 1550)
		await _until(func(): return stage.rooms.get_child(index).get_node("Scroll")._secured,30,"Secure the new scroll for reload")
	_check(progress.get_count("gravity")==2,"Two actual new IDs remain stored together")
	monitor_view=false
	_release_inputs()
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(4)
	var card: Button=current_scene.get_node("Margin/Content/Stages/Stage3")
	_check(card.get_node("Content/Collection/Count").text=="2 / 10" and card.accessibility_name.contains("巻物 2 / 10"),"Visible and accessible stage selection show two of ten")
	await _para_capture("selection")
	print("GRAVITY_PARACHUTE_SAVE ",progress.save_path)
	if not OS.get_cmdline_user_args().has("--keep-save"): DirAccess.remove_absolute(progress.save_path)
	current_scene.queue_free()
	await _step(5)
	print("GRAVITY_PARACHUTE_SCROLL_TEST_OK %d checks"%checks)
	quit()


func _para_scroll_pickup(index: int, secured := false) -> void:
	var room: Node2D=stage.rooms.get_child(index)
	var scroll: Area2D=room.get_node("Scroll")
	await _para_grab()
	var wind_x:=450.0 if index==21 else 1900.0
	var target_y:=670.0 if index==21 else 550.0
	for frame in 650:
		_para_drive(wind_x)
		if absf(_para_x()-wind_x)<15 and player.position.y<target_y:break
		await _step()
	await _para_capture("room_%d_scroll_entrance"%(index+1))
	var target_x:=240.0 if index==21 else 1600.0
	for frame in 250:
		_para_drive(target_x)
		if scroll._follower==player or (secured and _touches_scroll(scroll)): break
		await _step()
	_check((scroll._secured and _touches_scroll(scroll)) if secured else scroll._follower==player,"The real left/up branch reaches its native scroll (p=%s secured=%s)"%[player.position,secured])
	await _para_capture("room_%d_scroll_pending"%(index+1))


func _para_branch_return(index: int) -> void:
	if index==21:
		_para_drive(450)
		await _jump()
		await _para_rise(450,760,820)
	else: await _para_walk(1550)
	await _para_rest()


func _touches_scroll(scroll: Area2D) -> bool:
	var target:CollisionShape2D=scroll.get_node("CollisionShape2D")
	var body:CollisionShape2D=player.get_node("CollisionShape2D")
	return target.shape.collide_with_motion(target.global_transform,Vector2.ZERO,body.shape,body.global_transform,Vector2.ZERO)
