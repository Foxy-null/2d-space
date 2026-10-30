extends "res://tests/gravity_fifth_route_test.gd"

const AIMS := [Vector2.RIGHT,Vector2(1,-1),Vector2.UP,Vector2(-1,-1),Vector2.LEFT,Vector2(-1,1),Vector2.DOWN,Vector2(1,1)]
var comparisons := 0


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_fifth_required_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	var only := "all"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	_check(only in ["all","remaining","refill30","boots","wind","steps","relay","held-relay","final-relay","spring","wall","roof","super"], "Select a known finite comparison group")
	if only in ["all","held-relay","final-relay"]: await _held_left_refill()
	if only in ["all","relay","final-relay"]: await _no_left_refill()
	if only in ["all","refill30"]: await _no_high_refill()
	if only in ["all","remaining","boots"]: await _no_boots()
	if only in ["all","remaining","wind"]: await _no_wind_or_parachute()
	if only in ["all","remaining","steps"]: await _real_steps()
	if only in ["all","remaining","spring"]: await _no_spring()
	if only in ["all","remaining","wall"]: await _no_kicks()
	if only in ["all","remaining","roof"]: await _outer_routes()
	if only in ["all","super"]: await _superdash_left_refill()
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_FIFTH_REQUIRED_TEST_%s %d comparisons %d checks" % ["FAILED" if failed else "OK",comparisons,checks])
	quit(1 if failed else 0)


func _prepare(index: int) -> void:
	await _fresh_para(index)
	monitor_view = false
	_fifth_connect()


func _observe(target: float, limit: int = 300, allow_kicks: bool = true, inverted := false) -> void:
	for frame in limit:
		if respawns > 0: break
		_para_drive(target, allow_kicks)
		if allow_kicks and frame%20 == 0 and (player.is_on_floor() or player.is_on_wall()): await _jump()
		await _step()
		if respawns>0: break
		_check(not stage.cleared.has(stage.room_index) and not _fifth_floor("ExitFloor"), "The finite omitted-action route cannot reach the actual exit floor or arrival")
		if inverted: _check(player.gravity_direction==-1,"The finite attempt cannot reach the real Down gate before dying")


func _no_high_refill() -> void:
	for takeoff in [300,330,360]:
		for gap in [16,24]:
			for aim in AIMS:
				await _prepare(29)
				stage.rooms.get_child(29).get_node("DashCrystal").queue_free()
				await _step(2)
				await _para_walk(takeoff)
				await _jump()
				await _step(gap)
				await _jump()
				await _step(gap)
				await _para_dash(aim)
				await _observe(650)
				_check(not flips.has(-1), "Without high recovery, the real boots and one Dash cannot reach Up, including landing on the lower bulkhead")
				comparisons += 1
				print("FIFTH_NO_HIGH_REFILL x=%d gap=%d aim=%s deaths=%d" % [takeoff,gap,aim,respawns])


func _no_boots() -> void:
	for aim in AIMS:
		await _prepare(29)
		stage.rooms.get_child(29).get_node("Boots").queue_free()
		await _step(2)
		await _para_walk(330)
		await _jump()
		await _step(24)
		await _para_dash(aim)
		await _observe(650)
		_check(not flips.has(-1), "An ordinary Jump and representative Dash cannot replace the real extra-jump boots")
		comparisons += 1


func _no_wind_or_parachute() -> void:
	for index in [27,30]:
		for missing in ["wind","parachute"]:
			for aim in AIMS:
				await _prepare(index)
				var room: Node2D = stage.rooms.get_child(index)
				if missing == "wind":
					room.get_node("Updraft").wind_acceleration = 0
					await _para_grab()
				else:
					room.get_node("Parachute").queue_free()
					await _step(2)
				_para_drive(450 if index == 27 else 1900)
				await _jump()
				await _step(20)
				await _para_dash(aim)
				await _observe(650 if index == 27 else 1550)
				_check(not _fifth_floor("WindRest") and not flips.has(-1), "The real high rest cannot be reached while omitting " + missing)
				comparisons += 1


