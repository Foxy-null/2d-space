extends "res://tests/gravity_fifth_recovery_test.gd"


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_fifth_scroll_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	var short := OS.get_cmdline_user_args().has("--routes-only") or OS.get_cmdline_user_args().has("--capture-only")
	for strength in ([1.0] if short else [1.0,0.8]):
		para_strength = strength
		Input.action_press("move_right",para_strength)
		_check(is_equal_approx(Input.get_axis("move_left","move_right"),para_strength),"The branch really uses the declared direct action strength")
		_release_inputs()
		progress._collected.clear()
		if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
		if not short: await _fifth_pending_cancellations()
		for after in [false,true]:
			progress._collected.clear()
			if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
			for index in [27,29]:
				await _fresh_para(index)
				_fifth_connect()
				var scroll: Area2D = stage.rooms.get_child(index).get_node("Scroll")
				var previous: int = progress.get_count("gravity")
				if after: await _fifth_course(index)
				var started := Engine.get_physics_frames()
				if after:
					actions.clear()
					flips.clear()
					await _para_walk(72)
				await _fifth_scroll_pickup(index)
				if after: await _fifth_capture("room_%d_scroll_after_arrival" % [index+1])
				await _fifth_scroll_secure(index)
				await _fifth_scroll_return(index)
				var seconds := float(Engine.get_physics_frames()-started)/60.0
				_check(respawns==0 and seconds<30 and scroll._secured and progress.get_count("gravity")==previous+1,"The actual optional round trip counts once and stays below thirty seconds, including three seconds of rest and the post-arrival approach")
				print("GRAVITY_FIFTH_SCROLL room=%d axis=%.1f after=%s %.2fs" % [index+1,para_strength,after,seconds])
				if not after:
					if index==27: await _fifth_after_wind(index)
					await _fifth_course(index,true)
				_check(stage.cleared.has(index) and respawns==0,"The optional return rejoins the actual main arrival; post-arrival exploration needs no R or re-entry")
				if not short:
					await _retry()
					_check(scroll._secured and progress.has_scroll("gravity",scroll.scroll_id),"R preserves the actual confirmed native scroll")
					actions.clear()
					flips.clear()
					await _fifth_scroll_pickup(index,true)
					await _fifth_pending_death(index)
					_check(scroll._secured and progress.get_count("gravity")==previous+1,"A later real spike death preserves the confirmed record")
					stage.get_node("PauseMenu").return_to_select()
					await _step(4)
					_check_fifth_selection(previous+1)
					progress._collected.clear()
					progress.load_progress()
					_check(progress.get_count("gravity")==previous+1,"The actual confirmed save file survives an in-process reread")
					await _fresh_para(index)
					_fifth_connect()
					_check(stage.rooms.get_child(index).get_node("Scroll")._secured and stage.rooms.get_child(index).get_node("Scroll").modulate.a<1,"A fresh revisit displays the confirmed scroll faintly")
				else:
					await _fresh_para(index)
					_fifth_connect()
				await _fifth_scroll_pickup(index,true)
				await _fifth_scroll_secure(index)
				await _fifth_scroll_return(index)
				_check(progress.get_count("gravity")==previous+1,"Physically revisiting the faint confirmed node returns naturally without adding a duplicate")
				await _fifth_capture("room_%d_scroll_revisit" % [index+1])
	monitor_view = false
	_release_inputs()
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(4)
	_check_fifth_selection(2)
	await _fifth_capture("selection")
	print("GRAVITY_FIFTH_SAVED_PATH ",progress.save_path)
	if not OS.get_cmdline_user_args().has("--keep-save") and FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	current_scene.queue_free()
	await _step(5)
	print("GRAVITY_FIFTH_SCROLL_TEST_%s %d checks" % ["FAILED" if failed else "OK",checks])
	quit(1 if failed else 0)


func _check_fifth_selection(total: int) -> void:
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage3")
	var expected := "%d / 10" % total
	_check(card.get_node("Content/Collection/Count").text==expected and card.accessibility_name.contains("巻物 "+expected) and not card.disabled,"Visible and accessible selection shows the actual saved IDs with the ten-scroll total")


