extends "res://tests/corridor_sixth_scroll_test.gd"
func _run() -> void:
	var progress:=root.get_node("CollectionProgress")
	progress.save_path="user://sixth_branch_skip_%d.cfg"%OS.get_process_id()
	progress._collected.clear()
	for section in [30,32,34]:
		var only := -1
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--section="):only=int(arg.trim_prefix("--section="))-1
		if only>=0 and only!=section:continue
		for aim in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			progress._collected.clear()
			await _new_stage()
			await _enter(section)
			await _sixth_branch_touch(section)
			var room: Node2D=stage.rooms.get_child(section)
			var rest: StaticBody2D=room.get_node("ScrollRest")
			var shape: CollisionShape2D=rest.get_node("Collision")
			var floor_rect:=Rect2(rest.position+shape.shape.get_rect().position,shape.shape.get_rect().size)
			_check(await more_flight(floor_rect,false),"The branch shortcut starts on its actual confirmed shelf")
			if section==32:
				room.get_node("Items/DashCrystal").monitoring=false
				room.get_node("Items/DashCrystal/CollisionShape2D").disabled=true
			elif section==34:room.get_node("HighTailwind").wind_acceleration=0
			else:
				room.get_node("Spring").monitoring=false
				room.get_node("Spring/CollisionShape2D").disabled=true
			var target: Rect2=room.walls[1 if section==32 else 2]
			await step(20)
			_check(progress.has_scroll("companion",room.get_node("Scroll").scroll_id),"The genuine optional landing is confirmed before the omission")
			var before:=deaths
			_check(await more_walk(clampf(target.get_center().x,floor_rect.position.x+25,floor_rect.end.x-25)),"Real branch edge launch")
			more_drive(target.get_center().x-_more_x())
			await more_jump()
			await step(20)
			await more_jump()
			await step(20)
			var before_dash: int=actions.get("dash",0)
			_drive(aim)
			await _pulse("dash")
			_check(actions.get("dash",0)>before_dash,"The actual shelf omission executes its directed Dash")
			var reached:=false

			for f in 420:
				more_drive(target.get_center().x-_more_x())
				if player.is_on_wall() and f%12==0:await more_jump()
				await step()
				reached=reached or _on_more_rest(target) or stage.room_index!=section
				if reached or deaths!=before:break
			_check(not reached,"The finite optional-shelf Jump/companion/eight-way Dash comparison does not replace its main resource")
			print("SIXTH_BRANCH_SKIP room=",section+1," aim=",aim," reached=",reached," p=",Vector2(_more_x(),player.position.y)," actions=",actions)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fifth_cleanup()
	print("CORRIDOR_SIXTH_BRANCH_REQUIRED_TEST_OK checks=",checks)
	quit()
