extends "res://tests/corridor_expansion_test.gd"

func _run() -> void:
	screenshot_mode=OS.get_cmdline_user_args().has("--screenshots")
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_more_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	if OS.get_cmdline_user_args().has("--timing-only"):
		await _more_timing()
		print("CORRIDOR_MORE_TIMING_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
		quit(1 if failed else 0)
		return
	for strength in [1.0, 0.85]:
		steering_strength = strength
		await _new_stage()
		await _enter(9)
		for section in range(9, 15):
			var before := deaths
			var started := Engine.get_physics_frames()
			actions.clear()
			if section==9:
				more_drive(100)
				_check(is_equal_approx(absf(Input.get_axis("move_left","move_right")),strength),"The synthetic action uses the measured horizontal strength directly")
				_hold()
			_check_mechanic_view(section)
			await _more_capture("room%d_entrance"%(section+1))
			_check(await traverse(section, true), "Reach the real observation rest in room %d" % (section+1))
			_hold()
			await step(12)
			var rest := player.position
			await step(180)
			_check(player.is_on_floor() and player.position.distance_to(rest) < 2 and stage._carry_requirement_met(), "Three seconds of safe stationary observation")
			await _more_capture("room%d_rest"%(section+1))
			_check(await traverse(section), "Rejoin the route and reach the next checkpoint in room %d" % (section+1))
			_check(deaths == before + (0 if section == stage.rooms.get_child_count() - 1 else 1), "Successful traversal does not die")
			_check(not actions.has("climb"), "Carry routes do not use wall climbing")
			_check(progress.get_count("companion") == 0, "Ordinary traversal leaves the optional scrolls untouched")
			var seconds := float(Engine.get_physics_frames()-started)/60
			_check(seconds < 30, "Retry segment stays under thirty seconds including rest")
			print("CORRIDOR_MORE_ROOM_%d %.2fs strength=%.2f actions=%s" % [section+1,seconds,strength,actions])
			_hold()
			await step(25)
		_check(not stage.completed and stage.room_index == 15, "The former final room now reaches the sixteenth checkpoint")
	await _more_capture("room15_exit")
	await _new_stage()
	await _gimmick_retries()
	if failed:return
	for strength in [1.0, 0.85]:
		steering_strength=strength
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		await _new_stage()
		await _scroll_route(progress)
		for section in [9, 12]:
			await _new_scroll(section, progress)
			if failed: return
	if OS.get_cmdline_user_args().has("--keep-fixture"):
		print("CORRIDOR_MORE_SAVED_PATH ",progress.save_path)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CORRIDOR_MORE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _more_timing() -> void:
	await _new_stage()
	for section in [9, 12]:
		for strength in [1.0, 0.85]:
			steering_strength = strength
			for first in [16, 20, 24]:
				for second in [16, 20, 24]:
					for third in [16, 20, 24]:
						await _enter(section)
						var before := deaths
						if section == 12:
							_check(await island_leap(20, 20, strength, section), "Reach the wind island before testing the boot transfer")
						var room: Node2D = stage.rooms.get_child(section)
						_check(not player.is_air_jump_ready(), "The real airborne boot must be earned during this transfer")
						_check(await more_combo(430 if section == 9 else 930, room.walls[0 if section == 9 else 1], first, second, third) and deaths == before, "Both jumps and Dash accept 16/20/24-frame gaps: room=%d strength=%.2f gaps=%d/%d/%d" % [section+1,strength,first,second,third])
						if failed: return
			print("CORRIDOR_MORE_TIMING_ROOM_%d strength=%.2f 27 combinations" % [section+1,strength])


func _new_scroll(section: int, progress: Node) -> void:
	var id := "combo_left_02" if section == 9 else "wind_left_03"
	var count: int = progress.get_count("companion")
	for interruption in ["retry", "death", "leave"]:
		await _new_stage()
		await _enter(section)
		await _new_branch_touch(section)
		var scroll: Area2D = stage.rooms.get_child(section).get_node("Scroll")
		_check(scroll._follower == player and not progress.has_scroll("companion",id), "A new branch starts as a real pending airborne pickup")
		if interruption == "retry":
			await _pulse("reset")
			_hold()
			await step(6)
			_check(scroll._follower == null and scroll.position == scroll._origin-stage.rooms.get_child(section).global_position, "R restores the pending scroll to its native position")
		elif interruption == "death":
			await _new_spike_death()
			_check(scroll._follower == null and scroll.global_position == scroll._origin, "Physical spike contact cancels a pending pickup")
		else:
			stage.get_node("PauseMenu").return_to_select()
			await step(4)
		_check(progress.get_count("companion") == count, "Interrupted pickup never changes the saved total")
	await _new_stage()
	await _enter(section)
	var started := Engine.get_physics_frames()
	var before := deaths
	await _new_branch_touch(section)
	await _more_capture("room%d_scroll" % (section+1))
	var room: Node2D = stage.rooms.get_child(section)
	var rest: StaticBody2D = room.get_node("ScrollRest")
	var collider: CollisionShape2D = rest.get_node("Collision")
	var rect := Rect2(rest.position+collider.shape.get_rect().position,collider.shape.get_rect().size)
	_check(await more_flight(rect,false), "The airborne scroll returns to the actual safe shelf")
	_hold()
	await step(20)
	_check(progress.has_scroll("companion",id) and stage._carry_requirement_met(), "Safe landing saves the new scroll while keeping the companion")
	var stopped := player.position
	await step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped)<2 and deaths==before, "The optional shelf permits three seconds of quiet observation")
	await _more_capture("room%d_scroll_rest" % (section+1))
	_check(await more_transfer(room.walls[1]), "The optional route rejoins the same main-path rest")
	var seconds:=float(Engine.get_physics_frames()-started)/60
	print("CORRIDOR_MORE_SCROLL_%d %.2fs strength=%.2f"%[section+1,seconds,steering_strength])
	_check(seconds<30 and deaths==before, "The collection round trip stays under thirty seconds without dying")
	await _more_capture("room%d_scroll_return" % (section+1))
	_check(await traverse(section) and deaths==before+1, "The branch returns to the intended route and next checkpoint")
	await _new_stage()
	await _enter(section)
	_check(stage.rooms.get_child(section).get_node("Scroll").modulate.a<1, "Confirmed collection remains as a faint revisit scroll")
	await _pulse("reset")
	_hold()
	await step(6)
	_check(progress.get_count("companion")==count+1, "R preserves confirmed collection")
	await _new_spike_death()
	_check(progress.get_count("companion")==count+1, "Actual contact death preserves confirmed collection")
	stage.get_node("PauseMenu").return_to_select()
	await step(4)
	var card: Button=current_scene.get_node("Margin/Content/Stages/Stage4")
	var expected := "%d / 12"%(count+1)
	_check(card.get_node("Content/Collection/Count").text==expected and card.accessibility_name.contains("巻物 "+expected), "Saved collection and actual total appear in selection and its accessible name")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("companion")==count+1 and progress.has_scroll("companion",id), "Returning from an unfinished stage and reloading preserves collection")


