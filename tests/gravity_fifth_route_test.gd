extends "res://tests/gravity_parachute_route_test.gd"


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_fifth_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	var args := OS.get_cmdline_user_args()
	var rooms := [25,26,27,28,29,30]
	for arg in args:
		if arg.begins_with("--room="):
			var index := int(arg.trim_prefix("--room="))-1
			_check(index in rooms, "Only native rooms 26 through 31 may be selected")
			rooms = [index]
	var profiles := [[0.8,20]] if args.has("--weak") else [[1.0,20]]
	if args.has("--timing") or args.has("--weak-timing") or args.has("--normal-timing"):
		profiles = []
		for axis in ([0.8] if args.has("--weak-timing") else ([1.0] if args.has("--normal-timing") else [1.0,0.8])):
			for gap in [16,20,24]: profiles.append([axis,gap])
	for profile in profiles:
		para_strength = profile[0]
		para_gap = profile[1]
		for index in rooms:
			await _fresh_para(index)
			_fifth_connect()
			Input.action_press("move_right",para_strength)
			_check(is_equal_approx(Input.get_axis("move_left","move_right"),para_strength), "The real action axis matches the declared strength")
			_release_inputs()
			await _fifth_course(index)
			if index==30:
				_check(not stage.completed,"The former room31 final remains an intermediate arrival")
				_para_drive(2350)
				await _until(func(): return stage.room_index==31,180,"The former final physically transfers into native room32")
				_release_inputs()
				await _step(25)
				_check(player.position.distance_to(stage.rooms.get_child(31).get_node("Spawn").global_position)<5 and player.gravity_direction==1 and player.controls_enabled,"The real old31/new32 seam settles at the next checkpoint")
			_check(progress.get_count("gravity") == 0, "The mandatory route leaves all optional scrolls untouched")
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_FIFTH_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK",checks])
	quit(1 if failed else 0)


func _para_capture(name: String) -> void:
	await _fifth_capture(name)


func _fifth_capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots") or captures.has(name): return
	captures[name] = true
	await _step(2)
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/gravity-fifth")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/gravity-fifth/%s.png" % name) == OK, "Save the native input phase")
