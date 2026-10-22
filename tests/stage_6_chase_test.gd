extends SceneTree
## Real enemy physics: pursuit, climbing, umbrella recovery, and the final cage approach.

var stage
var checks := 0
var arena: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	stage._load_room(1)
	stage._immunity_left = 999.0
	stage._chase_delay = 0.0
	stage.player.set_physics_process(false)
	stage.player.position = Vector2(1100, 794)
	await _step(240)
	_check(stage.enemy.position.x > 900 and stage.enemy.position.x < 1200, "Enemy pursues the player instead of the exit")
	stage.player.position.x = 600
	await _step(150)
	_check(stage.enemy.position.x < 760, "Enemy reverses to chase a backtracking player")
	var path_size: int = stage.enemy.get("_trail").size()
	stage.enemy.call("reset_pursuit", true)
	_check(path_size > 0 and stage.enemy.get("_trail").size() == path_size and stage.enemy.get("_trail_index") == 0, "Enemy retry replays the remembered route instead of losing gravity gates")
	stage.set_physics_process(false)
	stage.room.set_physics_process(false)
	await _wall_climb()
	await _umbrella()
	await _final_approach()
	var worst := 0.0
	for number in 12:
		var start := Time.get_ticks_usec()
		stage._load_room(number)
		worst = maxf(worst, (Time.get_ticks_usec() - start) / 1000.0)
		await _step(2)
	print("STAGE_6_CHASE_TEST_OK (%d checks), maximum room construction %.2f ms" % [checks, worst])
	quit()


func _wall_climb() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	_block(Rect2(0, -5300, 1000, 60))
	_block(Rect2(550, -5580, 250, 280))
	_position(Vector2(460, -5326), Vector2(680, -5606))
	var climbed := false
	for frame in 240:
		await _step()
		climbed = climbed or stage.enemy.is_wall_grabbing()
		if stage.enemy.position.y < -5595 and stage.enemy.position.x > 570:
			break
	_check(climbed, "Enemy actually grabs and climbs the wall")
	_check(stage.enemy.position.y < -5595 and stage.enemy.position.x > 570, "Enemy reaches the top using shared player physics")
	arena.free()


func _umbrella() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	_block(Rect2(0, -4300, 1000, 60))
	_block(Rect2(400, -4560, 240, 32))
	var wind: Area2D = stage.room.WIND.instantiate()
	wind.position = Vector2(500, -4550)
	wind.area_size = Vector2(900, 600)
	wind.wind_direction = Vector2.UP
	wind.wind_acceleration = 2600.0
	wind.max_wind_speed = 500.0
	arena.add_child(wind)
	_position(Vector2(510, -4326), Vector2(760, -4700))
	var umbrella: Grabbable = stage.room.UMBRELLA.instantiate()
	umbrella.position = stage.enemy.position + Vector2(25, -10)
	arena.add_child(umbrella)
	await _step(2)
	_check(stage.enemy.try_begin_grab(umbrella) or stage.enemy.get_held_object() == umbrella, "Enemy acquires a real umbrella")
	for frame in 360:
		await _step()
		if stage.enemy.position.y < -4640:
			break
	_check(stage.enemy.position.y < -4640, "Umbrella enemy goes around the underside of terrain and keeps rising")
	_check(stage.enemy.get_held_object() == umbrella, "Enemy keeps its umbrella during the wind climb")
	stage.enemy.release_grab()
	arena.free()


func _final_approach() -> void:
	stage._load_room(11)
	stage.room.set_physics_process(true)
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	for door in stage.room.doors:
		var item: Grabbable = (stage.room.HEAVY if door.button.required_weight > 2 else stage.room.LIGHT).instantiate()
		item.position = door.button.position - Vector2(0, 60)
		stage.room.get_node("Items").add_child(item)
	await _step(30)
	_position(Vector2(2250, 1454), Vector2(3370, 1094))
	var trail: Array[Dictionary] = []
	for point in [Vector2(2280, 1454), Vector2(2340, 1364), Vector2(2540, 1274), Vector2(2740, 1184), Vector2(2910, 1094), Vector2(3090, 1094), Vector2(3370, 1094)]:
		trail.append({"at": point, "gravity": 1})
	stage.enemy.set("_trail", trail)
	var entered_cage := false
	for frame in 1200:
		await _step()
		if stage.room.cage.encloses(Rect2(stage.enemy.position - Vector2(26, 26), Vector2(52, 52))):
			entered_cage = true
			break
	_check(entered_cage, "Live enemy climbs the final stairs and enters the sealing cage")


func _position(enemy_at: Vector2, player_at: Vector2) -> void:
	stage.enemy.set_respawn_position(enemy_at)
	stage.enemy.call("reset_pursuit")
	stage.player.position = player_at
	stage.player.velocity = Vector2.ZERO
	stage.player.set_gravity_direction(1)
	stage.enemy.set("active", true)
	stage.enemy.set_physics_process(true)


func _block(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	body.add_child(shape)
	arena.add_child(body)


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("CHASE: %s; enemy=%s" % [message, stage.enemy.position])
		quit(1)
