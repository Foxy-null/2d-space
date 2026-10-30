extends "res://tests/corridor_more_test.gd"

func _run() -> void:
	root.get_node("CollectionProgress").save_path="user://corridor_capture_%d.cfg"%OS.get_process_id()
	root.get_node("CollectionProgress")._collected.clear()
	var section:=11
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):section=int(arg.trim_prefix("--room="))-1
	_check(section>=9 and section<15,"Capture a real new room")
	await _new_stage()
	await _enter(section)
	if OS.get_cmdline_user_args().has("--branch"):
		await _new_branch_touch(section)
		await _more_capture("room%d_scroll"%(section+1))
		var room: Node2D=stage.rooms.get_child(section)
		var rest: StaticBody2D=room.get_node("ScrollRest")
		var collider: CollisionShape2D=rest.get_node("Collision")
		var rect:=Rect2(rest.position+collider.shape.get_rect().position,collider.shape.get_rect().size)
		_check(await more_flight(rect,false),"The drawn branch lands on its real shelf")
		_hold()
		await step(180)
		await _more_capture("room%d_scroll_rest"%(section+1))
		_check(await more_transfer(room.walls[1]),"The drawn branch rejoins the same main rest")
		await _more_capture("room%d_scroll_return"%(section+1))
	else:
		_check_mechanic_view(section)
		await _more_capture("room%d_entrance"%(section+1))
		_check(await traverse(section,true),"Draw the real input route to the first rest")
		_hold()
		await step(180)
		await _more_capture("room%d_rest"%(section+1))
		if not OS.get_cmdline_user_args().has("--rest-only"):
			_check(await traverse(section),"The drawn room resumes from rest to the next checkpoint")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.get_node("CollectionProgress").save_path))
	print("CORRIDOR_MORE_CAPTURE_%s room=%d checks=%d"%["FAILED" if failed else "OK",section+1,checks])
	quit(1 if failed else 0)
