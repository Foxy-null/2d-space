extends "res://tests/canyon_left_route_test.gd"

var monitor_view := false


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	var only_room := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="): only_room = int(arg.trim_prefix("--room="))
	var profiles: Array = [[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	if OS.get_cmdline_user_args().has("--quick") or OS.get_cmdline_user_args().has("--screenshots"): profiles = [[1.0,20]]
	for profile in profiles:
		for index in [24,25,26]:
			if only_room > 0 and index+1 != only_room: continue
			await _course(index,profile[0],profile[1])
			if failed: return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_ENTRY_ROUTE_TEST_OK (",checks," checks)")
	quit()


func _course(index: int, strength: float, delay: int) -> void:
	monitor_view = false
	await _setup(index)
	stage.set_hints_visible(OS.get_cmdline_user_args().has("--hints"))
	monitor_view = true
	await _capture("room%d_entrance" % (index+1))
	Input.action_press("move_right",strength)
	_check(is_equal_approx(Input.get_axis("move_left","move_right"),strength),"The live horizontal axis matches the reported strength")
	_release_inputs()
	var started := Engine.get_physics_frames()
	await _entry_begin(strength)
	await _capture("room%d_entrance_mechanic" % (index+1))
	if failed: return
	for frame in 1200:
		if stage.next_bumper >= 3 or respawns > 0: break
		_steer(strength)
		await _step()
	_check(stage.next_bumper == 3 and respawns == 0,"The real entrance mechanic reaches three reflections")
	if failed: return
	await _land_at_wide_rest(strength)
	if failed: return
	await _step(180)
	_check(player.is_on_floor() and respawns == 0,"The actual observation floor permits three seconds of rest")
	await _capture("room%d_main_rest" % (index+1))
	await _repeat_wide_third(strength,delay)
	if failed: return
	await _entry_finish(strength)
	_release_inputs()
	var seconds := float(Engine.get_physics_frames()-started)/60
	print("CANYON_ENTRY_ROOM_",index+1," strength=",strength," delay=",delay," seconds=",seconds," next=",stage.next_bumper," p=",Vector2(_x(),player.position.y)," respawns=",respawns)
	_check((stage.room_index==index+1 and stage.transitioning and respawns==1) if index<26 else (stage.completed and respawns==0),"The entire actual route reaches the exit without dying")
	_check(seconds<30,"The successful retry remains below thirty seconds")
	_check(progress.get_count("canyon")==0,"The actual main route leaves both optional scrolls untouched")
	if index == 26: await _capture("room27_goal")
	monitor_view = false

func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/canyon-entry")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/canyon-entry/%s.png" % label) == OK,"The final native route image is saved")


func _step(count: int = 1) -> void:
	for frame in count:
		await super._step()
		if not monitor_view or not is_instance_valid(stage) or not is_instance_valid(player) or stage.transitioning: continue
		var bodies: Array[CollisionShape2D] = [player.get_node("CollisionShape2D")]
		var held: Grabbable = player.get_held_object()
		if held!=null: bodies.append(held.collider)
		var panels: Array[Control] = [stage.get_node("HUD/Info"),stage.get_node("HUD/PauseButton")]
		var hint: Control = stage.get_node("HUD/Hint")
		if hint.visible:
			panels.append(hint)
			_check(not panels[0].get_global_rect().intersects(hint.get_global_rect()),"The optional hint and persistent information remain separate")
		var card: Control = stage.get_node("HUD/Completion").card
		if card.visible: panels.append(card)
		for shape in bodies:
			var bounds := shape.shape.get_rect()
			bounds.position = shape.get_global_transform_with_canvas()*bounds.position
			_check(root.get_visible_rect().encloses(bounds),"The entire native player and carried object stay inside the viewport")
			for panel in panels:
				_check(not panel.get_global_rect().intersects(bounds),"The moving body remains outside visible HUD panels: "+panel.name)

	if not OS.get_cmdline_user_args().has("--screenshots") or count != 180 or not is_instance_valid(stage) or stage.room_index not in [24,25] or stage.transitioning: return
	var shelf: StaticBody2D = stage.rooms.get_child(stage.room_index).get_node("LateRest")
	for index in player.get_slide_collision_count():
		var contact := player.get_slide_collision(index)
		if contact.get_collider() == shelf and contact.get_normal().dot(Vector2.UP)>0.8:
			await _capture("room%d_late_rest" % (stage.room_index+1))
			break


func _check(ok: bool, message: String) -> void:
	super._check(ok,message)
	if not ok and is_instance_valid(player):
		print("ENTRY_FAIL ",message," index=",stage.room_index," p=",Vector2(_x(),player.position.y)," v=",player.velocity," next=",stage.next_bumper," respawns=",respawns)
