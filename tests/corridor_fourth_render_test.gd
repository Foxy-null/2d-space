extends "res://tests/corridor_fourth_scroll_test.gd"

func _run() -> void:
	screenshot_mode = true
	observe_fourth_view = true
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_fourth_render_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	for section in range(18, 24):
		await _new_stage()
		await _enter(section)
		await _wide_capture("room%d_entrance" % (section + 1))
		_check(await traverse_fourth(section, true), "The captured entrance reaches its real first rest")
		_hold()
		await step(200)
		await _wide_capture("room%d_rest" % (section + 1))
		var room: Node2D = stage.rooms.get_child(section)
		if section in [18, 20, 23]:
			_check(await more_combo(800 if section == 23 else (500 if section == 18 else 1000), room.walls[1], 20), "The captured upper shelf uses the actual boots route")
		elif section == 19:
			_check(await fourth_spring(920, room.walls[1], 20), "The captured upper shelf uses the actual Spring route")
		elif section == 22:
			_check(await more_walk(1310) and await wide_shaft(room.walls[1]), "The captured wall top uses actual held wall kicks")
		else:
			_check(await more_walk(330), "The captured inverted view begins on its real ceiling")
		_hold()
		await step(20)
		await _wide_capture("room%d_upper" % (section + 1))
		_check(await traverse_fourth(section), "The rendered course physically rejoins its exit")
		if section == 23: await _wide_capture("room24_green_exit")
		if failed: return
	for section in [19, 22]:
		await _wide_scroll(section, progress)
		if failed: return
	await _new_stage()
	await _enter(23)
	_check(await traverse_fourth(23, true) and await fourth_choose_red(), "The rendered choice acquires the actual local red companion")
	_hold()
	await step(20)
	await _wide_capture("room24_red_choice")
	stage.set_hints_visible(true)
	await step()
	await _wide_capture("room24_red_hint")
	stage.set_hints_visible(false)
	_check(await fourth_spring(1100, stage.rooms.get_child(23).walls[2], 20, false), "The real selected parachute reaches its upper rest by Spring")
	_hold()
	await step(200)
	await _wide_capture("room24_red_rest")
	_check(await more_transfer(stage.rooms.get_child(23).walls[3]), "The rendered parachute crosses the actual wind to its right landing")
	_hold()
	await step(20)
	await _wide_capture("room24_red_wind_return")
	_check(await more_walk(stage.rooms.get_child(23).room_width - 230), "The rendered parachute reaches the actual final approach")
	more_drive(0)
	await more_jump()
	await step(20)
	release()
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await more_dash()
	await step(15)
	_check(await more_flight(Rect2(2530, 700, 45, 24), false, true) and stage.room_index==24 and not stage.completed, "The captured red alternative activates the real next checkpoint")
	await _wide_capture("room24_red_exit")
	observe_fourth_view = false
	release()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fourth_cleanup()
	print("CORRIDOR_FOURTH_RENDER_TEST_OK checks=", checks)
	quit()


func _wide_capture(label: String) -> void:
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/corridor-fourth")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/corridor-fourth/%s.png" % label) == OK, "The actual native rendering is saved")
