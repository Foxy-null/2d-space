extends "res://tests/corridor_sixth_required_test.gd"

func _run() -> void:
	var progress:=root.get_node("CollectionProgress")
	progress.save_path="user://corridor_sixth_alt_%d.cfg"%OS.get_process_id()
	progress._collected.clear()
	if OS.get_cmdline_user_args().has("--throws-only"):
		await _sixth_throws()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		await _required_cleanup()
		print("CORRIDOR_SIXTH_THROWS_TEST_OK checks=",checks," trials=",trials)
		quit()
		return
	for section in [31,35]:
		var only := -1
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--section="):only=int(arg.trim_prefix("--section="))-1
		if only>=0 and only!=section:continue
		await _new_stage()
		for delay in [20,28,36]:
			for aim in DIRECTIONS:
				await _sixth_support(section,delay,aim)
				if failed:return
	print("CORRIDOR_SIXTH_ALTERNATIVE_TEST_OK checks=",checks," trials=",trials)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _required_cleanup()
	quit()

func _sixth_support(section: int, delay: int, aim: Vector2) -> void:
	await _enter(section)
	var room: Node2D=stage.rooms.get_child(section)
	var creature: Grabbable=room.get_node("Items/JumpCreature")
	room.get_node("Items/JumpCrystal").monitoring=false
	room.get_node("Items/JumpCrystal/CollisionShape2D").disabled=true
	_check(await more_walk(room.route_x(430)),"The real original companion is physically moved to the comparison launch")
	release()
	await step(40)
	_check(creature.carrier==null and absf(creature.linear_velocity.y)<20,"The actual moved object rests on the native entrance")
	await more_jump()
	for frame in 150:
		release()
		steer_to(creature.position.x-_more_x())
		await step()
		if player.is_on_floor() and player.position.y<room.entrance_top-60:break
	var supported:=false
	for index in player.get_slide_collision_count():supported=supported or player.get_slide_collision(index).get_collider()==creature
	_check(supported and player.get_held_object()==null,"The real free companion physically supports the raised launch")
	var before:=deaths
	actions.clear()
	_hold()
	await more_jump()
	_check(player.get_held_object()==creature and actions.get("jump",0)==1,"Simultaneous Grab/Jump really leaves the actual companion back")
	var reached:=false
	for frame in 360:
		more_drive(room.walls[0].get_center().x-_more_x())
		if frame==16:await more_jump()
		if frame==delay:
			_drive(Vector2(aim.x*room.travel_direction,aim.y))
			await _pulse("dash")
		if player.is_on_wall() and frame%12==0:await more_jump()
		await step()
		reached=reached or _on_more_rest(room.walls[0]) or stage.room_index!=section or stage.completed
		if reached or deaths!=before:break
	_check(actions.get("creature_jump",0)>0 and actions.get("dash",0)>0 and not player.is_air_jump_ready(),"The no-Boot comparison really uses its carried extra jump and directed Dash")
	_check(not reached,"The finite real raised companion support cannot replace the native Boot")
	room.get_node("Items/JumpCrystal").monitoring=true
	room.get_node("Items/JumpCrystal/CollisionShape2D").disabled=false
	trials+=1

func _sixth_throws() -> void:
	await _new_stage()
	var climbs:=0
	for raised in [false,true]:
		for side in [-1,1]:
			for delay in [0,4,8]:
				await _enter(34)
				var room: Node2D=stage.rooms.get_child(34)
				_check(await traverse_sixth(34,true),"The throw comparison physically passes Spring and reaches the actual first rest with its companion")
				var creature: Grabbable=room.get_node("Items/JumpCreature")
				_check(await more_walk(room.route_x(780)),"The actual throw launch settles between the opposing walls")
				_hold()
				await step(20)
				if raised:
					release()
					await step(40)
					await more_jump()
					for frame in 150:
						release()
						steer_to(creature.position.x-_more_x())
						await step()
						if player.is_on_floor() and player.position.y<room.walls[0].position.y-60:break
					var supported:=false
					for index in player.get_slide_collision_count():supported=supported or player.get_slide_collision(index).get_collider()==creature
					_check(supported and player.get_held_object()==null,"The raised throw really starts from the moved companion back")
				if raised:
					for frame in 90:
						release()
						steer_to(creature.position.x-10-_more_x())
						await step()
						if absf(creature.position.x-10-_more_x())<6:break
					release()
					await step(12)
					var back_contact:=false
					for index in player.get_slide_collision_count():back_contact=back_contact or player.get_slide_collision(index).get_collider()==creature
					print("SIXTH_BACK p=",Vector2(_more_x(),player.position.y)," object=",creature.position)
					_check(back_contact and player.get_held_object()==null,"The real supported carrier settles away from the wall before grabbing and throwing")
				var launch_speeds: Array[Vector2]=[]
				player.object_released.connect(func(body,thrown):
					if body==creature and thrown:launch_speeds.append(creature.linear_velocity)
				,CONNECT_ONE_SHOT)
				actions.clear()
				_hold()
				more_drive(0)
				await more_jump()
				await step(20)
				await more_jump()
				await step(20)
				_check(actions.get("creature_jump",0)==1 and actions.get("wall_jump",0)==0 and player.get_held_object()==creature,"The preparation actually uses a companion jump without a wall kick")
				release()
				Input.action_press("wall_grab")
				Input.action_press("move_up")
				await more_dash()
				await step(delay)
				Input.action_release("wall_grab")
				await step()
				print("SIXTH_THROW_COMPARE raised=",raised," side=",side," delay=",delay," speeds=",launch_speeds," p=",Vector2(_more_x(),player.position.y))
				_check(creature.carrier==null and launch_speeds.size()==1 and launch_speeds[0].y< -100 and creature.release_physics_frame>=Engine.get_physics_frames()-2,"The original real companion is actually thrown upward after the carried jump and Dash")
				var before:=deaths
				for frame in 16:
					release()
					Input.action_press("move_right" if side>0 else "move_left",steering_strength)
					await step()
				var reached:=false
				var climbed:=false
				for frame in 420:
					release()
					Input.action_press("wall_grab")
					Input.action_press("move_up")
					steer_to(side*100)
					await step()
					climbed=climbed or player.is_wall_grabbing() and player.velocity.y< -100 and player.get_held_object()==null
					reached=reached or _on_more_rest(room.walls[1]) and player.get_held_object()==creature
					if reached or deaths!=before:break
				_check(not reached and actions.get("wall_jump",0)==0,"These finite actual support/throw/bare-climb inputs cannot recover the same companion on the shaft top without wall kicks")
				climbs+=int(climbed)
				trials+=1
	_check(climbs>0,"The throw comparisons contain actual upward bare climbing")
