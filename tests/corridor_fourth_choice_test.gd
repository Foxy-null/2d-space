extends "res://tests/corridor_fourth_route_test.gd"

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_fourth_choice_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	var profiles: Array = [[1.0,20]] if OS.get_cmdline_user_args().has("--strong") else [[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): profiles = [profiles[int(arg.trim_prefix("--profile="))]]
	for profile in profiles:
		observe_fourth_view=false
		steering_strength=profile[0]
		await _new_stage()
		stage.set_hints_visible(true)
		await _enter(23)
		observe_fourth_view=true
		var before:=deaths
		var started:=Engine.get_physics_frames()
		_check(await traverse_fourth(23,true,profile[1]),"The choice starts from the actual green companion and boots route")
		_hold()
		await step(200)
		actions.clear()
		var wind_contacts: Array[bool] = []
		stage.rooms.get_child(23).get_node("ChoiceTailwind").body_entered.connect(func(body):
			if body==player:wind_contacts.append(true))
		_check(await fourth_choose_red(),"Actual release, walking away and grabbing select the local red companion")
		var room: Node2D = stage.rooms.get_child(23)
		var green: Grabbable = room.get_node("Items/JumpCreature")
		var green_bounds: Rect2 = green.collider.get_global_transform_with_canvas() * green.collider.shape.get_rect()
		_check(root.get_visible_rect().encloses(green_bounds) and not stage.get_node("HUD/Info").get_global_rect().intersects(green_bounds), "The safely placed green companion remains visible after choosing red")
		var next := Rect2(root.get_canvas_transform()*room.to_global(room.walls[2].position),room.walls[2].size)
		_check(root.get_visible_rect().encloses(next) and not stage.get_node("HUD/Info").get_global_rect().intersects(next),"After choosing red the actual next landing is visible before Spring")
		_check(await fourth_right_finish(profile[1],false),"Actual release, unheld walk and regrab take the local red parachute through Spring and wind to the next checkpoint")
		_check(not stage.completed and stage.room_index==24 and fourth_delivered==stage.rooms.get_child(23).get_node("Items/ParachuteCreature"),"Only the actual local red companion satisfies this alternative delivery")
		_check(not wind_contacts.is_empty(),"The alternative red route actually enters its native horizontal wind")
		_check(not actions.has("creature_jump") and deaths==before+1,"The parachute route does not borrow the green extra jump or respawn")
		var seconds:=float(Engine.get_physics_frames()-started)/60
		_check(seconds<30,"The real red delivery including three-second rest stays below thirty seconds")
		print("FOURTH_RED strength=",profile[0]," gap=",profile[1]," seconds=",seconds," actions=",actions)
		if failed:return
	observe_fourth_view = false
	steering_strength = 1.0
	await _new_stage()
	stage.set_hints_visible(true)
	await _enter(23)
	observe_fourth_view = true
	_check(await traverse_fourth(23, true), "The shared right route begins after the real common boots transfer")
	var upper_boot: Array[bool] = []
	stage.rooms.get_child(23).get_node("Items/UpperJumpCrystal").collected.connect(func(_body): upper_boot.append(true))
	_check(await fourth_right_finish(20, false) and stage.room_index==24 and not stage.completed and upper_boot.is_empty(), "Green may also carry through the legitimate Spring route without a history lock or upper-boot requirement")
	_check(fourth_delivered == stage.rooms.get_child(23).get_node("Items/JumpCreature"), "The shared route delivers the actual local green companion")
	observe_fourth_view=false
	release()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fourth_cleanup()
	print("CORRIDOR_FOURTH_CHOICE_TEST_OK checks=",checks)
	quit()
