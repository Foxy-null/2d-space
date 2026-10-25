extends "res://tests/corridor_more_required_test.gd"

const CASES := [[24,"refill",0,430],[24,"boot",1,700],[24,"companion",1,700],[25,"spring",0,145],[25,"up",1,900],[26,"wall",0,218],[26,"wind",1,480],[27,"bumper",0,185],[27,"up",1,1050],[28,"boot",0,430],[28,"companion",0,430],[28,"bumper",1,1100],[29,"refill",0,430],[29,"spring",1,820]]

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_fifth_required_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	if OS.get_cmdline_user_args().has("--extras"):
		await _extras()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		print("CORRIDOR_FIFTH_EXTRAS_TEST_OK checks=",checks," routes=",trials)
		quit()
		return
	for entry in CASES:
		var only := -1
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--section="): only=int(arg.trim_prefix("--section="))-1
		if only>=0 and only!=entry[0]:continue
		if OS.get_cmdline_user_args().has("--wind-only") and entry[1]!="wind":continue
		if OS.get_cmdline_user_args().has("--remaining") and entry[0]<27:continue
		await _new_stage()
		for delay in ([12,20,28,36,44,52,60] if entry[1]=="wind" else [12,20,28]):
			for direction in DIRECTIONS:
				await _omit(entry,delay,direction)
				if failed:return
		print("FIFTH_OMIT room=",entry[0]+1," mode=",entry[1]," cumulative_routes=",trials)
	if OS.get_cmdline_user_args().has("--steps"):
		await _new_stage()
		await _companion_steps([24],430)
		await _new_stage()
		await _companion_steps([28],1490)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	release()
	print("CORRIDOR_FIFTH_REQUIRED_TEST_OK checks=",checks," routes=",trials)
	quit()

func _omit(entry: Array, delay: int, direction: Vector2) -> void:
	var section: int = entry[0]
	var mode: String = entry[1]
	var phase: int = entry[2]
	await _enter(section)
	player.wall_actions_enabled = true
	var room: Node2D = stage.rooms.get_child(section)
	if phase==1:_check(await traverse_fifth(section,true), "An omission after the first challenge begins on its actual safe native rest")
	var disabled: Area2D
	if mode in ["refill","boot","up"]:disabled=room.get_node("Items/"+{"refill":"DashCrystal","boot":"JumpCrystal","up":"UpGate"}[mode])
	elif mode in ["spring","bumper"]:disabled=room.get_node("Spring" if mode=="spring" else "Bumper")
	if disabled!=null:
		disabled.monitoring=false
		disabled.get_node("CollisionShape2D").disabled=true
	if mode=="wind":room.get_node("HighTailwind").wind_acceleration=0
	if mode=="wall":player.wall_actions_enabled=false
	_check(await more_walk(room.route_x(entry[3])), "The comparison carries the original companion to a real floor launch")
	var target_index := 0 if phase==0 else (2 if mode=="up" else 1)
	var target: Rect2 = room.walls[target_index]
	var creature: Grabbable = room.get_node("Items/JumpCreature")
	var before := deaths
	var reached := false
	actions.clear()
	await more_jump()
	for frame in 360:
		if mode=="companion":creature.consume_extra_jump()
		more_drive(target.get_center().x-_more_x())
		if frame==20 and mode!="companion":await more_jump()
		if frame==delay:
			_drive(direction)
			await _pulse("dash")
		if player.is_air_jump_ready() and frame>delay and frame%16==0:await more_jump()
		if mode=="refill" and frame==delay+28 and player.is_dash_ready():
			_drive(Vector2.UP)
			await _pulse("dash")
		if mode!="wall" and player.is_on_wall() and frame%12==0:await more_jump()
		await step()
		reached=reached or _on_more_rest(target) or stage.room_index!=section or stage.completed
		if deaths!=before or reached:break
	_check(not reached, "The omitted native action cannot be replaced by normal/companion jumps, boots if available, eight-way Dash or wall kicks: room=%d mode=%s delay=%d direction=%s"%[section+1,mode,delay,direction])
	if mode=="companion":_check(not actions.has("creature_jump"), "The physical comparison omits the carried extra jump")
	if mode=="wall":_check(not actions.has("wall_jump") and not actions.has("climb"), "The physical shaft comparison really omits wall actions")
	if mode=="up":_check(player.gravity_direction==1, "The no-Up comparison really retains normal gravity")
	if disabled!=null:
		disabled.monitoring=true
		disabled.get_node("CollisionShape2D").disabled=false
	if mode=="wind":room.get_node("HighTailwind").wind_acceleration=3500
	player.wall_actions_enabled=true
	trials+=1


