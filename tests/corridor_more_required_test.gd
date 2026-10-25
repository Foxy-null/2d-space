extends "res://tests/corridor_more_test.gd"

const DIRECTIONS := [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]
var trials := 0

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path="user://corridor_more_required_%d.cfg"%OS.get_process_id()
	progress._collected.clear()
	await _new_stage()
	if OS.get_cmdline_user_args().has("--down-only"):
		await _down_gate_skips()
		print("CORRIDOR_MORE_DOWN_TEST_%s (%d checks, %d routes)"%["FAILED" if failed else "OK",checks,trials])
		quit(1 if failed else 0)
		return
	if OS.get_cmdline_user_args().has("--spring-step-only"):
		await _spring_without_companion(true)
		print("CORRIDOR_MORE_SPRING_STEP_TEST_%s (%d checks, %d routes)"%["FAILED" if failed else "OK",checks,trials])
		quit(1 if failed else 0)
		return
	if OS.get_cmdline_user_args().has("--spring-only"):
		await _spring_without_companion()
		print("CORRIDOR_MORE_SPRING_TEST_%s (%d checks, %d routes)"%["FAILED" if failed else "OK",checks,trials])
		quit(1 if failed else 0)
		return
	if OS.get_cmdline_user_args().has("--step-only"):
		await _companion_steps()
		print("CORRIDOR_MORE_STEP_TEST_%s (%d checks, %d routes)"%["FAILED" if failed else "OK",checks,trials])
		quit(1 if failed else 0)
		return
	if OS.get_cmdline_user_args().has("--rest-only"):
		await _rest_skips()
		print("CORRIDOR_MORE_REST_TEST_%s (%d checks, %d routes)"%["FAILED" if failed else "OK",checks,trials])
		quit(1 if failed else 0)
		return
	for section in range(9,15):
		for mode in (["boot","companion"] if section in [9,12] else ["required"]):
			for launch in ([430,475] if section==9 else ([930,1000] if section==12 else [185,218])):
				for delay in [12,20,28]:
					for direction in DIRECTIONS:
						await _missing_action(section,mode,launch,delay,direction)
						if failed:return
		print("CORRIDOR_MORE_REQUIRED_ROOM_%d %d cumulative routes"%[section+1,trials])
	# The omission comparisons deliberately disable native areas; later routes start fresh.
	await _new_stage()
	await _rest_skips()
	if failed:return
	await _companion_steps()
	if failed:return
	await _spring_without_companion()
	if failed:return
	await _down_gate_skips()
	if failed:return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CORRIDOR_MORE_REQUIRED_TEST_%s (%d checks, %d routes)"%["FAILED" if failed else "OK",checks,trials])
	quit(1 if failed else 0)


