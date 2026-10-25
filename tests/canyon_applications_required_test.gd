extends "res://tests/canyon_applications_route_test.gd"

const NATIVE_AIMS := [Vector2.UP,Vector2(1,-1),Vector2.RIGHT,Vector2(1,1),Vector2.DOWN,Vector2(-1,1),Vector2.LEFT,Vector2(-1,-1)]
var attempts := 0
var action_events: Dictionary = {}


func _run() -> void:
	_isolate_collection()
	progress=root.get_node("CollectionProgress")
	var mode:="boots"
	var offset:=0
	var count:=8
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode=arg.trim_prefix("--case=")
		if arg.begins_with("--offset="): offset=int(arg.trim_prefix("--offset="))
		if arg.begins_with("--count="): count=int(arg.trim_prefix("--count="))
	_check(mode in ["boots","super","wall","refill","direct","relay","down"] and offset>=0 and count>0,"Select a finite ordinary-input comparison")
	if failed:return
	if mode=="super":
		for launch in [90.0,190.0,270.0]:
			for delay in [0,4,8]:
				await _boots_super(launch,delay)
				if failed:return
				attempts+=1
	else:
		for aim in NATIVE_AIMS.slice(offset,mini(offset+count,8)):
			for delay in ([0,12] if mode=="direct" else ([16,32,48,64] if mode=="relay" else ([20,36,44] if mode=="wall" else [12,20,28]))):
				match mode:
					"boots": await _boots_omitted(aim,delay)
					"wall":
						for prefix in ["bounce","rest"]:
							await _wall_omitted(aim,delay,prefix)
							if failed:return
							attempts+=1
						continue
					"refill": await _refill_omitted(aim,delay)
					"direct":
						for lane in [-40.0,0.0,40.0]:
							await _direct_down(aim,delay,lane)
							if failed:return
							attempts+=1
						continue
					"down": await _down_omitted(aim,delay)
					"relay": await _relay_omitted(aim,delay)
				if failed:return
				attempts+=1
	_check(attempts>0,"The selected finite comparison executes at least one actual attempt")
	if failed:return
	_release_inputs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_APPLICATIONS_REQUIRED_TEST_OK case=",mode," attempts=",attempts," checks=",checks)
	quit()


func _comparison_setup(index:int) -> Node2D:
	monitor_view=false
	await _setup(index)
	action_events={"jump":0,"dash":0,"superdash":0,"wall_jump":0,"air_jump":0,"bumper":0,"fourth":0}
	player.movement_action.connect(func(action):
		if action_events.has(action): action_events[action]+=1)
	for bumper_index in stage._bumpers().get_child_count():
		stage._bumpers().get_child(bumper_index).launched.connect(_comparison_bumper.bind(bumper_index))
	return stage.rooms.get_child(index)


func _comparison_bumper(_body:PlayerController, index:int) -> void:
	action_events.bumper+=1
	if index==3:action_events.fourth+=1


func _actual_dash(aim:Vector2) -> void:
	_release_inputs()
	if aim.x!=0: Input.action_press("move_right" if aim.x>0 else "move_left")
	if aim.y!=0: Input.action_press("move_down" if aim.y>0 else "move_up")
	_check(player.is_dash_ready(),"The comparison really has its ungranted Dash")
	await _pulse("dash")


func _first_three(inverted:bool, lane:float=0.0) -> void:
	if inverted: await _inverted_begin(1.0)
	else: await _entry_begin(1.0)
	for frame in 1200:
		if stage.next_bumper>=3 or respawns>0:break
		if inverted:
			if stage.next_bumper==2: _inverted_to(stage._bumpers().get_child(2).position+Vector2(lane,62),1.0)
			else:_inverted_steer(1.0)
		else:_steer()
		await _step()
	_check(stage.next_bumper==3 and respawns==0,"The comparison prepares three actual reflections without positioning or resource grants")


func _finish_comparison(index:int, label:String) -> void:
	_check(stage.room_index==index and not stage.transitioning and not stage.completed,label+" reaches no native exit or Goal")
	_release_inputs()


func _boots_omitted(aim:Vector2, delay:int) -> void:
	var room:=await _comparison_setup(30)
	room.get_node("Items/Boots").monitoring=false
	await _pulse("jump")
	for frame in delay:
		_entry_horizontal(300)
		await _step()
	await _actual_dash(aim)
	for frame in 480:
		if respawns>0 or stage.next_bumper>0 or stage.transitioning:break
		_entry_horizontal(300)
		await _step()
	_check(action_events.jump==1 and action_events.dash==1 and action_events.air_jump==0,"The omitted boots leave one actual Jump and Dash")
	_check(action_events.bumper==0,"The tested bare Jump/Dash cannot reach the first reflection")
	_finish_comparison(30,"The omitted boots")