func _extras() -> void:
	await _new_stage()
	for section in [25,27]:
		for delay in [12,20,28,36,44]:
			for aim in [Vector2.DOWN,Vector2(1,1),Vector2.RIGHT,Vector2.UP]:
				await _enter(section)
				var room: Node2D = stage.rooms.get_child(section)
				_check(await traverse_fifth(section,true) and await fifth_invert(room), "The no-Down route starts on its real inverted ceiling after the actual Spring or bumper")
				_check(await more_walk(room.route_x(1230 if section==25 else 1280)), "The carrier reaches the actual ceiling edge away from Down")
				var before := deaths
				more_drive(room.route_x(room.room_width-15)-_more_x())
				await more_jump()
				await step(20)
				await more_jump()
				await step(delay)
				_drive(Vector2(aim.x*room.travel_direction,aim.y))
				await _pulse("dash")
				var advanced := false
				for frame in 360:
					more_drive(room.route_x(room.room_width-15)-_more_x())
					await step()
					advanced=advanced or stage.room_index!=section or stage.completed
					if deaths!=before or advanced:break
				_check(not advanced and (player.gravity_direction==-1 or deaths==before+1), "Inverted Jump, companion Jump and actual Dash cannot use the one-way exit underside or outer wall instead of Down")
				trials+=1
	await _new_stage()
	for delay in [12,20,28]:
		for aim in DIRECTIONS:
			await _enter(28)
			var room: Node2D = stage.rooms.get_child(28)
			_check(await traverse_fifth(28,true) and await more_walk(room.route_x(1100)), "The raised bumper omission physically carries through boots to a moved position on the actual first rest")
			var creature: Grabbable = room.get_node("Items/JumpCreature")
			release()
			await step(30)
			await more_jump()
			for frame in 120:
				release()
				steer_to(creature.position.x-_more_x())
				await step()
				if player.is_on_floor() and player.position.y<room.walls[0].position.y-60:break
			var supported := false
			for index in player.get_slide_collision_count():supported=supported or player.get_slide_collision(index).get_collider()==creature
			_check(supported and player.get_held_object()==null, "The moved real companion physically supports the raised launch")
			room.get_node("Bumper").monitoring=false
			room.get_node("Bumper/CollisionShape2D").disabled=true
			actions.clear()
			_hold()
			await more_jump()
			_check(player.get_held_object()==creature and actions.get("jump",0)==1, "Simultaneous Grab/Jump really leaves the companion's back")
			var before := deaths
			var reached := false
			for frame in 360:
				more_drive(room.walls[1].get_center().x-_more_x())
				if frame==20:await more_jump()
				if frame==delay:
					_drive(aim)
					await _pulse("dash")
				await step()
				reached=reached or _on_more_rest(room.walls[1]) or stage.room_index!=28 or stage.completed
				if deaths!=before or reached:break
			_check(not reached, "The moved companion step, normal/extra Jump and eight-way Dash cannot replace the actual second bumper")
			room.get_node("Bumper").monitoring=true
			room.get_node("Bumper/CollisionShape2D").disabled=false
			trials+=1