func _missing_action(section: int, mode: String, launch: float, delay: int, direction: Vector2) -> void:
	await _enter(section)
	var room: Node2D=stage.rooms.get_child(section)
	player.wall_actions_enabled=section!=13
	var spring_hits: Array[bool]=[]
	if section==11:
		room.get_node("Spring").monitoring=false
		room.get_node("Spring/CollisionShape2D").disabled=true
		room.get_node("Spring").launched.connect(func(_body):spring_hits.append(true),CONNECT_ONE_SHOT)
	if section==12:
		_check(await island_leap(20,20,1.0,section),"The second transfer comparison reaches its real wind island")
	_check(await more_walk(launch),"The comparison carries the original companion to a real floor launch")
	var creature: Grabbable=room.get_node("Items/JumpCreature")
	if mode=="boot":
		var boot: Area2D=room.get_node("Items/JumpCrystal")
		boot.monitoring=false
		boot.get_node("CollisionShape2D").disabled=true
	elif section==10:
		var gate: Area2D=room.get_node("Items/UpGate")
		gate.monitoring=false
		gate.get_node("CollisionShape2D").disabled=true
	actions.clear()
	var before:=deaths
	var target: Rect2=room.walls[1 if section==12 else 0]
	var reached:=false
	await more_jump()
	for frame in 300:
		if mode=="companion" or section==14: creature.consume_extra_jump()
		if frame==20 and mode!="companion" and section!=14: await more_jump()
		more_drive(target.get_center().x-_more_x())
		if frame==delay:
			_hold()
			if direction.x!=0:Input.action_press("move_right" if direction.x>0 else "move_left")
			if direction.y!=0:Input.action_press("move_down" if direction.y>0 else "move_up")
			await _pulse("dash")
		if frame>delay and player.is_air_jump_ready() and frame%20==0: await more_jump()
		if player.is_on_wall() and section!=13 and frame%12==0: await more_jump()
		await step()
		reached=reached or _on_more_rest(target)
		if deaths!=before or stage.room_index!=section or stage.completed:break
	_check(not reached and stage.room_index==section and not stage.completed,"Required action cannot be replaced by normal jumps and eight-way Dash: room=%d mode=%s launch=%d delay=%d direction=%s"%[section+1,mode,launch,delay,direction])
	if mode=="companion" or section==14:_check(not actions.has("creature_jump"),"The negative route really omits the companion jump")
	if section==13:_check(not actions.has("wall_jump"),"The shaft comparison really omits wall kicks")
	if section==11:
		_check(spring_hits.is_empty(),"The no-spring comparison really omits its launch")
		room.get_node("Spring").monitoring=true
		room.get_node("Spring/CollisionShape2D").disabled=false
	trials+=1


func _rest_skips() -> void:
	for section in [9,11,12,14]:
		for delay in [12,20,28]:
			for direction in DIRECTIONS:
				await _enter(section)
				_check(await traverse(section,true),"A rest shortcut starts from its real entrance and actual first landing")
				var room: Node2D=stage.rooms.get_child(section)
				if section==12:_check(await more_combo(930,room.walls[1],20),"The upper shortcut starts after the actual boot transfer")
				var target: Rect2=room.walls[2] if section in [9,11,14] else Rect2(1160,room.exit_top,120,40)
				var before:=deaths
				more_drive(target.get_center().x-_more_x())
				await more_jump()
				var reached:=false
				for frame in 300:
					more_drive(target.get_center().x-_more_x())
					if frame==20:await more_jump()
					if frame==delay:
						_drive(direction)
						await _pulse("dash")
					await step()
					reached=reached or _on_more_rest(target) or stage.transitioning or stage.completed
					if deaths!=before or (player.is_on_floor() and frame>30):break
				_check(not reached and stage.room_index==section,"A safe rest cannot skip the next high transfer with ordinary Jump, companion Jump and eight-way Dash: room=%d delay=%d direction=%s"%[section+1,delay,direction])
				trials+=1
		print("CORRIDOR_MORE_REST_SKIP_ROOM_%d complete"%(section+1))


func _companion_steps() -> void:
	for section in [9,14]:
		for delay in [12,20,28]:
			for direction in DIRECTIONS:
				await _enter(section)
				var room: Node2D=stage.rooms.get_child(section)
				var creature: Grabbable=room.get_node("Items/JumpCreature")
				release()
				await more_jump()
				for frame in 120:
					release()
					steer_to(175-_more_x())
					await step()
					if player.is_on_floor() and player.position.y<room.entrance_top-60:break
				release()
				await step(3)
				var supported:=false
				for index in player.get_slide_collision_count():supported=supported or player.get_slide_collision(index).get_collider()==creature
				_check(supported and player.get_held_object()==null,"The raised shortcut physically stands on the free companion")
				if failed:return
				actions.clear()
				_hold()
				await more_jump()
				_check(player.get_held_object()==creature and actions.get("jump",0)==1,"Simultaneous Grab/Jump really lifts the companion from its back")
				var before:=deaths
				var reached:=false
				for frame in 300:
					creature.consume_extra_jump()
					more_drive(room.walls[0].get_center().x-_more_x())
					if frame==delay:
						_drive(direction)
						await _pulse("dash")
					if player.is_air_jump_ready() and player.velocity.y>-40:await more_jump()
					if player.is_on_wall() and frame%12==0:await more_jump()
					await step()
					reached=reached or _on_more_rest(room.walls[0]) or stage.transitioning or stage.completed
					if deaths!=before:break
				_check(not reached and not actions.has("creature_jump"),"The physical step, boot if reachable and eight-way Dash cannot replace the companion jump: room=%d delay=%d direction=%s"%[section+1,delay,direction])
				trials+=1
		print("CORRIDOR_MORE_STEP_ROOM_%d complete"%(section+1))


