extends SceneTree

var failed := false
var world: Node2D
var player: PlayerController


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	for y in [600.0, 0.0]:
		var solid := StaticBody2D.new()
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(1200, 40)
		collision.shape = shape
		solid.add_child(collision)
		solid.position = Vector2(600, y + (20 if y > 0 else -20))
		world.add_child(solid)
	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(300, 574)
	world.add_child(player)
	var sprite := player.get_node("Visuals/Body") as AnimatedSprite2D
	_check(sprite != null, "Original ninja replaces placeholder")
	_check(sprite.sprite_frames.get_frame_count("walk") == 2, "Two original walk key poses")
	_check(sprite.sprite_frames.get_frame_count("wall_climb") == 2, "Two climbing key poses")
	_check(sprite.sprite_frames.get_frame_count("carry_walk") == 2, "Two carrying key poses")
	_check(sprite.sprite_frames.get_frame_texture("fall", 0).resource_path.ends_with("kouka.png"), "Normal descent uses kouka")
	_check(sprite.sprite_frames.get_frame_texture("bonk", 0).resource_path.ends_with("rakka.png"), "Head impact uses rakka")
	await _step(4)
	_check(sprite.animation == &"idle", "Standing pose")
	Input.action_press("move_right")
	await _step(8)
	_check(sprite.animation == &"walk" and not sprite.flip_h, "Walk right")
	Input.action_release("move_right")
	Input.action_press("jump")
	await _step(2)
	Input.action_release("jump")
	_check(sprite.animation == &"jump", "Jump ascent")
	await _step(25)
	_check(sprite.animation == &"fall", "Descent follows velocity, not a fixed timeline")
	for gravity in [1, -1]:
		player.respawn()
		player.position = Vector2(300, 574 if gravity > 0 else 26)
		player.set_gravity_direction(gravity)
		Input.action_press("move_right")
		await _step(12)
		_check(not sprite.flip_h if gravity > 0 else sprite.flip_h, "Screen-right facing under both gravities")
		Input.action_release("move_right")
		Input.action_press("move_left")
		await _step(12)
		_check(sprite.flip_h == (gravity > 0), "Screen-left facing under both gravities")
		Input.action_release("move_left")
		Input.action_press("dash")
		await _step(2)
		_check(player.is_dashing() and sprite.animation == &"jump", "Dash uses a clear jump key pose")
		Input.action_release("dash")
	var wall := StaticBody2D.new()
	var wall_collision := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(40, 500)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	wall.position = Vector2(500, 300)
	world.add_child(wall)
	for gravity in [1, -1]:
		player.respawn()
		player.position = Vector2(456, 300)
		player.set_gravity_direction(gravity)
		Input.action_press("move_right")
		Input.action_press("wall_grab")
		await _step(8)
		_check(sprite.animation == &"wall_grab" and sprite.flip_h == (gravity < 0), "Face the grabbed wall under both gravities")
		Input.action_press("move_up" if gravity > 0 else "move_down")
		await _step(4)
		_check(sprite.animation == &"wall_climb", "Climbing loop follows actual motion")
		Input.action_press("jump")
		await _step(1)
		_check(sprite.animation == &"jump" and sprite.flip_h == (gravity > 0), "Wall kick faces away from the wall")
		for action in ["move_right", "move_up", "move_down", "wall_grab", "jump"]:
			Input.action_release(action)
	var indicator: Node2D = player.get_node("Visuals/ExtraJumpIndicator")
	_check(absf(indicator.position.x) > 18.0, "Jump counter is beside the outfit")
	for name in ["grabbable", "heavy_object", "jump_creature", "parachute_creature"]:
		player.respawn()
		player.position = Vector2(300, 400)
		player.set_physics_process(false)
		var object := load("res://scenes/" + name + ".tscn").instantiate() as Grabbable
		object.position = player.position + Vector2(35, 0)
		world.add_child(object)
		object.freeze = true
		await _step(2)
		_check(player.try_begin_grab(object), "Carry " + name)
		await _step(2)
		_check(sprite.animation == &"carry_idle", "Raised hands for " + name)
		for gravity in [1, -1]:
			player.set_gravity_direction(gravity)
			await _step(10)
			var size := (object.collider.shape as RectangleShape2D).size
			var artwork := object.visuals.get_node("Body") as AnimatedSprite2D
			if artwork != null:
				size = artwork.sprite_frames.get_frame_texture(artwork.animation, artwork.frame).get_size() * artwork.scale
			_check(absf(size.x * object.visuals.scale.x - 90.0) < 0.01, "2.5 body widths: " + name)
			_check(object.visuals.scale.x == object.visuals.scale.y, "Preserve aspect ratio: " + name)
			var bottom: float = object.visuals.position.y + size.y * object.visuals.scale.y * 0.5 * gravity
			_check(absf(object.position.y + bottom - player.position.y + 28.0 * gravity) < 0.01, "Large item meets raised palms: " + name)
			_check(object.rotation == 0.0, "Visual gravity does not rotate physics: " + name)
			if name == "parachute_creature":
				_check(object.visuals.position.x * player.facing_direction > 0.0, "Umbrella handle reaches the forward palm")
		player.respawn()
		object.queue_free()
	print("CHARACTER_SPRITES_TEST_%s" % ["FAILED" if failed else "OK"])
	quit(1 if failed else 0)


func _step(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
		# process_frame fires before the sprite's _process; timers run after nodes.
		await create_timer(0.0).timeout


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
