extends "res://tests/corridor_more_required_test.gd"

func _run() -> void:
	var progress:=root.get_node("CollectionProgress")
	progress.save_path="user://corridor_fourth_required_%d.cfg"%OS.get_process_id()
	progress._collected.clear()
	var only := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="): only=int(arg.trim_prefix("--section="))-1
	for entry in [[18,"spring",145,0],[18,"boot",500,1],[19,"boot",430,0],[19,"companion",430,0],[19,"spring",920,1],[20,"bumper",185,0],[20,"boot",1000,1],[20,"companion",1000,1],[21,"up",185,0],[21,"spring",480,2],[22,"wind",218,0],[22,"companion",218,0],[22,"wall",1310,0],[23,"boot",430,0],[23,"companion",430,0]]:
		if only>=0 and entry[0]!=only:continue
		await _new_stage()
		for delay in [12,20,28]:
			for direction in DIRECTIONS:
				await _missing_action(entry[0],entry[1],entry[2],delay,direction,entry[3])
				if failed:return
		print("FOURTH_OMIT room=",entry[0]+1," mode=",entry[1]," cumulative=",trials)
	for section in [19,23]:
		if only<0 or only==section:
			await _new_stage()
			await _companion_steps([section],430)
			if failed:return
	if only<0 or only==22:
		await _new_stage()
		await _companion_steps([22],160)
		if failed:return
	if only<0 or only==18:
		await _new_stage()
		await _spring_without_companion(false,18,670)
		if failed:return
		await _spring_without_companion(true,18,670)
		if failed:return
	if only<0 or only==21:
		await _new_stage()
		await _down_gate_skips(21)
		if failed:return
		await _new_stage()
		for delay in [24,28,32,36,40,44]:
			for direction in DIRECTIONS:
				await _spring_after_down(delay,direction)
				if failed:return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CORRIDOR_FOURTH_REQUIRED_TEST_OK checks=",checks," routes=",trials)
	quit()


func _spring_after_down(delay:int, direction:Vector2)->void:
	await _enter(21)
	var room:Node2D=stage.rooms.get_child(21)
	var launches:Array[bool]=[]
	room.get_node("Spring").launched.connect(func(_body):launches.append(true),CONNECT_ONE_SHOT)
	_check(await more_walk(185) and await more_inverted_rest() and await more_walk(330),"The companion omission really carries through Up and rests on the inverted ceiling")
	more_drive(230-_more_x())
	await more_jump()
	for frame in 300:
		more_drive((480 if player.gravity_direction==1 else 230)-_more_x())
		await step()
		if not launches.is_empty():break
	_check(not launches.is_empty() and player.gravity_direction==1,"The real Down fall activates the native Spring before this comparison")
	if failed:return
	actions.clear()
	var before:=deaths
	var reached:=false
	for frame in 360:
		room.get_node("Items/JumpCreature").consume_extra_jump()
		more_drive(room.walls[2].get_center().x-_more_x())
		if frame==delay:
			_drive(direction)
			await _pulse("dash")
		if player.is_on_wall() and frame%12==0:await more_jump()
		await step()
		reached=reached or _on_more_rest(room.walls[2]) or stage.room_index!=21 or stage.completed
		if deaths!=before or reached:break
	_check(not reached and not actions.has("creature_jump"),"Actual Spring after Down, eight-way Dash and any real wall kick cannot replace the held extra jump: delay=%d direction=%s"%[delay,direction])
	trials+=1
