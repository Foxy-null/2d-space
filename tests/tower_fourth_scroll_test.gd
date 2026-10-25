extends "res://tests/tower_fourth_route_test.gd"

var progress: Node
var scroll: Area2D
var branch_high := false

func _run() -> void:
	progress = root.get_node("CollectionProgress")
	var capture := OS.get_cmdline_user_args().has("--screenshots")
	var positive_only := capture or OS.get_cmdline_user_args().has("--routes-only")
	for strength in ([1.0] if capture else [1.0,0.8]):
		upper_strength = strength
		upper_jump_delay = 20
		upper_dash_delay = 20
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for high in [false,true]:
			if OS.get_cmdline_user_args().has("--low-only") and high: continue
			if OS.get_cmdline_user_args().has("--high-only") and not high: continue
			branch_high = high
			var id := "updraft_return_08" if high else "reflection_left_07"
			var before: int = progress.get_count("tower")
			for interruption in ["retry","death","leave"]:
				if positive_only: break
				await _new_branch()
				await _pickup_scroll()
				if failed:return
				_check(scroll._follower==player and not scroll._secured,"The actual airborne scroll remains pending")
				if interruption=="retry":
					await _upper_pulse("reset")
					await _step(8)
				elif interruption=="death":
					await _actual_fall()
				else:
					monitor_view = false
					stage.get_node("PauseMenu").return_to_select()
					await _step(5)
				_check(progress.get_count("tower")==before,"Retry, real death and leaving never save a pending pickup")
				if interruption!="leave": _check(scroll._follower==null and scroll.global_position==scroll._origin,"The pending native scroll returns to its original branch")
				if failed:return
			var started := Engine.get_physics_frames()
			await _new_branch()
			await _pickup_scroll()
			if failed:return
			await _land_on(1130 if high else 160,-30586 if high else -27306,500)
			await _more_walk(1130 if high else 160)
			var stopped := player.position
			_release()
			if branch_high: Input.action_press("wall_grab")
			await _step(180)
			_check(scroll._secured and progress.has_scroll("tower",id) and respawns==0,"The actual static shelf confirms its own optional scroll")
			_check(player.is_on_floor() and player.position.distance_to(stopped)<2,"The optional static shelf provides three seconds of genuine rest")
			await _scroll_view("rest")
			if high:
				await _more_walk(1040)
				await _upper_pulse("jump")
				_horizontal(600)
				await _land_on(600,-30426,500)
				await _more_walk(-100)
			else:
				await _more_walk(270)
				Input.action_press("move_right",upper_strength)
				await _upper_pulse("jump")
				await _step(28)
				await _upper_pulse("dash")
				await _land_on(660,-27306,400)
			_check(stage.checkpoint_index==(23 if high else 21) and respawns==0,"The detour returns to the same native checkpoint's main floor")
			if high: _check(player.get_held_object()==stage.get_node("Items/Fourth24Parachute"),"The return preserves the actual native parachute")
			var seconds := float(Engine.get_physics_frames()-started)/60
			_check(seconds<30,"The optional pickup and natural return stay below thirty seconds")
			print("TOWER_FOURTH_SCROLL_SECONDS high=",high," axis=",upper_strength," seconds=",seconds)
			await _scroll_view("return")
			if positive_only: continue
			await _upper_pulse("reset")
			await _step(8)
			_check(scroll._secured,"R preserves a confirmed native scroll")
			await _actual_fall()
			_check(scroll._secured and progress.has_scroll("tower",id),"A real death also preserves the confirmed collection")
			await _fresh_fourth(23 if high else 21)
			scroll = stage.get_node("ScrollBranch/FourthUpdraftScroll" if high else "ScrollBranch/FourthReflectionScroll")
			_check(scroll.modulate.a<1 and scroll._follower==null,"A saved native scroll remains faint on revisit")
			monitor_view = false
			stage.get_node("PauseMenu").return_to_select()
			await _step(5)
			var card: Button = current_scene.get_node("Margin/Content/Stages/Stage2")
			var expected := "%d / 8"%(before+1)
			_check(card.get_node("Content/Collection/Count").text==expected and card.accessibility_name.contains("巻物 "+expected),"Selection displays and announces the actual saved count out of eight")
			progress._collected.clear()
			progress.load_progress()
			_check(progress.get_count("tower")==before+1 and progress.has_scroll("tower",id),"Confirmed optional IDs survive an actual disk reload")
			if failed:return
	monitor_view = false
	_release()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await _step(18)
	print("TOWER_FOURTH_SAVED_PATH=",progress.save_path)
	print("TOWER_FOURTH_SCROLL_TEST_OK checks=",checks)
	quit(1 if failed else 0)

func _new_branch() -> void:
	await _fresh_fourth(23 if branch_high else 21)
	scroll = stage.get_node("ScrollBranch/FourthUpdraftScroll" if branch_high else "ScrollBranch/FourthReflectionScroll")
	if branch_high:
		await _more_walk(450)
		await _more_grab("Fourth24Parachute")
		await _wind_rise(800,-30550)
	else:
		await _more_bounce(800,"Fourth22Bumper",Vector2(850,-27280))
		await _more_walk(610)
	await _scroll_view("entrance")

func _pickup_scroll() -> void:
	if branch_high:
		await _upper_dash()
		_horizontal(1230)
	else:
		Input.action_press("move_left",upper_strength)
		await _upper_pulse("jump")
		await _step(28)
		await _upper_pulse("dash")
		_horizontal(260)
	var jumped := false
	for frame in 700:
		if scroll._follower==player or respawns>0:break
		if player.is_on_floor() and not jumped:
			await _more_walk(1130 if branch_high else 160)
			await _upper_pulse("jump")
			jumped=true
		await _step()
	_check(scroll._follower==player and not scroll._secured and not player.is_on_floor() and respawns==0,"Real controls touch the optional airborne scroll before a safe landing")
	_horizontal(player.position.x)
	await _scroll_view("touch")

func _actual_fall() -> void:
	monitor_view=false
	var before := respawns
	for frame in 600:
		Input.action_press("move_right" if branch_high else "move_left",upper_strength)
		Input.action_press("move_down")
		if player.is_dash_ready(): Input.action_press("dash")
		await _step()
		if respawns>before:break
	_release()
	await _step(8)
	_check(respawns==before+1 and player.is_on_floor(),"Normal input causes a real fall and returns to the same safe checkpoint")

func _scroll_view(phase: String) -> void:
	if phase in ["entrance","rest"]:
		var name := "Fourth24UpperRest" if branch_high else "Fourth22Rest"
		var x := 570.0 if branch_high else 700.0
		if phase == "entrance":
			name = "FourthUpdraftBranch" if branch_high else "FourthReflectionBranch"
			x = 1130.0 if branch_high else 210.0
		var shape: CollisionShape2D = stage.get_node("Terrain/"+name+"/Collision")
		var face := shape.shape.get_rect()
		face.position.x = clampf(x-shape.global_position.x-80,face.position.x,face.end.x-160)
		face.size = Vector2(160,16)
		_check_next_visible(shape.get_global_transform_with_canvas()*face,"The optional branch's actual next landing: "+phase)
	if not OS.get_cmdline_user_args().has("--screenshots"):return
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tower-fourth")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/tower-fourth/scroll_%s_%s%s.png"%["high" if branch_high else "low",phase,"_hints" if stage.hints_visible else ""])==OK,"The native optional branch image is saved")