func _new_branch_touch(section: int) -> void:
	_check(await traverse(section,true), "Reach the real first rest before the optional branch")
	var room: Node2D=stage.rooms.get_child(section)
	if section==9:
		_check(await more_transfer(room.walls[1]), "Carry the companion to the left branch entrance")
	else:
		_check(await more_combo(930,room.walls[1],20), "The boot and companion reach the upper branch entrance")
	var scroll: Area2D=room.get_node("Scroll")
	more_drive(scroll.position.x-_more_x())
	await more_jump()
	var cooldown:=12
	for frame in 300:
		if scroll._follower==player:return
		more_drive(scroll.position.x-_more_x())
		cooldown=maxi(0,cooldown-1)
		if not player.is_on_floor() and player.velocity.y>-40 and player.get_available_extra_jump_count()>0 and cooldown==0:
			Input.action_press("jump")
			cooldown=12
		await step()
	_check(false,"Real input reaches the new airborne scroll")


func _new_spike_death() -> void:
	var before:=deaths
	var hits: Array[bool]=[]
	stage.rooms.get_child(stage.room_index).get_node("Hazards/LeftEdgeSpikes").player_hit.connect(func():hits.append(true),CONNECT_ONE_SHOT)
	_drive(Vector2.LEFT)
	await _pulse("dash")
	for frame in 120:
		if deaths>before:break
		await step()
	release()
	await step(6)
	_check(deaths==before+1 and not hits.is_empty(),"A real movement into visible spikes produces one contact death")
	_check(player.position.distance_to(player._spawn_position)<2 and player.get_held_object()==null and player.gravity_direction==1 and player.is_dash_ready() and not player.is_air_jump_ready(),"Contact death restores the room checkpoint, companion and resources")


func _gimmick_retries() -> void:
	await _enter(9)
	_check(await more_walk(430),"The resource retry starts from the actual companion entrance")
	_hold()
	await more_jump()
	await step(20)
	await more_jump()
	await step(20)
	_check(player.is_air_jump_ready() and actions.has("creature_jump"),"R is tested after earning a real airborne boot and spending the companion")
	await _pulse("reset")
	release()
	await step(6)
	_check(not player.is_air_jump_ready() and player.get_held_object()==null and stage.rooms.get_child(9).get_node("Items/JumpCrystal")._available,"R restores the boot, companion and movement rights")
	await _enter(10)
	_check(await more_walk(185),"The gravity retry carries the actual companion")
	more_drive(300-_more_x())
	await more_jump()
	for frame in 120:
		more_drive(360-_more_x())
		await step()
		if player.gravity_direction==-1:break
	_check(player.gravity_direction==-1,"The real Up gate reverses the carrier before retry")
	await _pulse("reset")
	release()
	await step(6)
	_check(player.gravity_direction==1 and player.get_held_object()==null and player.position.distance_to(player._spawn_position)<2,"R removes reversed gravity and delayed gate contacts")
	await _enter(11)
	var launches: Array[bool]=[]
	stage.rooms.get_child(11).get_node("Spring").launched.connect(func(_body):launches.append(true))
	_check(await more_walk(185) and launches.size()==1,"The actual spring launches the held companion")
	await _pulse("reset")
	release()
	await step(6)
	_check(player.position.distance_to(player._spawn_position)<2 and player.get_held_object()==null,"R during a spring flight restores the real entrance")
	_check(await more_walk(185) and launches.size()==2,"Leaving the spring on R rearms its native contact without a custom reset")
	await _new_spike_death()


func _check_mechanic_view(section: int) -> void:
	if section not in [11,12,17]:return
	var room: Node2D=stage.rooms.get_child(section)
	var mechanic: Rect2=room.walls[0] if section==11 else Rect2(room.get_node("HighTailwind").position-room.get_node("HighTailwind").area_size*0.5,room.get_node("HighTailwind").area_size)
	var screen:=Rect2(root.get_canvas_transform()*room.to_global(mechanic.position),mechanic.size)
	_check(root.get_visible_rect().encloses(screen),"The first Spring destination or required high wind is visible from the actual entrance")
	_check(not stage.get_node("HUD/Info").get_global_rect().intersects(screen),"The HUD leaves the first intended mechanic fully visible")
