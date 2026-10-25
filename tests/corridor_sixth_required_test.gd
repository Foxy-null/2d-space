extends "res://tests/corridor_fifth_required_test.gd"

const SIXTH_CASES := [[30,"spring",1,900,2],[31,"boot",0,430,0],[31,"wind",1,1040,1],[32,"bumper",0,185,0],[32,"refill",1,1220,1],[33,"up",0,185,0],[33,"refill",1,730,1],[34,"spring",0,205,0],[34,"wall",1,795,1],[34,"wind",2,1010,2],[35,"boot",0,430,0],[35,"spring",1,1000,1],[35,"bumper",1,1000,1]]

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path="user://corridor_sixth_required_%d.cfg"%OS.get_process_id()
	progress._collected.clear()
	if OS.get_cmdline_user_args().has("--up-return"):
		await _sixth_no_up_return()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		await _required_cleanup()
		print("CORRIDOR_SIXTH_UP_RETURN_TEST_OK checks=",checks," trials=",trials)
		quit()
		return
	if OS.get_cmdline_user_args().has("--down-only"):
		await _sixth_no_down()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		await _required_cleanup()
		print("CORRIDOR_SIXTH_DOWN_TEST_OK checks=",checks," trials=",trials)
		quit()
		return
	var only := -1
	var mode := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="):only=int(arg.trim_prefix("--section="))-1
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	for entry in SIXTH_CASES:
		if only>=0 and only!=entry[0] or not mode.is_empty() and mode!=entry[1]:continue
		await _new_stage()
		for delay in [12,20,28]:
			var selected_delay := -1
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--delay="):selected_delay=int(arg.trim_prefix("--delay="))
			if selected_delay>=0 and selected_delay!=delay:continue
			for direction in DIRECTIONS:
				await _sixth_omit(entry,delay,direction)
				if failed:return
		print("SIXTH_OMIT room=",entry[0]+1," mode=",entry[1]," cumulative=",trials)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	release()
	await _required_cleanup()
	print("CORRIDOR_SIXTH_REQUIRED_TEST_OK checks=",checks," trials=",trials)
	quit()

func _required_cleanup() -> void:
	release()
	if is_instance_valid(stage):stage.queue_free()
	await process_frame
	await process_frame

func _sixth_omit(entry: Array, delay: int, direction: Vector2) -> void:
	var section: int=entry[0]
	var mode: String=entry[1]
	await _enter(section)
	player.wall_actions_enabled=true
	var room: Node2D=stage.rooms.get_child(section)
	if entry[2]>0:_check(await traverse_sixth(section,true),"An omission starts on the actual native rest after the real entrance actions")
	if entry[2]==2:_check(await wide_shaft(room.walls[1]),"The wind omission starts after actual held wall kicks to the shaft top")
	var disabled: Area2D
	if mode in ["boot","refill","up"]:disabled=room.get_node("Items/"+{"boot":"JumpCrystal","refill":"DashCrystal","up":"UpGate"}[mode])
	if mode in ["spring","bumper"]:disabled=room.get_node("Spring" if mode=="spring" else "Bumper")
	if disabled!=null:
		disabled.monitoring=false
		disabled.get_node("CollisionShape2D").disabled=true
	if mode=="wind":room.get_node("HighTailwind").wind_acceleration=0
	if mode=="wall":player.wall_actions_enabled=false
	var spring_used: Array[bool]=[]
	if section==35 and mode=="bumper":room.get_node("Spring").launched.connect(func(body):
		if body==player:spring_used.append(true)
	,CONNECT_ONE_SHOT)
	_check(await more_walk(room.route_x(entry[3])),"The original held companion physically reaches the real launch floor")
	_check(stage._carry_requirement_met(),"The omission launch really carries its original native companion")
	var target: Rect2=room.walls[entry[4]]
	var before:=deaths
	var reached:=false
	actions.clear()
	await more_jump()
	for frame in 360:
		more_drive(target.get_center().x-_more_x())
		if frame==20:await more_jump()
		if frame==delay:
			_drive(Vector2(direction.x*room.travel_direction,direction.y*player.gravity_direction))
			await _pulse("dash")
		if player.is_air_jump_ready() and frame>delay and frame%16==0:await more_jump()
		if mode=="refill" and frame==delay+28 and player.is_dash_ready():
			_drive(Vector2.UP*player.gravity_direction)
			await _pulse("dash")
		if mode!="wall" and player.is_on_wall() and frame%12==0:await more_jump()
		await step()
		reached=reached or _on_more_rest(target) or _on_wide_ceiling(target) or stage.room_index!=section or stage.completed
		if deaths!=before or reached:break
	_check(actions.get("dash",0)>0,"The omission comparison executes an actual Dash after real preparation")
	if section==35 and mode=="bumper":_check(not spring_used.is_empty(),"The no-bumper comparison actually uses the remaining native Spring")
	_check(not reached,"The finite real Jump/companion/Boot/Dash/wall comparison cannot replace the omitted resource: room=%d mode=%s delay=%d aim=%s"%[section+1,mode,delay,direction])
	if mode=="up":_check(player.gravity_direction==1,"The no-Up comparison really retains ordinary gravity")
	if mode=="wall":_check(actions.get("wall_jump",0)==0,"The no-wall comparison really omits wall kicks")
	if disabled!=null:
		disabled.monitoring=true
		disabled.get_node("CollisionShape2D").disabled=false
	if mode=="wind":room.get_node("HighTailwind").wind_acceleration=2500
	player.wall_actions_enabled=true
	trials+=1

