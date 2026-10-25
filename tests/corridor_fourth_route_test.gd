extends "res://tests/corridor_wide_route_test.gd"

var observe_fourth_view := false

func _run() -> void:
	observe_fourth_view = true
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_fourth_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	var first := 18
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="): first=int(arg.trim_prefix("--section="))-1
	var profiles: Array = [[1.0,20]] if OS.get_cmdline_user_args().has("--strong") else [[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): profiles = [profiles[int(arg.trim_prefix("--profile="))]]
	for profile in profiles:
		steering_strength=profile[0]
		await _new_stage()
		await _enter(first)
		var ids: Array[String] = []
		var goals := 0
		for room in stage.rooms.get_children():
			if room.has_node("Scroll"):
				var scroll: Area2D = room.get_node("Scroll")
				_check(scroll.stage_id == "companion" and not ids.has(scroll.scroll_id), "Native optional scroll IDs belong to this stage and are unique")
				ids.append(scroll.scroll_id)
			if room.has_node("Goal"): goals += 1
		_check(ids.size() == 7 and progress.TOTALS["companion"] == ids.size(), "The persisted selection total equals all seven actual native scrolls")
		_check(stage.rooms.get_child_count() == 24 and goals == 1 and stage.goal.get_parent() == stage.rooms.get_child(23), "All twenty-four native rooms connect to one real final Goal")
		for section in range(first,24):
			if section == 23:
				stage.set_hints_visible(true)
				var red: Grabbable = stage.rooms.get_child(section).get_node("Items/ParachuteCreature")
				var red_bounds: Rect2 = red.collider.get_global_transform_with_canvas() * red.collider.shape.get_rect()
				_check(not stage.get_node("HUD/PauseButton").get_global_rect().intersects(red_bounds), "The entrance does not hide the red alternative behind the pause button")
			var before:=deaths
			var started:=Engine.get_physics_frames()
			actions.clear()
			_check(await traverse_fourth(section,true,profile[1]),"The actual new entrance reaches a safe observation rest")
			if failed:return
			_hold()
			await step(20)
			var stopped:=player.position
			await step(180)
			_check(player.is_on_floor() and player.position.distance_to(stopped)<2 and stage._carry_requirement_met(),"The actual rest is safe for three seconds while carrying")
			var room: Node2D = stage.rooms.get_child(section)
			if section in [19, 23]:
				var spring: Area2D = room.get_node("Spring" if section == 19 else "ChoiceSpring")
				var spring_bounds := Rect2(root.get_canvas_transform() * spring.global_position - Vector2(32, 32), Vector2(64, 40))
				_check(root.get_visible_rect().encloses(spring_bounds) and not stage.get_node("HUD/Info").get_global_rect().intersects(spring_bounds), "The actual Spring remains visible before leaving the first rest")
				if section == 23:
					var red: Grabbable = room.get_node("Items/ParachuteCreature")
					var red_bounds: Rect2 = red.collider.get_global_transform_with_canvas() * red.collider.shape.get_rect()
					_check(root.get_visible_rect().encloses(red_bounds) and not stage.get_node("HUD/Info").get_global_rect().intersects(red_bounds), "The red alternative is visible before choosing a carrier")
			print("FOURTH_REST room=",section+1," p=",Vector2(_more_x(),player.position.y)," floor=",player.is_on_floor())
			_check(_on_wide_ceiling(room.walls[0]) if section == 21 else _on_more_rest(room.walls[0]),"The three-second observation remains on the intended first native landing")
			if failed:return
			if section in [18, 19, 20, 23]:
				var next := Rect2(root.get_canvas_transform()*room.to_global(room.walls[1].position),room.walls[1].size)
				print("FOURTH_NEXT room=",section+1," rect=",next)
				_check(root.get_visible_rect().encloses(next) and not stage.get_node("HUD/Info").get_global_rect().intersects(next),"The next real landing stays visible outside the HUD before leaving the rest")
			_check(await traverse_fourth(section,false,profile[1]),"The actual new course reaches its exit and next checkpoint or real Goal")
			var seconds:=float(Engine.get_physics_frames()-started)/60
			print("FOURTH_MAIN room=",section+1," strength=",profile[0]," gap=",profile[1]," seconds=",seconds," actions=",actions)
			_check(deaths==before+(0 if section==23 else 1) and seconds<30,"The successful course has only normal room transfer and stays below thirty seconds")
			_check(progress.get_count("companion")==0,"Ordinary traversal leaves the optional scrolls untouched")
			if failed:return
			_hold()
			await step(25)
		_check(stage.completed,"The six new rooms form a connected route to the real final Goal")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fourth_cleanup()
	print("CORRIDOR_FOURTH_ROUTE_TEST_OK checks=",checks)
	quit()


func step(count: int = 1) -> void:
	for frame in count:
		await super.step()
		if not observe_fourth_view or not is_instance_valid(stage) or not is_instance_valid(player) or stage.room_index < 18 or stage.transitioning: continue
		var shape: CollisionShape2D = player.get_node("CollisionShape2D")
		var body: Rect2 = shape.get_global_transform_with_canvas()*shape.shape.get_rect()
		var hud: Rect2 = stage.get_node("HUD/Info").get_global_rect()
		if not root.get_visible_rect().encloses(body) or hud.intersects(body): print("FOURTH_VIEW_BAD body=",body," hud=",hud," p=",Vector2(_more_x(),player.position.y)," v=",player.velocity," camera=",stage.camera.position)
		_check(root.get_visible_rect().encloses(body) and not hud.intersects(body),"The actual whole player remains on screen and outside the HUD during the new main route")
		_check(not hud.intersects(stage.get_node("HUD/PauseButton").get_global_rect()), "The native HUD and pause button remain readable separately")
		if stage.get_node("HUD/Hint").visible:
			_check(not hud.intersects(stage.get_node("HUD/Hint").get_global_rect()), "The optional hint remains readable beside the native HUD")
		var held: Grabbable = player.get_held_object()
		if held != null:
			var object_bounds: Rect2 = held.collider.get_global_transform_with_canvas()*held.collider.shape.get_rect()
			if not root.get_visible_rect().encloses(object_bounds) or hud.intersects(object_bounds): print("FOURTH_HELD_BAD body=",object_bounds," hud=",hud," p=",Vector2(_more_x(),player.position.y)," v=",player.velocity," camera=",stage.camera.position)
			_check(root.get_visible_rect().encloses(object_bounds) and not hud.intersects(object_bounds),"The entire actual held companion stays on screen and outside the HUD during the new main route")


func _fourth_cleanup() -> void:
	observe_fourth_view = false
	release()
	current_scene.queue_free()
	stage = null
	player = null
	await step(5)
