extends "res://tests/tower_fourth_route_test.gd"

var fifth_wind_frames := 0


func _run() -> void:
	var profiles: Array = [[1.0,20]]
	if OS.get_cmdline_user_args().has("--six"):
		profiles = [[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):profiles=[profiles[int(arg.trim_prefix("--profile="))]]
	var first := 25
	var last := 31
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="):
			first=int(arg.trim_prefix("--section="))-1
			last=first+1
		if arg=="--through":last=31
	for profile in profiles:
		upper_strength = profile[0]
		upper_jump_delay = profile[1]
		upper_dash_delay = profile[1]
		await _fresh_fourth(24 if OS.get_cmdline_user_args().has("--old25") else first)
		_assert_static_checkpoint()
		if OS.get_cmdline_user_args().has("--old25"):
			await _fourth_course(24)
			_check(stage.checkpoint_index==25 and not stage.completed and respawns==0,"The actual old summit now leads into CP26 without prematurely completing the tower")
		for section in range(first,last):
			actions.clear()
			fifth_wind_frames=0
			climb_frames=0
			await _fifth_course(section)
			_check(respawns==0,"Each actual fifth route keeps its native checkpoint and never respawns")
			if section in [28,29]:_check(fifth_wind_frames>0,"The native route actually registers and spends non-Dash frames in its real wind")
			if section==25:_check(actions.get("creature_jump",0)>=2 and climb_frames>0,"Actual extra jumps and unheld wall climb contribute separate actions")
			if section==30:_check(actions.get("air_jump",0)==1 and actions.get("dash",0)>=4,"The native final Boot, reflection and refill each contribute actions")
			print("FIFTH_ACTIONS section=",section+1," axis=",upper_strength," delay=",upper_dash_delay," actions=",actions)
			if failed:return
	monitor_view=false
	_release()
	current_scene.queue_free()
	await _step(18)
	print("TOWER_FIFTH_ROUTE_TEST_OK checks=",checks," observed_frames=",observed_frames)
	quit(1 if failed else 0)


func _fifth_view(phase: String) -> void:
	var faces := {"25_refill":["FourthSummit",-1200],"26_entry":["Fifth26Wall",-500],"26_carry":["Fifth27Checkpoint",100],"27_wall":["Fifth27Wall",700],"28_entry":["Fifth28Lower",450],"28_wall":["Fifth28Wall",-200],"29_boot":["Fifth30Checkpoint",-850],"30_glide":["Fifth30Lower",-1980],"30_wind":["Fifth31Checkpoint",-1420],"31_goal":["FifthSummit",-150]}
	if faces.has(phase):
		var destination: Array=faces[phase]
		var shape: CollisionShape2D=stage.get_node("Terrain/"+destination[0]+"/Collision")
		var face := shape.shape.get_rect()
		face.position.x=clampf(float(destination[1])-shape.global_position.x-80,face.position.x,face.end.x-160)
		face.size=Vector2(160,minf(16,face.size.y))
		_check_next_visible(shape.get_global_transform_with_canvas()*face,phase+" next static face")
	var items := {"25_entry":"Fourth25Bumper","27_entry":"Fifth27Dash","29_entry":"Fifth29Bumper","31_entry":"Fifth31Boot","31_refill":"Fifth31Dash"}
	if items.has(phase):
		var shape: CollisionShape2D=stage.get_node("Items/"+items[phase]+"/CollisionShape2D")
		_check_next_visible(shape.get_global_transform_with_canvas()*shape.shape.get_rect(),phase+" real item")
	if phase=="25_refill":
		var point: Marker2D=stage.checkpoints.get_child(25)
		_check_next_visible(point.get_global_transform_with_canvas()*Rect2(-108,-52,48,56),"The actual next CP26 flag at the old summit")
	if phase=="31_goal":
		var point: Marker2D=stage.checkpoints.get_child(31)
		_check_next_visible(point.get_global_transform_with_canvas()*Rect2(-108,-52,48,56),"The actual next CP32 flag at the former summit")
	if not OS.get_cmdline_user_args().has("--screenshots"):return
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tower-fifth")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/tower-fifth/%s%s.png"%[phase,"_hints" if stage.hints_visible else ""])==OK,"Save the actual native fifth route")


func _step(count: int=1) -> void:
	for frame in count:
		await super._step()
		if not monitor_view or not is_instance_valid(stage) or not is_instance_valid(player):continue
		for name in ["Fifth29Wind","Fifth30Wind"]:
			var wind=stage.get_node("Items/"+name)
			if player._winds.has(wind.get_instance_id()) and not player.is_dashing():fifth_wind_frames+=1


func _assert_static_checkpoint() -> void:
	var supported:=false
	for index in player.get_slide_collision_count():
		var contact:=player.get_slide_collision(index)
		supported=supported or (contact.get_collider() is StaticBody2D and contact.get_normal().dot(Vector2.UP)>0.8)
	_check(supported and player.position.distance_to(player._spawn_position)<3,"The actual native checkpoint rests on a static floor at its safe spawn, outside movable objects")


func _fourth_view(phase: String) -> void:
	await _fifth_view(phase)
