extends "res://tests/tower_fourth_required_test.gd"

const FIFTH_KINDS := ["26_wall","26_companion","27_refill","28_spring","29_bumper","29_boot","29_direct_boot","30_parachute","30_wind","31_boot","31_bumper","31_refill","31_direct_refill"]

func _run() -> void:
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):selected=arg.trim_prefix("--only=")
	for kind in FIFTH_KINDS:
		if selected!="" and not selected.split(",").has(kind):continue
		for timing in [16,24,40]:
			for direction in DIRECTIONS:
				await _missing_fifth(kind,direction,timing)
				if failed:return
		print("FIFTH_REQUIRED kind=",kind," attempts=",attempts)
	if selected=="" or selected.split(",").has("throws"):
		for strength in [1.0,0.8]:
			upper_strength=strength
			for release in [1,8]:
				await _fresh_fourth(25)
				await _fifth26_reacquire(release)
				_check(respawns==0 and player.get_held_object()==stage.get_node("Items/Fifth26Companion"),"The same native companion is actually thrown and reacquired across a broad Dash-release window")
				actual_throws+=1
	if selected=="" or selected.split(",").has("steps"):
		upper_strength=1.0
		for direction in DIRECTIONS:
			await _fresh_fourth(25)
			monitor_view=false
			await _fifth26_reacquire()
			var object := await _stand_on_real_object()
			Input.action_press("wall_grab")
			await _upper_pulse("jump")
			_check(player.get_held_object()==object,"A real supported jump simultaneously reacquires its native companion")
			await _fifth_flight(25,_world_floor("Fifth27Checkpoint"),direction,20,true,false)
			attempts+=1
	if selected=="" or selected.split(",").has("carried"):
		for strength in [1.0,0.8]:
			upper_strength=strength
			await _carried_green()
	if selected=="" or selected.split(",").has("old_parachute"):
		upper_strength=1.0
		for direction in [Vector2.UP,Vector2(1,-1)]:
			await _old_para_step(direction)
	if selected=="" or selected.split(",").has("coyote"):
		for strength in [1.0,0.8]:
			upper_strength=strength
			for grace in [0,4,7]:
				for direction in [Vector2.LEFT,Vector2(-1,-1)]:
					for timing in [16,24,40]:
						await _glide_coyote(grace,direction,timing)
	_check(attempts+actual_throws+actual_transports>0,"The selected native comparison actually ran")
	monitor_view=false
	_release()
	current_scene.queue_free()
	await _step(18)
	print("TOWER_FIFTH_REQUIRED_TEST_OK checks=",checks," attempts=",attempts," actual_steps=",actual_steps," actual_transports=",actual_transports," actual_throws=",actual_throws)
	quit(1 if failed else 0)

func _missing_fifth(kind: String,direction: Vector2,timing: int) -> void:
	var section:=int(kind.split("_")[0])-1
	await _fresh_fourth(section)
	monitor_view=false
	upper_bounces=0
	if section==30 and kind in ["31_boot","31_bumper"]:stage.get_node("Items/Fifth31Bumper").launched.connect(_on_upper_bounce)
	var target := ""
	var airborne:=false
	match kind:
		"26_wall":
			player.wall_actions_enabled=false
			await _more_walk(-900)
			await _more_grab("Fifth26Companion")
			await _more_walk(-650)
			target="Fifth26Rest"
		"26_companion":
			await _fifth26_reacquire()
			_horizontal(player.position.x-100)
			await _step(2)
			Input.action_release("wall_grab")
			await _step()
			_release()
			await _more_walk(200)
			_check(player.get_held_object()==null,"The actual preceding throw and wall route puts its companion aside before the upper-resource omission")
			target="Fifth27Checkpoint"
		"27_refill":
			_off("Fifth27Dash")
			await _more_walk(100)
			target="Fifth27Rest"
		"28_spring":
			_off("Fifth28Spring")
			await _more_walk(450)
			target="Fifth28Rest"
		"29_bumper":
			_off("Fifth29Bumper")
			await _more_walk(-130)
			target="Fifth29Rest"
		"29_boot":
			_off("Fifth29Boot")
			await _fifth29_reflection()
			target="Fifth30Checkpoint"
		"29_direct_boot":
			_off("Fifth29Boot")
			await _fifth29_bounce()
			airborne=true
			target="Fifth30Checkpoint"
		"30_parachute":
			await _more_walk(-1060)
			target="Fifth30Lower"
		"30_wind":
			await _fifth30_lower()
			stage.get_node("Items/Fifth30Wind").wind_acceleration=0
			await _more_walk(-2200)
			target="Fifth31Checkpoint"
		"31_boot":
			_off("Fifth31Boot")
			await _more_walk(-1150)
			target="Fifth31Rest"
		"31_bumper":
			_off("Fifth31Bumper")
			await _more_walk(-1150)
			target="Fifth31Rest"
		"31_refill":
			_off("Fifth31Dash")
			await _fifth31_reflection()
			target="FifthSummit"
		"31_direct_refill":
			_off("Fifth31Dash")
			await _fifth31_bounce()
			airborne=true
			target="FifthSummit"
	await _fifth_flight(section,_world_floor(target),direction,timing,airborne,true,-1300.0 if kind in ["31_boot","31_bumper"] else NAN)
	attempts+=1