func _real_steps() -> void:
	for index in [27,30]:
		for aim in AIMS:
			await _prepare(index)
			var room: Node2D = stage.rooms.get_child(index)
			room.get_node("Updraft").wind_acceleration = 0
			var creature: Grabbable = room.get_node("Parachute")
			await _para_walk(creature.position.x+(-100 if _para_x()<creature.position.x else 100))
			_para_drive(creature.position.x)
			await _jump()
			var supported := false
			for frame in 180:
				_para_drive(creature.position.x)
				await _step()
				for contact in player.get_slide_collision_count():
					var collision := player.get_slide_collision(contact)
					if collision.get_collider()==creature and collision.get_normal().dot(Vector2.UP)>0.8: supported = true
				if supported: break
			_check(supported and player.is_on_floor(), "The actual umbrella must physically support the player before the step comparison")
			Input.action_press("wall_grab")
			_para_drive(450 if index==27 else 1900,true)
			await _jump()
			await _step(20)
			await _para_dash(aim)
			await _observe(650 if index==27 else 1550)
			_check(not _fifth_floor("WindRest") and not flips.has(-1), "An actual object step plus Grab/Jump and Dash cannot replace the wind")
			comparisons += 1
			print("FIFTH_REAL_STEP room=%d support=%s aim=%s" % [index+1,supported,aim])


func _no_left_refill() -> void:
	for index in [26,30]:
		for gap in [16,24,32]:
			for aim in AIMS:
				await _prepare(index)
				await _fifth_entry(index)
				stage.rooms.get_child(index).get_node("DashCrystal").queue_free()
				await _step(2)
				await _para_walk(1664 if index==26 else 1150)
				_para_drive(1000 if index==26 else 550)
				await _jump()
				await _step(gap)
				await _para_dash(aim)
				for frame in 300:
					if respawns>0: break
					_para_drive(1000 if index==26 else 550,true)
					if frame%20==0 and (player.is_on_floor() or player.is_on_wall()): await _jump()
					await _step()
					if respawns>0: break
					_check(not _fifth_floor("LandingCeiling") and player.gravity_direction==-1 and not stage.cleared.has(index), "Without the horizontal refill, one Dash cannot reach the left ceiling or Down (gap=%d aim=%s)" % [gap,aim])
				comparisons += 1
				print("FIFTH_NO_LEFT_REFILL room=%d gap=%d aim=%s deaths=%d" % [index+1,gap,aim,respawns])


func _no_spring() -> void:
	for gap in [16,24,32]:
		for aim in AIMS:
			await _prepare(28)
			await _fifth_entry(28)
			await _para_walk(1664)
			_para_drive(1200)
			await _jump()
			await _step(20)
			await _para_dash(Vector2.LEFT)
			await _para_walk(1200)
			stage.rooms.get_child(28).get_node("CeilingSpring").collision_mask = 0
			await _para_walk(1030)
			_para_drive(800)
			await _jump()
			await _step(gap)
			await _para_dash(aim)
			await _observe(800,300,true,true)
			_check(actions.get("fifth_spring",0)==0,"The controlled omitted-Spring comparison really has no actual launch")
			comparisons += 1