func _fifth_pending_cancellations() -> void:
	for index in [27,29]:
		for cancellation in ["retry","death","leave"]:
			await _fresh_para(index)
			_fifth_connect()
			await _fifth_scroll_pickup(index)
			var scroll: Area2D = stage.rooms.get_child(index).get_node("Scroll")
			_check(scroll._follower==player and not scroll._secured and progress.get_count("gravity")==0,"The real airborne follower is pending before cancellation")
			if cancellation=="retry": await _retry()
			elif cancellation=="death": await _fifth_pending_death(index)
			else:
				monitor_view = false
				stage.get_node("PauseMenu").return_to_select()
				await _step(4)
				await _fresh_para(index)
				scroll = stage.rooms.get_child(index).get_node("Scroll")
			_check(not scroll._secured and scroll._follower==null and scroll.global_position.is_equal_approx(scroll._origin) and progress.get_count("gravity")==0,"Actual retry, swept spike death or unfinished exit returns the pending scroll to origin without saving")


func _fifth_pending_death(index: int) -> void:
	monitor_view = false
	var before := respawns
	var hits := [0]
	for area in stage.rooms.get_child(index).find_children("*","Area2D",true,false):
		if area is SpikeBlock: area.player_hit.connect(func(): hits[0]+=1,CONNECT_ONE_SHOT)
	if index==29:
		await _para_dash(Vector2.LEFT)
		await _until(func(): return not player.is_dashing(),30,"The real lateral escape Dash finishes")
	for frame in 650:
		if respawns>before: break
		_para_drive(140 if index==27 else 50)
		await _step()
	_check(respawns>before,"Actual branch movement reaches native spikes before a new static confirmation")
	_release_inputs()
	await _step(4)
	_check(hits[0]>0 and respawns==before+1,"The branch death really uses one native spike contact")


func _fifth_scroll_pickup(index: int, secured := false) -> void:
	var scroll: Area2D = stage.rooms.get_child(index).get_node("Scroll")
	if index==27:
		await _para_grab()
		_para_drive(450)
		await _until(func(): return absf(_para_x()-450)<15,160,"Enter the actual branch wind")
		for frame in 650:
			_para_drive(450)
			if player.position.y<810: break
			await _step()
		_para_drive(240)
	else:
		await _fifth_entry(index)
		await _para_walk(420)
		_para_drive(220)
		await _until(func(): return _fifth_floor("ScrollRest"),240,"The inverted left/up branch reaches the native higher ceiling")
		await _para_walk(220)
		await _jump()
	for frame in 250:
		_para_drive(240 if index==27 else 220)
		if scroll._follower==player or (secured and _fifth_touches_scroll(scroll)): break
		await _step()
	_check((scroll._secured and _fifth_touches_scroll(scroll)) if secured else scroll._follower==player,"Actual optional input touches the airborne native scroll before its safe landing")
	_check(secured or not progress.has_scroll("gravity",scroll.scroll_id),"Pending airborne contact has not been saved")
	await _fifth_capture("room_%d_scroll_pending" % [index+1])


func _fifth_scroll_secure(index: int) -> void:
	await _para_walk(240 if index==27 else 220)
	var scroll: Area2D = stage.rooms.get_child(index).get_node("Scroll")
	await _until(func(): return scroll._secured,30,"The real safe static landing confirms the follower")
	_check(progress.has_scroll("gravity",scroll.scroll_id) and _fifth_floor("ScrollRest"),"The actual branch support saves its exact native ID")
	await _fifth_rest("scroll_secured")


func _fifth_scroll_return(index: int) -> void:
	if index==27:
		_para_drive(450)
		await _jump()
		await _para_rise(450,1060,650,"scroll_return_wind")
	else:
		_para_drive(650)
		await _jump()
		await _step(20)
		await _para_dash(Vector2(1,1))
		await _para_walk(650)
	_check(_fifth_floor("WindRest" if index==27 else "UpperRest"),"The physical branch returns to the same main static rest without re-entry")
	await _fifth_capture("room_%d_scroll_return" % [index+1])


func _fifth_touches_scroll(scroll: Area2D) -> bool:
	var target: CollisionShape2D = scroll.get_node("CollisionShape2D")
	var body: CollisionShape2D = player.get_node("CollisionShape2D")
	return target.shape.collide_with_motion(target.global_transform,Vector2.ZERO,body.shape,body.global_transform,Vector2.ZERO)