func _fifth_flight(section: int,target: Rect2,direction: Vector2,timing: int,airborne:=false,use_extra:=true,first_target:=NAN) -> void:
	var before:=respawns
	if not airborne:await _upper_pulse("jump")
	var started:=Engine.get_physics_frames()
	var dashed:=false
	var reflected_dash:=false
	var reflected_at: int=-1
	var bounce_before:=upper_bounces
	var reached:=false
	var next_extra:=16
	actions.clear()
	for frame in 480:
		if not player.is_dashing():
			Input.action_release("move_up")
			Input.action_release("move_down")
			_horizontal((first_target if dashed else player.position.x) if is_finite(first_target) and upper_bounces==bounce_before else target.get_center().x)
		var elapsed:=Engine.get_physics_frames()-started
		if use_extra and elapsed>=next_extra and not player.is_dashing() and player.get_available_extra_jump_count()>0:
			await _upper_pulse("jump")
			next_extra+=16
		if elapsed>=timing and not dashed:
			_release_direction(direction)
			await _upper_pulse("dash")
			dashed=true
		if upper_bounces>bounce_before and reflected_at<0:reflected_at=Engine.get_physics_frames()
		if reflected_at>=0 and Engine.get_physics_frames()-reflected_at>=timing+18 and not reflected_dash and player.is_dash_ready():
			await _upper_dash()
			reflected_dash=true
		if player.wall_actions_enabled and player.is_on_wall() and frame%12==0:await _upper_pulse("jump")
		await _step()
		reached=reached or stage.checkpoint_index>section or stage.completed or (player.is_on_floor() and absf(player.position.y+26-target.position.y)<5 and player.position.x>=target.position.x-18 and player.position.x<=target.end.x+18)
		if reached or respawns>before:break
	_check(not reached,"The finite native omission does not reach the actual destination: cp=%d target=%s direction=%s timing=%d p=%s actions=%s"%[section+1,target,direction,timing,player.position,actions])
	_release()

func _carried_green() -> void:
	await _fresh_fourth(25)
	monitor_view=false
	await _fifth26()
	var object: Grabbable=player.get_held_object()
	_check(object==stage.get_node("Items/Fifth26Companion") and stage.checkpoint_index==26,"The same native Green is physically carried through the preceding throw, wall and upper landing")
	_off("Fifth27Dash")
	actions.clear()
	await _upper_pulse("jump")
	await _step(18)
	await _upper_pulse("jump")
	await _step(20)
	await _upper_dash()
	await _land_on(200,-33746,300)
	await _more_walk(450)
	_horizontal(player.position.x-100)
	await _step(2)
	_release()
	await _step(3)
	await _more_walk(450)
	await _more_climb("Fifth27Wall")
	await _more_walk(900)
	_check(stage.checkpoint_index==27 and respawns==0 and actions.get("creature_jump",0)==1 and stage.get_node("Items/Fifth27Dash").visible,"An actually transported companion legitimately replaces the left refill before the right wall")
	actual_transports+=1

func _old_para_step(direction: Vector2) -> void:
	await _fresh_fourth(23)
	monitor_view=false
	await _fourth_updraft_rest()
	await _fourth_down_rest()
	await _boot_transfer(-930,"Fourth24Boot",-1350,-30666)
	await _more_walk(-1500)
	var object: Grabbable=player.get_held_object()
	_check(object==stage.get_node("Items/Fourth24Parachute") and stage.checkpoint_index==24,"The actual old twenty-fourth route transports its same native parachute to CP25")
	await _more_bounce(-1700,"Fourth25Bumper",Vector2(-1550,-31780))
	await _more_refill("Fourth25Dash",-1450,Vector2(-1300,-32280))
	await _more_walk(-1050)
	_check(player.get_held_object()==object and stage.checkpoint_index==25 and respawns==0,"The same parachute really travels through the old final course into CP26")
	actual_transports+=1
	var support:=await _stand_on_real_object()
	_check(support==object,"The carried old parachute supplies a real physical support")
	Input.action_press("wall_grab")
	await _upper_pulse("jump")
	player.wall_actions_enabled=false
	await _fifth_flight(25,_world_floor("Fifth26Rest"),direction,20,true,false)
	attempts+=1

func _glide_coyote(grace: int,direction: Vector2,timing: int) -> void:
	await _fresh_fourth(29)
	monitor_view=false
	await _more_walk(-1080)
	Input.action_press("move_left",upper_strength)
	for frame in 60:
		await _step()
		if not player.is_on_floor():break
	_check(not player.is_on_floor(),"The coyote comparison really leaves the native launch edge without a parachute")
	await _step(grace)
	actions.clear()
	await _upper_pulse("jump")
	_check(actions.get("jump",0)==1,"The actual coyote input produces a normal Jump")
	await _fifth_flight(29,_world_floor("Fifth30Lower"),direction,timing,true,false)
	attempts+=1