func _held_left_refill() -> void:
	var probe := OS.get_cmdline_user_args().has("--probe-held")
	for aim in ([Vector2.LEFT] if probe else AIMS):
		await _prepare(30)
		await _para_grab()
		await _para_rise(1900,620,1550)
		_para_drive(1250)
		await _jump()
		await _until(func(): return player.gravity_direction==-1,180,"Enter native Up while keeping the actual umbrella")
		await _para_walk(1250)
		await _fifth_rest("held_comparison")
		stage.rooms.get_child(30).get_node("DashCrystal").queue_free()
		await _para_walk(1150)
		_para_drive(550)
		await _jump()
		await _step(24)
		if probe: print("HELD_START x=%.2f y=%.2f" % [_para_x(),player.position.y])
		await _para_dash(aim)
		for frame in 400:
			if respawns>0: break
			_para_drive(550,true)
			await _step()
			if respawns>0: break
			if probe and frame%8==0: print("HELD_TRACE f=%d x=%.2f y=%.2f vy=%.2f held=%s" % [frame,_para_x(),player.position.y,player.velocity.y,player.get_held_object()!=null])
			_check(not _fifth_floor("LandingCeiling") and player.gravity_direction==-1 and not stage.cleared.has(30),"The actual retained umbrella cannot replace the left refill (aim=%s)" % aim)
		comparisons += 1
		print("FIFTH_HELD_RELAY aim=%s deaths=%d" % [aim,respawns])


func _no_kicks() -> void:
	for index in [25,27]:
		for aim in AIMS:
			await _prepare(index)
			var origin := 0.0 if index==25 else 600.0
			if index==27:
				await _para_grab()
				await _para_rise(450,1060,650)
				await _fifth_release_toward(600)
				await _para_walk(820)
			await _para_walk(origin+270)
			_fifth_grip(origin+310)
			await _step(60)
			await _para_dash(aim)
			for frame in 240:
				if respawns>0: break
				_fifth_grip(origin+480)
				await _step()
				_check(not flips.has(-1) and not stage.cleared.has(index), "Climbing and a representative Dash without any wall kick cannot reach Up")
			_check(actions.get("wall_jump",0)==0, "The omitted-kick comparison really performs zero wall kicks")
			comparisons += 1


func _outer_routes() -> void:
	for index in range(25,31):
		for aim in [Vector2.UP,Vector2(1,-1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
			await _prepare(index)
			_para_drive(stage.rooms.get_child(index).get_node("Goal").position.x)
			await _jump()
			await _step(24)
			await _para_dash(aim)
			await _observe(stage.rooms.get_child(index).get_node("Goal").position.x,360)
			comparisons += 1
			print("FIFTH_OUTER room=%d aim=%s deaths=%d" % [index+1,aim,respawns])


func _superdash_left_refill() -> void:
	for variant in ["bare27","bare31","held31"]:
		var index := 26 if variant=="bare27" else 30
		for delay in [0,4,8]:
			for followup in [16,24]:
				await _prepare(index)
				if variant=="held31":
					await _para_grab()
					await _para_rise(1900,620,1550)
					_para_drive(1250)
					await _jump()
					await _until(func():return player.gravity_direction==-1,180,"The actual held umbrella reaches Up for the Superdash comparison")
					await _para_walk(1250)
					await _fifth_rest("super_held_comparison")
				else: await _fifth_entry(index)
				stage.rooms.get_child(index).get_node("DashCrystal").queue_free()
				await _step(2)
				await _para_walk(1800 if index==26 else 1250)
				await _para_dash(Vector2.LEFT)
				await _step(delay)
				await _jump()
				_check(actions.get("superdash",0)==1,"The finite alternative really launches one surface Dash-to-Jump")
				await _step(followup)
				# A genuine ground Dash may retain its charge; spend it rather than assuming it was lost.
				if respawns==0 and player.is_dash_ready(): await _para_dash(Vector2.LEFT)
				for frame in 360:
					if respawns>0: break
					_para_drive(1000 if index==26 else 550,true)
					if frame%20==0 and (player.is_on_floor() or player.is_on_wall()):await _jump()
					await _step()
					if respawns>0: break
					_check(not _fifth_floor("LandingCeiling") and player.gravity_direction==-1 and not stage.cleared.has(index),"The actual Superdash and any genuinely retained Dash cannot omit the left refill")
				comparisons+=1
				print("FIFTH_SUPER_RELAY variant=%s delay=%d followup=%d deaths=%d"%[variant,delay,followup,respawns])