func _spring_without_companion(stepped: bool = false) -> void:
	for delay in ([24,28,32,36,40,44,48,52] if stepped else [24,32,36,40,44,48]):
		await _enter(11)
		var room: Node2D=stage.rooms.get_child(11)
		var launches: Array[Vector2]=[]
		var callback=func(_body):launches.append(Vector2(_more_x(),player.position.y))
		room.get_node("Spring").launched.connect(callback)
		if stepped:
			var creature: Grabbable=room.get_node("Items/JumpCreature")
			release()
			await more_jump()
			for frame in 120:
				release()
				steer_to(175-_more_x())
				await step()
				if player.is_on_floor() and player.position.y<room.entrance_top-60:break
			release()
			await step(3)
			var supported:=false
			for index in player.get_slide_collision_count():supported=supported or player.get_slide_collision(index).get_collider()==creature
			_check(supported,"The Spring shortcut physically stands on the free companion")
			actions.clear()
			_hold()
			await more_jump()
			_check(player.get_held_object()==creature and actions.get("jump",0)==1,"Normal Jump and Grab lift the companion from its back before Spring")
		else:
			_check(await more_walk(145),"Approach the spring on the real entrance before its trigger")
			more_drive(205-_more_x())
			await more_jump()
		for frame in 180:
			room.get_node("Items/JumpCreature").consume_extra_jump()
			more_drive(205-_more_x())
			await step()
			if not launches.is_empty():break
		_check(not launches.is_empty(),"A real normal jump falls onto the active Spring")
		var before:=deaths
		var reached:=false
		for frame in 300:
			room.get_node("Items/JumpCreature").consume_extra_jump()
			more_drive(570-_more_x())
			if frame==delay:
				_drive(Vector2.UP)
				await _pulse("dash")
			await step()
			reached=reached or _on_more_rest(room.walls[0])
			if deaths!=before:break
		_check(not reached and not actions.has("creature_jump"),"Falling onto Spring and upper Dash near its apex cannot replace the held companion's extra jump: delay=%d"%delay)
		room.get_node("Spring").launched.disconnect(callback)
		trials+=1


func _down_gate_skips() -> void:
	for gap in [12,20,28,36,44]:
		for aim in [Vector2.DOWN,Vector2(1,1),Vector2.RIGHT,Vector2.UP]:
			await _enter(10)
			_check(await more_walk(185),"The inversion comparison carries the original companion from the actual entrance")
			_check(await more_inverted_rest(),"The inversion comparison really lands on the ceiling rest")
			_check(await more_walk(650),"Walk to the actual ceiling's right edge before trying to omit DownGate")
			var before:=deaths
			more_drive(1200-_more_x())
			await more_jump()
			await step(20)
			await more_jump()
			await step(gap)
			_drive(aim)
			await _pulse("dash")
			var advanced:=false
			for frame in 360:
				advanced=advanced or stage.room_index!=10
				if advanced or deaths!=before:break
				more_drive(1268-_more_x())
				await step()
			_check(not advanced and stage.room_index==10,"Inverted Jump, companion Jump and Dash cannot land under the exit and omit DownGate: gap=%d aim=%s"%[gap,aim])
			if failed:return
			trials+=1
