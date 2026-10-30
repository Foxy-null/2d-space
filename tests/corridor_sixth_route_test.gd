extends "res://tests/corridor_fifth_route_test.gd"

var observe_sixth_view := false
var sixth_hits: Dictionary = {}
var observed_sixth_frames := 0
var capture_spring_view := false

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_sixth_%d.cfg"%OS.get_process_id()
	progress._collected.clear()
	screenshot_mode = OS.get_cmdline_user_args().has("--screenshots")
	capture_spring_view = screenshot_mode
	var profiles: Array = [[1.0,20]] if OS.get_cmdline_user_args().has("--strong") or screenshot_mode else [[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	var first := 30
	var last := 36
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="):first=int(arg.trim_prefix("--section="))-1;last=first+1
		if arg.begins_with("--profile="):profiles=[profiles[int(arg.trim_prefix("--profile="))]]
	for profile in profiles:
		steering_strength=profile[0]
		await _new_stage()
		await _enter(first)
		stage.set_hints_visible(OS.get_cmdline_user_args().has("--hints") or not screenshot_mode)
		observe_sixth_view = not OS.get_cmdline_user_args().has("--no-view")
		more_drive(100*stage.rooms.get_child(first).travel_direction)
		_check(is_equal_approx(absf(Input.get_axis("move_left","move_right")),steering_strength),"The actual direct horizontal axis matches the reported strength")
		_hold()
		var ids: Array[String] = []
		var goals := 0
		for room in stage.rooms.get_children():
			if room.has_node("Scroll"):
				var scroll: Area2D=room.get_node("Scroll")
				_check(scroll.stage_id=="companion" and not ids.has(scroll.scroll_id),"Every real native collection has a unique stage-scoped ID")
				ids.append(scroll.scroll_id)
			if room.has_node("Goal"):goals+=1
		_check(ids.size()==12 and progress.TOTALS["companion"]==12,"Twelve actual placements match the persisted selection total")
		_check(stage.rooms.get_child_count()==36 and goals==1 and stage.goal.get_parent()==stage.rooms.get_child(35),"Thirty-six real rooms lead to one final Goal")
		for section in range(first,last):
			var started := Engine.get_physics_frames()
			var before := deaths
			actions.clear()
			_sixth_events(stage.rooms.get_child(section))
			await _sixth_capture("room%d_entrance"%(section+1))
			_check(await traverse_sixth(section,true,profile[1]),"The real sixth entrance reaches its safe observation floor")
			if failed:return
			_hold()
			await step(20)
			if OS.get_cmdline_user_args().has("--trace"):print("SIXTH_REST room=",section+1," p=",Vector2(_more_x(),player.position.y)," floor=",player.is_on_floor()," walls=",stage.rooms.get_child(section).walls)
			var stopped := player.position
			await step(180)
			_check(player.is_on_floor() and player.position.distance_to(stopped)<2 and stage._carry_requirement_met(),"The real carried observation remains safe for three seconds")
			await _sixth_rest_view(section)
			await _sixth_capture("room%d_rest"%(section+1))
			_check(await traverse_sixth(section,false,profile[1]),"The actual sixth course reaches its next checkpoint or Goal")
			_sixth_actions(section)
			print("SIXTH_MAIN room=",section+1," strength=",profile[0]," gap=",profile[1]," seconds=",(Engine.get_physics_frames()-started)/60.0," actions=",actions)
			_check(deaths==before+(0 if section==35 else 1) and Engine.get_physics_frames()-started<1800,"The actual retry has only its ordinary transfer and remains below thirty seconds")
			_check(progress.get_count("companion")==0,"The ordinary main course leaves optional scrolls untouched")
			if failed:return
			_hold()
			await step(25)
			if stage.completed:
				await _sixth_capture("room36_goal")
	observe_sixth_view=false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fifth_cleanup()
	print("CORRIDOR_SIXTH_ROUTE_TEST_OK checks=",checks," observed_frames=",observed_sixth_frames)
	quit()


func _sixth_events(room: Node2D) -> void:
	sixth_hits={"spring":0,"bumper":0,"refill":0,"up":0,"down":0,"throw":0,"wind_frames":0}
	for entry in [["Spring","spring","launched"],["Bumper","bumper","launched"],["Items/DashCrystal","refill","collected"],["Items/UpGate","up","body_entered"],["Items/DownGate","down","body_entered"]]:
		if room.has_node(entry[0]):
			room.get_node(entry[0]).connect(entry[2],func(body):
				if body==player:sixth_hits[entry[1]]+=1
			)
	player.object_released.connect(func(_object,thrown):
		if thrown:sixth_hits["throw"]+=1
	,CONNECT_ONE_SHOT)


func _sixth_actions(section: int) -> void:
	_check(actions.get("creature_jump",0)>0,"The route really uses its held companion jump")
	match section:
		30:_check(sixth_hits["throw"]>0 and actions.get("bare_climb_frames",0)>0 and sixth_hits["spring"]>0,"The same real object is thrown, recovered after a bare climb, and carried through Spring")
		31:_check(actions.get("air_jump",0)>0 and sixth_hits["wind_frames"]>0,"The actual Boot and registered horizontal wind contribute to the leftward route")
		32:_check(sixth_hits["bumper"]>0 and sixth_hits["refill"]==1 and actions.get("dash",0)>=3,"The real first rebound and airborne refill contribute three actual dashes")
		33:_check(sixth_hits["up"]>0 and sixth_hits["down"]>0 and sixth_hits["refill"]==1,"The actual Up, inverted refill and Down contact all occur")
		34:_check(sixth_hits["spring"]>0 and actions.get("wall_jump",0)>0 and sixth_hits["wind_frames"]>0,"The actual Spring, held wall kicks and registered wind contribute separate actions")
		35:_check(actions.get("air_jump",0)>0 and sixth_hits["spring"]>0 and sixth_hits["bumper"]>0 and stage.goal.is_pressed(),"The actual Boot, Spring, upper reflection and final switch all occur")
	print("SIXTH_NATIVE_EVENTS room=",section+1," events=",sixth_hits)


func step(count: int = 1) -> void:
	for frame in count:
		await super.step()
		if not observe_sixth_view or not is_instance_valid(stage) or not is_instance_valid(player) or stage.transitioning or stage.room_index<30:continue
		observed_sixth_frames+=1
		var room: Node2D=stage.rooms.get_child(stage.room_index)
		if room.has_node("HighTailwind") and player._winds.has(room.get_node("HighTailwind").get_instance_id()):sixth_hits["wind_frames"]=sixth_hits.get("wind_frames",0)+1
		var bodies: Array[CollisionShape2D]=[player.get_node("CollisionShape2D")]
		var held: Grabbable=player.get_held_object()
		if held!=null:bodies.append(held.collider)
		var panels: Array[Control]=[stage.get_node("HUD/Info"),stage.get_node("HUD/PauseButton")]
		if stage.get_node("HUD/Hint").visible:panels.append(stage.get_node("HUD/Hint"))
		if stage.get_node("HUD/Completion").visible and stage.get_node("HUD/Completion").card.visible:panels.append(stage.get_node("HUD/Completion").card)
		for shape in bodies:
			var bounds: Rect2=shape.get_global_transform_with_canvas()*shape.shape.get_rect()
			if not root.get_visible_rect().encloses(bounds):print("SIXTH_OFFSCREEN room=",stage.room_index+1," body=",shape.get_parent().name," rect=",bounds," p=",Vector2(_more_x(),player.position.y)," camera=",stage.camera.position)
			_check(root.get_visible_rect().encloses(bounds),"The whole native player and actual held object remain inside the viewport")
			for panel in panels:
				if panel.get_global_rect().intersects(bounds):print("SIXTH_HUD_OVERLAP room=",stage.room_index+1," body=",shape.get_parent().name," rect=",bounds," panel=",panel.name,panel.get_global_rect()," p=",Vector2(_more_x(),player.position.y))
				_check(not panel.get_global_rect().intersects(bounds),"The real player and held object remain outside every visible HUD panel")
		for panel in panels:_check(root.get_visible_rect().encloses(panel.get_global_rect()),"Every shown native HUD panel remains fully inside the viewport")
		for i in panels.size():
			for j in range(i+1,panels.size()):
				if panels[i].get_global_rect().intersects(panels[j].get_global_rect()):print("SIXTH_PANEL_OVERLAP ",panels[i].name,panels[i].get_global_rect()," / ",panels[j].name,panels[j].get_global_rect())
				_check(not panels[i].get_global_rect().intersects(panels[j].get_global_rect()),"All shown HUD panels remain readable separately")
		if stage.get_node("HUD/Hint").visible:
			var ceiling: Node2D=room.get_node("Hazards/CeilingSpikes")
			var extent: Vector2=ceiling.hit_extent()
			_check(not stage.get_node("HUD/Hint").get_global_rect().intersects(ceiling.get_global_transform_with_canvas()*Rect2(-extent,extent*2)),"The visible Hint leaves the actual native ceiling hazard clear on every observed frame")
		if capture_spring_view and stage.room_index==30 and stage.camera.position.y<392:
			capture_spring_view=false
			_sixth_capture_now("room31_spring")


func _sixth_rest_view(section: int) -> void:
	var room: Node2D=stage.rooms.get_child(section)
	match section:
		30:_sixth_shape_view(room.get_node("Spring/CollisionShape2D"),"The actual next Spring")
		31:_sixth_landing(room.walls[1],true,"The next lower left island")
		32:_sixth_shape_view(room.get_node("Items/DashCrystal/CollisionShape2D"),"The actual next airborne refill")
		33:_sixth_landing(room.walls[1],false,"The next inverted ceiling")
		34:
			var shape: CollisionShape2D=room.get_node("ShaftLeft/Collision")
			var face:=shape.shape.get_rect()
			face.position.y=face.end.y-120
			face.size.y=120
			_sixth_bounds(shape.get_global_transform_with_canvas()*face,"The next real shaft entry")
		35:_sixth_shape_view(room.get_node("Bumper/CollisionShape2D"),"The next upper reflection")


func _sixth_shape_view(shape: CollisionShape2D, label: String) -> void:
	_sixth_bounds(shape.get_global_transform_with_canvas()*shape.shape.get_rect(),label)


func _sixth_landing(rect: Rect2, left: bool, label: String) -> void:
	var face:=Rect2(Vector2(rect.end.x-160 if left else rect.position.x,rect.end.y-16 if player.gravity_direction==-1 else rect.position.y),Vector2(160,16))
	_sixth_bounds(root.get_canvas_transform()*stage.rooms.get_child(stage.room_index).global_transform*face,label)


func _sixth_view(label: String) -> void:
	if label=="room33_refill":_sixth_landing(stage.rooms.get_child(32).walls[1],false,"The upper landing is visible after touching the real refill")
	if label in ["room32_wind","room35_wind"]:
		var room: Node2D=stage.rooms.get_child(stage.room_index)
		_sixth_landing(room.walls[1 if stage.room_index==31 else 2],true,"The lower island is visible before entering its wind")
	await _sixth_capture(label)


func _sixth_capture(label: String) -> void:
	if not screenshot_mode:return
	await process_frame
	_sixth_capture_now(label)


func _sixth_capture_now(label: String) -> void:
	RenderingServer.force_draw()
	var hints: bool=stage.hints_visible if is_instance_valid(stage) else OS.get_cmdline_user_args().has("--hints")
	var directory:="res://docs/screenshots/corridor-sixth/"+("hints" if hints else "default")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"The final native frame is saved")


func _sixth_bounds(bounds: Rect2, label: String) -> void:
	if not root.get_visible_rect().encloses(bounds):print("SIXTH_NEXT_OFFSCREEN ",label," rect=",bounds," camera=",stage.camera.position," p=",Vector2(_more_x(),player.position.y))
	_check(root.get_visible_rect().encloses(bounds),"The next real mechanic or broad landing face is visible: "+label)
	for path in ["Info","Hint","PauseButton"]:
		var panel: Control=stage.get_node("HUD/"+path)
		if panel.visible:
			if panel.get_global_rect().intersects(bounds):print("SIXTH_NEXT_HUD ",label," rect=",bounds," panel=",path,panel.get_global_rect())
			_check(not panel.get_global_rect().intersects(bounds),"The next real destination stays clear of shown HUD: "+label)