func _sixth_no_down() -> void:
	await _new_stage()
	for delay in [16,24,32]:
		for aim in DIRECTIONS:
			await _enter(33)
			var room: Node2D=stage.rooms.get_child(33)
			_check(await traverse_sixth(33,true) and await sixth_ceiling(room,20),"The Down omission physically traverses Up and refill to the second inverted ceiling")
			room.get_node("Items/DownGate").monitoring=false
			room.get_node("Items/DownGate/CollisionShape2D").disabled=true
			_check(await more_walk(1450),"The actual inverted carrier walks to the final ceiling edge")
			var before:=deaths
			more_drive(room.room_width-_more_x())
			await more_jump()
			await step(20)
			await more_jump()
			await step(delay)
			var count: int=actions.get("dash",0)
			_drive(aim)
			await _pulse("dash")
			_check(actions.get("dash",0)>count,"The inverted comparison executes its real directed Dash")
			var advanced:=false
			for frame in 420:
				more_drive(room.room_width-_more_x())
				await step()
				advanced=advanced or stage.room_index!=33 or stage.completed
				if advanced or deaths!=before:break
			_check(not advanced,"The finite inverted carry/Jump/eight-way Dash inputs cannot use roof, floor underside or boundary instead of Down")
			room.get_node("Items/DownGate").monitoring=true
			room.get_node("Items/DownGate/CollisionShape2D").disabled=false
			trials+=1

func _sixth_no_up_return() -> void:
	await _new_stage()
	for delay in [20,44,60]:
		for aim in DIRECTIONS:
			await _enter(33)
			var room: Node2D=stage.rooms.get_child(33)
			room.get_node("Items/UpGate").monitoring=false
			room.get_node("Items/UpGate/CollisionShape2D").disabled=true
			_check(await more_walk(430),"The original companion physically reaches the entrance edge for a no-Up crossing to the later return floor")
			var before:=deaths
			more_drive(room.walls[2].get_center().x-_more_x())
			await more_jump()
			var reached:=false
			for frame in 420:
				more_drive(room.walls[2].get_center().x-_more_x())
				if frame==20:await more_jump()
				if frame==delay:
					_drive(aim)
					await _pulse("dash")
				if player.is_on_wall() and frame%12==0:await more_jump()
				await step()
				reached=reached or _on_more_rest(room.walls[2]) or _on_more_rest(room.walls[3]) or stage.room_index!=33
				if reached or deaths!=before:break
			_check(actions.get("dash",0)>0,"The no-Up return-floor comparison really executes a directed Dash")
			_check(not reached,"The finite normal-gravity Jump/companion/late eight-way Dash inputs cannot bypass both inverted ceilings via the later normal return floor")
			room.get_node("Items/UpGate").monitoring=true
			room.get_node("Items/UpGate/CollisionShape2D").disabled=false
			trials+=1
