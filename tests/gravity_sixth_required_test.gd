extends "res://tests/gravity_sixth_route_test.gd"

const AIMS := [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]
var comparisons := 0


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_sixth_required_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	var only := "all"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only=arg.trim_prefix("--only=")
		else: _check(arg in ["--weak","--hints"],"Use a known finite-comparison argument")
	_check(only in ["all","remaining","bumper","spring","boots","glide","refill","wall","steps","roof","super","throws"],"Select a known native omission group")
	if failed: return
	para_strength = 0.8 if args_have("--weak") else 1.0
	if only in ["all","remaining","bumper"]: await _no_bumper()
	if only in ["all","spring"]: await _no_spring()
	if only in ["all","remaining","boots"]: await _no_boots()
	if only in ["all","remaining","glide"]: await _no_glide_resource()
	if only in ["all","refill"]: await _no_diagonal_refill()
	if only in ["all","remaining","wall"]: await _no_wall_kicks()
	if only in ["all","remaining","steps"]: await _real_umbrella_step()
	if only in ["all","remaining","roof"]:
		await _outer_routes()
		await _two_stage_entry()
	if only in ["all","remaining","super"]: await _real_superdash()
	if only in ["all","remaining","throws"]: await _real_umbrella_throw()
	monitor_view = false
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_SIXTH_REQUIRED_TEST_%s %d comparisons %d checks" % ["FAILED" if failed else "OK",comparisons,checks])
	quit(1 if failed else 0)


func _prepare(index: int) -> void:
	await _sixth_fresh(index)
	monitor_view = false


func _fifth_rest(_phase: String) -> void:
	_release_inputs()
	if player.get_held_object()!=null: Input.action_press("wall_grab")
	await _step(12)
	_check(player.is_on_floor(),"The omission starts from actual static support; three-second rests belong to the positive matrix")


func _observe(target: float,label: String,floors: Array,kicks := true,climb := 0) -> void:
	for frame in 360:
		if respawns>0: break
		var reached: bool = stage.cleared.has(stage.room_index)
		for name in floors:
			if stage.rooms.get_child(stage.room_index).has_node(name) and _fifth_floor(name): reached=true
		if reached:
			print("SIXTH_BYPASS ",label," local=",Vector2(_para_x(),player.position.y)," velocity=",player.velocity," actions=",actions," respawns=",respawns," flips=",flips)
			_check(false,"The real omission reaches its forbidden native support: "+label)
			return
		_para_drive(target,kicks or climb!=0)
		if climb!=0: Input.action_press("move_down" if climb>0 else "move_up")
		if kicks and frame%20==0 and (player.is_on_floor() or player.is_on_wall()): await _jump()
		await _step()
	comparisons += 1
	if comparisons%16==0: print("SIXTH_FINITE_DONE ",comparisons)
	_check(not stage.cleared.has(stage.room_index),"The finite real comparison remains before its native target: "+label)


func _no_bumper() -> void:
	for gap in [16,24,32]:
		for aim in AIMS:
			await _prepare(32)
			stage.rooms.get_child(32).get_node("CeilingBumper").queue_free()
			await _step(2)
			await _para_walk(1800)
			await _para_walk(1664)
			_para_drive(800)
			await _jump()
			await _step(gap)
			await _para_dash(aim)
			await _observe(800,"no bumper gap%d aim%s" % [gap,aim],["LandingCeiling","ExitFloor"])


func _no_spring() -> void:
	for index in [31,36]:
		for gap in [16,24,32]:
			for aim in AIMS:
				await _prepare(index)
				stage.rooms.get_child(index).get_node("LaunchSpring" if index==31 else "CeilingSpring").queue_free()
				await _step(2)
				await _para_walk(200 if index==31 else 1620)
				_para_drive(360 if index==31 else 1620)
				await _jump()
				await _step(gap)
				await _para_dash(aim)
				await _observe(440 if index==31 else 1620,"no spring room%d gap%d aim%s" % [index+1,gap,aim],["EntryCeiling"] if index==31 else ["MiddleFloor"])


func _no_boots() -> void:
	for gap in [16,24,32]:
		for aim in AIMS:
			await _prepare(33)
			stage.rooms.get_child(33).get_node("Boots").queue_free()
			await _step(2)
			await _para_walk(1664)
			_check(player.gravity_direction==-1 and not player.is_air_jump_ready(),"The real omitted charge remains absent at the inverted entrance")
			_para_drive(1450)
			await _jump()
			await _step(gap)
			await _para_dash(aim)
			await _observe(1200,"no boots gap%d aim%s" % [gap,aim],["LandingCeiling","ExitFloor"])


func _no_glide_resource() -> void:
	for missing in ["wind","parachute"]:
		for gap in [16,24]:
			for aim in AIMS:
				await _prepare(34)
				var room: Node2D = stage.rooms.get_child(34)
				if missing=="wind":
					room.get_node("Crosswind").wind_acceleration=0
					await _para_grab()
				else:
					room.get_node("Parachute").queue_free()
					await _step(2)
				await _para_walk(1800)
				_para_drive(500)
				await _jump()
				await _step(gap)
				await _para_dash(aim)
				await _observe(500,"no %s gap%d aim%s" % [missing,gap,aim],["LandingFloor","ExitFloor"])


func _no_diagonal_refill() -> void:
	for takeoff in [830,890]:
		for gap in [16,24,32]:
			for aim in AIMS:
				await _prepare(35)
				stage.rooms.get_child(35).get_node("DashCrystal").queue_free()
				await _step(2)
				await _sixth_entry(35)
				await _para_walk(takeoff)
				_para_drive(1500)
				await _jump()
				await _step(gap)
				await _para_dash(aim)
				await _observe(1500,"no diagonal refill x%d gap%d aim%s" % [takeoff,gap,aim],["LandingFloor","ExitFloor"])


