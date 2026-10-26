extends "res://tests/gravity_fifth_route_test.gd"


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_sixth_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	var args := OS.get_cmdline_user_args()
	var rooms := [31,32,33,34,35,36]
	for arg in args:
		if arg.begins_with("--room="):
			var index := int(arg.trim_prefix("--room="))-1
			_check(index in rooms,"Only native rooms32 through37 may be selected")
			rooms = [index]
		else: _check(arg in ["--weak","--timing","--weak-timing","--normal-timing","--hints","--screenshots"],"Use a known sixth-course argument")
	var profiles := [[0.8,20]] if args.has("--weak") else [[1.0,20]]
	if args.has("--timing") or args.has("--weak-timing") or args.has("--normal-timing"):
		profiles = []
		for strength in ([0.8] if args.has("--weak-timing") else ([1.0] if args.has("--normal-timing") else [1.0,0.8])):
			for gap in [16,20,24]: profiles.append([strength,gap])
	for profile in profiles:
		para_strength = profile[0]
		para_gap = profile[1]
		for index in rooms:
			await _sixth_fresh(index)
			await _sixth_course(index)
			_check(progress.get_count("gravity")==0,"The mandatory course leaves all ten native scrolls untouched")
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_SIXTH_ROUTE_TEST_%s %d checks" % ["FAILED" if failed else "OK",checks])
	quit(1 if failed else 0)


func _sixth_fresh(index: int) -> void:
	await _fresh_para(index)
	_sixth_connect()
	Input.action_press("move_right",para_strength)
	_check(is_equal_approx(Input.get_axis("move_left","move_right"),para_strength),"The native course uses the declared direct action axis")
	_release_inputs()


func args_have(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)


func _fifth_capture(name: String) -> void:
	await _sixth_capture(name)


func _sixth_capture(name: String) -> void:
	if name=="room_35_entry_rest":
		var floor: CollisionShape2D = stage.rooms.get_child(34).get_node("LandingFloor/Collision")
		var point := floor.shape.get_rect().end-Vector2(160,floor.shape.get_rect().size.y)
		_sixth_clear_rect(Rect2(floor.get_global_transform_with_canvas()*point,Vector2(160,8)),"The last 160 pixels of the glide landing")
	if name=="room_35_landing_rest":
		_sixth_next_floor("ExitFloor",34)
		for part in ["Base","Case","Cap"]:
			var body: CollisionShape2D = stage.rooms.get_child(34).get_node("Goal/"+part+"/Collision")
			_sixth_clear_rect(Rect2(body.get_global_transform_with_canvas()*body.shape.get_rect().position,body.shape.get_rect().size),"The actual next left Goal "+part)
	if name=="room_36_entry_rest":
		_sixth_next_floor("LandingFloor")
		var arrow: Control = stage.rooms.get_child(35).get_node("DownGate/Arrow")
		_sixth_clear_rect(Rect2(arrow.get_global_transform_with_canvas()*Vector2.ZERO,arrow.size),"The actual next Down arrow")
	if name=="room_36_landing_rest": _sixth_next_floor("ExitFloor")
	if not args_have("--hints"): name += "_plain"
	if not args_have("--screenshots") or captures.has(name): return
	captures[name] = true
	await _step(2)
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/gravity-sixth")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/gravity-sixth/%s.png" % name)==OK,"Save the actual native sixth-course phase")


func _sixth_next_floor(name: String,index := 35) -> void:
	var shape: CollisionShape2D = stage.rooms.get_child(index).get_node(name+"/Collision")
	var bounds := Rect2(shape.get_global_transform_with_canvas()*shape.shape.get_rect().position,Vector2(160,8))
	_sixth_clear_rect(bounds,"The first 160 pixels of the next actual safe floor")


func _sixth_clear_rect(bounds: Rect2,label: String) -> void:
	_check(root.get_visible_rect().encloses(bounds),label+" stays inside the viewport from static rest")
	for panel in [stage.get_node("HUD/Margin/Panel"),stage.get_node("HUD/PauseButton"),stage.get_node("HUD/Status")]:
		_check(not panel.is_visible_in_tree() or not panel.get_global_rect().intersects(bounds),label+" stays outside visible HUD")
