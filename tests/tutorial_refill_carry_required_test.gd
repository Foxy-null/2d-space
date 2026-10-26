extends "res://tests/tutorial_refill_carry_scroll_test.gd"

var attempts := 0
var actual_walls := 0

func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://tutorial_refill_carry_required_%d.cfg" % OS.get_process_id()
	_clear_progress()
	await _new_tutorial()
	for index in [4,10]:
		for axis in [1.0,0.8]:
			for launch in ([180,245] if index == 4 else [180,380,600,820,1060]):
				for gap in [16,24]:
					for direction in [Vector2.RIGHT,Vector2(1,-1),Vector2.UP,Vector2(-1,-1),Vector2.LEFT,Vector2(-1,1),Vector2.DOWN,Vector2(1,1)]:
						strength = axis
						await _enter(index)
						_disable_mechanic(index)
						if launch > 900: await _move_to(600)
						await _move_to(launch)
						_check(player.is_on_floor() and player.is_dash_ready(), "The omission comparison starts on a real original floor")
						await _pulse("jump")
						await _step(gap)
						_aim(direction)
						await _pulse("dash")
						await _reject(index, "Jump and eight-way Dash without the actual crystal or boxes")
						if failed: return
	await _one_dash()
	await _held_box()
	await _actual_wall()
	_clear_progress()
	await _close_fixture()
	print("TUTORIAL_REFILL_CARRY_REQUIRED_OK (",checks," checks, ",attempts," routes, ",actual_walls," real wall holds)")
	quit(1 if failed else 0)

func _disable_mechanic(index: int) -> void:
	if index == 4:
		tutorial.rooms.get_child(index).get_node("DashCrystal").collision_mask = 0
	else:
		for name in ["SmallBox","Heavy"]:
			var object: Grabbable = tutorial.rooms.get_child(index).get_node(name)
			object.collision_layer = 0
			object.collision_mask = 0

func _aim(direction: Vector2) -> void:
	for action in ["move_left","move_right","move_up","move_down"]:
		Input.action_release(action)
	if direction.x != 0: Input.action_press("move_right" if direction.x > 0 else "move_left",strength)
	if direction.y != 0: Input.action_press("move_down" if direction.y > 0 else "move_up",strength)

func _reject(index: int, message: String, held: Node = null) -> void:
	var reached := false
	for frame in 200:
		if respawns > 0 or tutorial.room_index != index: break
		reached = reached or _on_loft() or _scroll()._follower == player or progress.has_scroll("tutorial","refill_loft_07" if index == 4 else "box_loft_08")
		_steer(590 if index == 4 else 600)
		if held != null:
			Input.action_press("wall_grab")
			_check(player.get_held_object() == held,"The held-object comparison never throws or steps on the box")
		await _step()
	_check(not reached,message)
	attempts += 1
	_release()

func _one_dash() -> void:
	var receives := 0
	for axis in [1.0,0.8]:
		for gap in [16,20,24]:
			strength = axis
			await _enter(4)
			var crystal: Area2D = tutorial.rooms.get_child(4).get_node("DashCrystal")
			crystal.collision_mask = 1
			await _move_to(245)
			Input.action_press("move_right",strength)
			await _pulse("jump")
			await _step(gap + (8 if strength < 1 else 0))
			Input.action_press("move_up",strength)
			await _pulse("dash")
			Input.action_release("move_up")
			await _until(func(): return tutorial.seen.has("dash_refill"),100,"A real crystal receives the spent dash before omission of its reuse")
			receives += 1
			_release()
			await _reject(4,"Receiving a real refill without using another dash cannot reach the upper branch")
	_check(receives == 6,"The one-dash cases include all six actual crystal contacts")

func _held_box() -> void:
	for axis in [1.0,0.8]:
		for gap in [16,24]:
			for direction in [Vector2.UP,Vector2(1,-1),Vector2(-1,-1)]:
				await _new_tutorial()
				await _enter(10)
				strength = axis
				await _jump_to(330)
				await _move_to(335)
				Input.action_press("wall_grab")
				await _step(4)
				var heavy: Grabbable = tutorial.rooms.get_child(10).get_node("Heavy")
				_check(player.get_held_object() == heavy,"The held comparison starts with the actual original Heavy")
				await _held_move(600)
				await _pulse("jump")
				await _step(gap)
				_aim(direction)
				await _pulse("dash")
				await _reject(10,"Holding the Heavy without using its real support cannot replace the box step",heavy)

func _actual_wall() -> void:
	for axis in [1.0,0.8]:
		for gap in [0,24]:
			for direction in [Vector2.LEFT,Vector2(-1,-1),Vector2.UP]:
				await _enter(10)
				_disable_mechanic(10)
				strength = axis
				await _move_to(600)
				await _move_to(1060)
				Input.action_press("move_right",strength)
				Input.action_press("wall_grab")
				Input.action_press("move_up")
				for frame in 360:
					if player.is_on_floor() and player.is_on_wall(): await _pulse("jump")
					await _step()
					if player.is_wall_grabbing() and _local().x > 1220 and _local().y < -150: break
					if respawns > 0: break
				_check(player.is_wall_grabbing() and _local().x > 1220 and _local().y < -150 and respawns == 0,"The wall omission begins from an actual high hold on the original closed exit")
				actual_walls += 1
				_aim(Vector2.LEFT)
				await _pulse("jump")
				Input.action_release("wall_grab")
				await _step(gap)
				_aim(direction)
				await _pulse("dash")
				await _reject(10,"A real high exit-wall kick cannot bypass the visible upper spike fence")
