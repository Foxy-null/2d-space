extends "res://tests/corridor_fourth_route_test.gd"

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path="user://corridor_fourth_scroll_%d.cfg"%OS.get_process_id()
	progress._collected.clear()
	for strength in ([1.0] if OS.get_cmdline_user_args().has("--strong") else [1.0,0.8]):
		steering_strength=strength
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for section in [19,22]:
			await _wide_scroll(section,progress)
			if failed:return
	observe_fourth_view=false
	if OS.get_cmdline_user_args().has("--keep-fixture"):
		print("CORRIDOR_FOURTH_SAVED_PATH ",progress.save_path)
	else:DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fourth_cleanup()
	print("CORRIDOR_FOURTH_SCROLL_TEST_OK checks=",checks)
	quit()

func _wide_branch_touch(section: int) -> void:
	observe_fourth_view=true
	_check(await traverse_fourth(section,true),"The real new entrance reaches its optional branch approach")
	if failed:return
	var room:Node2D=stage.rooms.get_child(section)
	if section==19:
		_check(await fourth_spring(920,room.walls[1],20),"The left branch begins after the actual boots and Spring on the upper shelf")
	else:
		_check(await more_walk(1310) and await wide_shaft(room.walls[1]),"The upper branch begins after the actual wind and carried wall kicks")
	if failed:return
	_hold()
	await step(20)
	var scroll:Area2D=room.get_node("Scroll")
	var scroll_bounds := Rect2(root.get_canvas_transform() * scroll.global_position - Vector2(16, 20), Vector2(32, 40))
	_check(root.get_visible_rect().encloses(scroll_bounds) and not stage.get_node("HUD/Info").get_global_rect().intersects(scroll_bounds), "The actual optional scroll is visible from its settled upper approach")
	var marker: Node2D = room.get_node("ScrollMark")
	var mark_bounds: Rect2 = marker.get_global_transform_with_canvas() * Rect2(-16, -20, 32, 40)
	_check(root.get_visible_rect().encloses(mark_bounds) and not stage.get_node("HUD/Info").get_global_rect().intersects(mark_bounds), "The subtle native branch marker remains visible before choosing the detour")
	more_drive(scroll.position.x-_more_x())
	await more_jump()
	var cooldown:=12
	for frame in 360:
		if scroll._follower==player:return
		more_drive(scroll.position.x-_more_x())
		cooldown=maxi(0,cooldown-1)
		if player.velocity.y>-40 and cooldown==0:
			if player.get_available_extra_jump_count()>0:
				Input.action_press("jump")
				cooldown=12
			elif player.is_dash_ready():
				Input.action_press("move_up")
				Input.action_press("dash")
				cooldown=12
		await step()
	_check(false,"The actual input reaches the new optional airborne scroll")

func _wide_fall(pending:=false)->void:
	observe_fourth_view=false
	await super._wide_fall(pending)
	observe_fourth_view=true
