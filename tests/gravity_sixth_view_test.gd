extends "res://tests/gravity_sixth_route_test.gd"

func _run() -> void:
	for arg in OS.get_cmdline_user_args(): _check(arg=="--screenshots","Use a known view-test argument")
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_sixth_view_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	await _sixth_fresh(32)
	await _sixth_entry(32)
	await _para_walk(1690)
	await _jump()
	await _step(para_gap)
	_para_drive(1760)
	await _until(func(): return actions.get("sixth_launch",0)>0,120,"Use the actual circular bumper")
	_para_drive(800)
	await _until(func(): return _fifth_floor("LandingCeiling"),240,"Land on the real left ceiling")
	await _para_walk(800)
	await _fifth_rest("landing_rest")
	var arrow: Control = stage.rooms.get_child(32).get_node("DownGate/Arrow")
	var resting := player.position
	for hints in [true,false]:
		stage.set_hints_visible(hints)
		var low := INF
		var high := -INF
		var gate: Area2D = stage.rooms.get_child(32).get_node("DownGate")
		var gate_low := INF
		var gate_high := -INF
		var saved := {}
		for frame in 360:
			await _step()
			var bounds := Rect2(arrow.get_global_transform_with_canvas()*Vector2.ZERO,arrow.size)
			_sixth_clear_rect(bounds,"The whole moving Down Arrow throughout a full phase cycle")
			_check(player.is_on_floor() and player.gravity_direction==-1 and player.position.distance_to(resting)<2,"Observe the actual moving target from the unchanged static ceiling")
			gate_low=minf(gate_low,gate.position.y)
			gate_high=maxf(gate_high,gate.position.y)
			low=minf(low,bounds.position.y)
			high=maxf(high,bounds.end.y)
			if OS.get_cmdline_user_args().has("--screenshots"):
				var phase := "high" if gate.position.y<801 else ("low" if gate.position.y>979 else "")
				if not phase.is_empty() and not saved.has(phase):
					saved[phase]=true
					RenderingServer.force_draw()
					DirAccess.make_dir_recursive_absolute("res://docs/screenshots/gravity-sixth")
					_check(root.get_texture().get_image().save_png("res://docs/screenshots/gravity-sixth/room_33_down_%s_%s.png"%[phase,"hints" if hints else "plain"])==OK,"Save the actual moving Arrow phase")
		_check(gate_high-gate_low>179,"Observe both actual endpoints across more than one complete gate cycle")
		print("ARROW_CYCLE hints=",hints," y=",low,"..",high)
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_SIXTH_VIEW_TEST_%s %d checks"%["FAILED" if failed else "OK",checks])
	quit(1 if failed else 0)