func _no_wall_kicks() -> void:
	for index in [31,35,36]:
		for gap in [16,24]:
			for aim in AIMS:
				await _prepare(index)
				if index==31:
					await _sixth_entry(index)
					_sixth_down_grip(910)
				elif index==35:
					_fifth_grip(310)
				else:
					await _sixth_entry(index)
					_para_drive(1620)
					await _until(func(): return actions.get("sixth_launch",0)>0,180,"The real Spring reaches the second challenge before the no-kick comparison")
					await _para_walk(1620)
					await _para_walk(1100)
					_fifth_grip(990)
					await _jump()
				await _step(110+gap)
				_check(actions.get("wall_jump",0)==0,"The finite climb keeps wall jumping omitted without disabling the ability")
				await _para_dash(aim)
				await _observe(1100 if index==31 else (440 if index==35 else 860),"no wall kicks room%d gap%d aim%s" % [index+1,gap,aim],["LandingFloor"] if index==31 else ["UpperRest"],false,1 if index==31 else -1)


func _real_umbrella_step() -> void:
	for aim in AIMS:
		await _prepare(34)
		var room: Node2D = stage.rooms.get_child(34)
		room.get_node("Crosswind").wind_acceleration=0
		var creature: Grabbable = room.get_node("Parachute")
		await _para_walk(creature.position.x+70)
		_para_drive(creature.position.x)
		await _jump()
		var supported := false
		for frame in 180:
			_para_drive(creature.position.x)
			await _step()
			for contact in player.get_slide_collision_count():
				var collision := player.get_slide_collision(contact)
				if collision.get_collider()==creature and collision.get_normal().dot(Vector2.UP)>0.8: supported=true
			if supported: break
		_check(supported and player.is_on_floor(),"The actual native umbrella physically supports the player before Grab+Jump")
		_para_drive(500,true)
		await _jump()
		await _step(20)
		_check(player.get_held_object()==creature,"Simultaneous real Grab+Jump holds the actual supporting object")
		await _para_dash(aim)
		await _observe(500,"actual supporting umbrella plus GrabJump aim%s" % aim,["LandingFloor","ExitFloor"])


func _outer_routes() -> void:
	for index in range(31,37):
		for aim in AIMS:
			await _prepare(index)
			_para_drive(2200 if index in [31,35] else 400)
			await _jump()
			await _step(20)
			await _para_dash(aim)
			await _observe(2200 if index in [31,35] else 400,"actual entrance roof/bottom room%d aim%s" % [index+1,aim],["LandingFloor"] if index==31 else (["LandingFloor","ExitFloor"] if index==35 else ["ExitFloor"]))


func _real_superdash() -> void:
	for index in [32,33,34,35]:
		for delay in [0,4,8]:
			for gap in [16,24]:
				await _prepare(index)
				var omitted := "CeilingBumper" if index==32 else ("Boots" if index==33 else ("Parachute" if index==34 else "DashCrystal"))
				stage.rooms.get_child(index).get_node(omitted).queue_free()
				await _step(2)
				if index==35: await _sixth_entry(index)
				await _para_walk(1780 if index in [32,33] else (1900 if index==34 else 750))
				await _para_dash(Vector2.RIGHT if index==35 else Vector2.LEFT)
				await _step(delay)
				await _jump()
				_check(actions.get("superdash",0)>0,"The omission actually triggers Superdash; a failed launch is not a successful negative: room%d delay%d gap%d" % [index+1,delay,gap])
				await _step(gap)
				if player.is_dash_ready(): await _para_dash(Vector2(1,1) if index==35 else Vector2(-1,1))
				await _observe(1500 if index==35 else (800 if index in [32,34] else 1200),"actual Superdash room%d delay%d gap%d" % [index+1,delay,gap],["LandingFloor","ExitFloor"] if index in [34,35] else ["LandingCeiling","ExitFloor"])


func _two_stage_entry() -> void:
	for gap in [16,24]:
		for aim in AIMS:
			await _prepare(31)
			_para_drive(450)
			await _jump()
			await _para_walk(450)
			_check(actions.get("sixth_launch",0)==0 and player.gravity_direction==1 and _fifth_floor("EntryFloor"),"The first real Jump avoids the Spring and lands on the entry floor with Dash available")
			_para_drive(2200)
			await _jump()
			await _step(gap)
			await _para_dash(aim)
			await _observe(2200,"actual two-stage entry floor gap%d aim%s" % [gap,aim],["LandingFloor"])


func _real_umbrella_throw() -> void:
	for strength in [1.0,0.8]:
		para_strength=strength
		for release_frame in [1,8]:
			for aim in [Vector2.LEFT,Vector2(-1,-1),Vector2(-1,1)]:
				await _prepare(34)
				var room: Node2D = stage.rooms.get_child(34)
				room.get_node("Crosswind").wind_acceleration=0
				await _sixth_entry(34)
				var creature: Grabbable=room.get_node("Parachute")
				var thrown := [0]
				player.object_released.connect(func(object: Grabbable,was_thrown: bool):
					if object==creature and was_thrown: thrown[0]+=1
				)
				_para_drive(500)
				await _jump()
				await _step(release_frame)
				_check(player.get_held_object()==creature and respawns==0,"The real inverted launch still holds its native umbrella before throwing")
				Input.action_release("wall_grab")
				await _step()
				_check(thrown[0]==1 and player.get_held_object()==null and creature.carrier==null,"An actual moving release throws the same physical umbrella; a failed release is not a negative")
				await _step(20-release_frame)
				await _para_dash(aim)
				await _observe(500,"actual umbrella throw axis%.1f release%d aim%s"%[strength,release_frame,aim],["LandingFloor","ExitFloor"])