func _boots_super(launch:float, delay:int) -> void:
	var room:=await _comparison_setup(30)
	room.get_node("Items/Boots").monitoring=false
	for frame in 180:
		_entry_horizontal(launch)
		await _step()
		if absf(_x()-launch)<6 and absf(player.velocity.x)<30:break
	_check(player.is_on_floor(),"The real Superdash begins on the actual entrance")
	Input.action_press("move_right")
	await _pulse("dash")
	await _step(delay)
	await _pulse("jump")
	for frame in 480:
		if respawns>0 or stage.next_bumper>0 or stage.transitioning:break
		_entry_horizontal(300)
		if player.is_dash_ready() and frame==20:await _actual_dash(Vector2.UP)
		await _step()
	_check(action_events.superdash>0 and action_events.air_jump==0,"The omission executes a real Superdash without boots")
	_check(action_events.bumper==0,"The tested bare Superdash reaches no first reflection")
	_finish_comparison(30,"The bare Superdash")


func _wall_omitted(aim:Vector2, delay:int, prefix:String) -> void:
	await _comparison_setup(32)
	await _first_three(false)
	if failed:return
	player.wall_actions_enabled=false
	if prefix=="rest":
		await _land_at_wide_rest()
		await _step(20)
		await _pulse("jump")
	for frame in delay:
		_entry_horizontal(2100)
		await _step()
	await _actual_dash(aim)
	var top_reached:=false
	for frame in 600:
		if respawns>0 or stage.next_bumper>3 or stage.completed:break
		_entry_horizontal(2100)
		await _step()
		top_reached=top_reached or (player.is_on_floor() and player.position.y<800)
	_check(not top_reached and action_events.bumper>=3 and action_events.fourth==0 and action_events.wall_jump==0,"Without wall actions the tested "+prefix+" prefix reaches neither rock top nor fourth reflection")
	_finish_comparison(32,"The omitted wall action")


func _refill_omitted(aim:Vector2, delay:int) -> void:
	var room:=await _comparison_setup(31)
	room.get_node("Items/Refill").monitoring=false
	await _applications_relay_begin(1.0,20)
	if failed:return
	await _pulse("jump")
	for frame in delay:
		_entry_horizontal(1950)
		await _step()
	await _actual_dash(aim)
	for frame in 480:
		if respawns>0 or stage.next_bumper>3 or stage.transitioning:break
		_entry_horizontal(1950)
		await _step()
	_check(action_events.fourth==0,"Without the native refill the tested floor Jump/Dash reaches no fourth reflection")
	_finish_comparison(31,"The omitted middle refill")


func _direct_down(aim:Vector2, delay:int, lane:float) -> void:
	var room:=await _comparison_setup(31)
	room.get_node("Items/Refill").monitoring=false
	await _first_three(true,lane)
	if failed:return
	for frame in 900:
		if player.gravity_direction==1 or respawns>0:break
		_entry_horizontal(1720)
		await _step()
	var prepared:=player.gravity_direction==1 and respawns==0
	if prepared:
		await _step(delay)
		if player.is_dash_ready():await _actual_dash(aim)
		for frame in 600:
			if respawns>0 or stage.next_bumper>3 or stage.transitioning:break
			_entry_horizontal(1950)
			await _step()
	print("DIRECT_DOWN lane=",lane," aim=",aim," delay=",delay," prepared=",prepared," p=",Vector2(_x(),player.position.y)," events=",action_events)
	_check(action_events.fourth==0,"Skipping the middle floor and refill reaches no fourth reflection in this tested prefix")
	_finish_comparison(31,"The direct Down prefix")


func _down_omitted(aim:Vector2, delay:int) -> void:
	var room:=await _comparison_setup(31)
	room.get_node("Gates/Down").monitoring=false
	await _first_three(true)
	if failed:return
	await _inverted_rest("Rest",1.0)
	await _pulse("jump")
	for frame in delay:
		_entry_horizontal(1720)
		await _step()
	await _actual_dash(aim)
	for frame in 1800:
		if respawns>0 or stage.transitioning or stage.completed:break
		if stage.next_bumper<stage._bumpers().get_child_count():_inverted_steer(1.0)
		else:_inverted_to(Vector2(3720,1474),1.0)
		await _step()
	_check(player.gravity_direction==-1 or respawns>0,"The omitted native Down never flips to normal gravity")
	_finish_comparison(31,"The omitted Down")

func _relay_omitted(aim:Vector2, delay:int) -> void:
	var room:=await _comparison_setup(31)
	room.get_node("Items/Refill").monitoring=false
	await _first_three(true)
	if failed:return
	for frame in delay:
		if respawns>0:break
		_entry_horizontal(1720)
		await _step()
	var prepared:=respawns==0 and player.is_dash_ready()
	if prepared:await _actual_dash(aim)
	for frame in 1200:
		if respawns>0 or action_events.fourth>0 or stage.transitioning:break
		if player.gravity_direction<0: _inverted_to(room.get_node("Gates/Down").position,1.0)
		else:_steer()
		await _step()
	print("RELAY_OMISSION aim=",aim," delay=",delay," prepared=",prepared," events=",action_events)
	_check(action_events.fourth==0,"The tested direct Jump/Dash through Down cannot replace the actual middle refill")
	_finish_comparison(31,"The direct gravity relay without refill")
