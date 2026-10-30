extends "res://tests/corridor_sixth_route_test.gd"

var consumed_frame := -1
var consumed_count := 0

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_sixth_resource_retry_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	for section in [31,32,33,35]:
		await _new_stage()
		await _enter(section)
		var room: Node2D = stage.rooms.get_child(section)
		var resource: Area2D = room.get_node("Items/JumpCrystal" if section in [31,35] else "Items/DashCrystal")
		resource.collected.connect(func(body):
			if body==player:
				consumed_frame=Engine.get_physics_frames()
				consumed_count+=1
		)
		for attempt in 2:
			var before_count := consumed_count
			_check(await _consume_now(section,resource), "Real entrance actions collect the actual native resource without positioning the player by fixture")
			_check(consumed_count==before_count+1 and consumed_frame==Engine.get_physics_frames() and not resource._available, "The fixture stops on the very physics frame of the actual collected signal")
			var before := deaths
			await _pulse("reset")
			release()
			_check(deaths==before+1 and Engine.get_physics_frames()==consumed_frame+1, "R is processed on the very next physics frame after consumption")
			_check(resource._available and resource._respawn_left==0 and resource.monitoring and not resource.get_node("CollisionShape2D").disabled, "Immediate retry rearms the same real collision and clears its respawn timer")
			_check(stage.room_index==section and player.gravity_direction==1 and player.is_dash_ready() and not player.is_air_jump_ready() and player.get_held_object()==null, "Immediate retry restores the native checkpoint, gravity and unused resources")
			await step(6)
			_check(resource._available and resource._respawn_left==0, "A deferred collection callback cannot hide the resource again after retry")
		print("SIXTH_RESOURCE_IMMEDIATE_RETRY room=",section+1," actual_contacts=2")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fifth_cleanup()
	print("CORRIDOR_SIXTH_RESOURCE_RETRY_TEST_OK checks=",checks)
	quit()

func _consume_now(section: int, resource: Area2D) -> bool:
	var room: Node2D=stage.rooms.get_child(section)
	var before := deaths
	var before_count := consumed_count
	if section in [32,33] and not await traverse_sixth(section,true):return false
	if not await more_walk(room.route_x(430) if section in [31,35] else (730.0 if section==33 else 1220.0)):return false
	var target: float = room.route_x(430) if section in [31,35] else (800.0 if section==33 else 1220.0)
	for frame in 180:
		more_drive(target-_more_x())
		if frame in [0,21]:Input.action_press("jump")
		if frame==42 and section in [32,33]:
			_drive(Vector2.UP*player.gravity_direction)
			Input.action_press("dash")
		await step()
		if consumed_count>before_count:
			return resource==room.get_node("Items/JumpCrystal" if section in [31,35] else "Items/DashCrystal") and deaths==before
		if deaths!=before:return false
	return false
