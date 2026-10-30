extends "res://tests/corridor_sixth_route_test.gd"

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_sixth_retry_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	for section in range(30,36):
		observe_sixth_view=false
		await _new_stage()
		await _enter(section)
		stage.set_hints_visible(true)
		observe_sixth_view=true
		_check(await traverse_sixth(section,true), "The retry starts after the real first native operation")
		var before := deaths
		await _pulse("reset")
		release()
		await step(6)
		_check(deaths==before+1, "R causes exactly one real reset")
		_restored(section)
		observe_sixth_view=false
		var room: Node2D = stage.rooms.get_child(section)
		var hits: Array[bool] = []
		room.get_node("Hazards/LeftEdgeSpikes").player_hit.connect(func():hits.append(true),CONNECT_ONE_SHOT)
		before=deaths
		_drive(Vector2.LEFT*room.travel_direction+(Vector2.UP if room.travel_direction==-1 else Vector2.ZERO))
		await _pulse("dash")
		for frame in 180:
			if deaths!=before:break
			await step()
		release()
		await step(6)
		_check(deaths==before+1 and hits.size()==1, "Actual movement into the native visible spike causes one contact death")
		_restored(section)
		if room.travel_direction == -1:
			for outside in [-80, room.room_width+80]:
				before=deaths
				player.position.x=room.position.x+outside
				await step(6)
				_check(deaths==before+1, "Both actual out-of-room bounds reset a left-facing delivery exactly once")
				_restored(section)
		observe_sixth_view=true
		_check(await traverse_sixth(section), "R and actual Spike death still allow the complete native course to its next checkpoint or real Goal")
		print("SIXTH_RETRY room=",section+1)
	observe_sixth_view=false
	await _new_stage()
	await _enter(29)
	var foreign: Grabbable=stage.rooms.get_child(29).get_node("Items/JumpCreature")
	_check(await traverse_fifth(29),"The old thirtieth room physically reaches the new thirty-first checkpoint")
	release()
	await step(25)
	_check(stage.room_index==30 and not stage.completed and player.get_held_object()==null and not stage._carry_requirement_met(),"The old final room transfers without carrying a foreign resource")
	_check(foreign.carrier==null and foreign.global_position.distance_to(foreign._spawn_transform.origin)<15,"The previous real companion resets to its actual native spawn")
	_check(await traverse_sixth(30,true) and player.get_held_object()==stage.rooms.get_child(30).get_node("Items/JumpCreature"),"The new route physically reclaims its own companion")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fifth_cleanup()
	print("CORRIDOR_SIXTH_RETRY_TEST_OK checks=",checks)
	quit()

func _restored(section: int) -> void:
	var room: Node2D = stage.rooms.get_child(section)
	_check(stage.room_index==section and player.position.distance_to(Vector2(room.position.x+room.entrance_x,room.entrance_top-26))<2 and player.is_on_floor(), "Retry returns to the room's actual left or right safe entrance")
	_check(player.gravity_direction==1 and player.is_dash_ready() and not player.is_air_jump_ready() and player.get_held_object()==null, "Retry restores gravity, resources and a free holding slot")
	var creature: Grabbable = room.get_node("Items/JumpCreature")
	_check(creature.carrier==null and creature.extra_jump_count()==1 and creature.global_position.distance_to(creature._spawn_transform.origin)<15, "Retry restores the actual companion and its unused extra jump")
	for item in room.get_node("Items").get_children():
		if item.name in ["DashCrystal","JumpCrystal"]:_check(item._available, "Retry restores each real airborne resource crystal")
