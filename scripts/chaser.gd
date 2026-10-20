extends PlayerController
## Uses the player's physics and abilities, with room-local decisions instead of Input.

@export var avatar_texture: Texture2D
var target: PlayerController
var course: StageSixRoom
var route: Array[Vector2] = []
var route_index := 0
var preferred_item := ""
var active := false
var throw_pose_left := 0.0
var _movement := Vector2.ZERO
var _commands: Dictionary = {}
var _previous: Dictionary = {}
var _jump_clock := 0.0
var _attack_left := -1.0
var _attack_cooldown := 1.8
var _held_time := 0.0
var _pickup_left := 0.0
var _last_gravity := 1


func _ready() -> void:
	super._ready()
	remove_from_group("player")
	$Camera2D.enabled = false
	$Visuals/Body.hide()
	var body := Polygon2D.new()
	body.name = "Prototype"
	body.polygon = PackedVector2Array([Vector2(-18, -26), Vector2(18, -26), Vector2(18, 15), Vector2(0, 26), Vector2(-18, 15)])
	body.color = Color("59ebff")
	visuals.add_child(body)
	var visor := Polygon2D.new()
	visor.polygon = PackedVector2Array([Vector2(-11, -13), Vector2(11, -13), Vector2(11, 2), Vector2(-11, 2)])
	visor.color = Color("09142e")
	visuals.add_child(visor)
	var arms := Line2D.new()
	arms.name = "Arms"
	arms.width = 6.0
	arms.default_color = Color("59ebff")
	visuals.add_child(arms)
	var warning := Label.new()
	warning.name = "ThrowWarning"
	warning.position = Vector2(-48, -120)
	warning.text = "投げる！"
	warning.add_theme_font_size_override("font_size", 20)
	warning.add_theme_color_override("font_color", Color("ffdc78"))
	warning.add_theme_color_override("font_outline_color", Color("15162c"))
	warning.add_theme_constant_override("outline_size", 4)
	add_child(warning)
	if avatar_texture != null:
		body.hide()
		visor.hide()
		var picture := Sprite2D.new()
		picture.texture = avatar_texture
		picture.scale = Vector2.ONE * 52.0 / avatar_texture.get_height()
		visuals.add_child(picture)
	object_released.connect(func(_object, thrown):
		_pickup_left = 0.75
		if thrown:
			throw_pose_left = 0.25
	)


func _process(delta: float) -> void:
	throw_pose_left = maxf(0.0, throw_pose_left - delta)
	var arms: Line2D = $Visuals/Arms
	var raised := get_held_object() != null
	arms.points = PackedVector2Array([Vector2(-20, -34 if raised else 5), Vector2(-15, -5), Vector2(15, -5), Vector2(30 if throw_pose_left > 0 else 20, -15 if throw_pose_left > 0 else (-34 if raised else 5))])
	$Visuals/Prototype.color = Color("ff9d68") if stun_left > 0 else Color("59ebff")
	$ThrowWarning.visible = _attack_left >= 0.0


func _physics_process(delta: float) -> void:
	_commands.clear()
	_movement = Vector2.ZERO
	if not active or not is_instance_valid(target):
		return
	_jump_clock = maxf(0.0, _jump_clock - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_pickup_left = maxf(0.0, _pickup_left - delta)
	if gravity_direction != _last_gravity:
		if route_index < route.size() and position.distance_to(route[route_index]) < 220.0:
			route_index += 1
		_last_gravity = gravity_direction
	if stun_left <= 0.0 and controls_enabled:
		_steer(delta)
	super._physics_process(delta)
	_previous = _commands.duplicate()


func _steer(delta: float) -> void:
	var destination := target.global_position
	if route_index < route.size():
		destination = route[route_index]
		var floating := get_held_object() != null and is_finite(get_held_object().fall_speed_limit()) and not _winds.is_empty()
		var difference := destination - global_position
		if global_position.distance_to(destination) < 65.0 or (floating and absf(difference.dot(get_walk_axis())) < 80.0 and difference.dot(get_gravity_vector()) > -40.0):
			route_index += 1
	var difference := destination - global_position
	var down := get_gravity_vector()
	var tangent := get_walk_axis()
	var along := difference.dot(tangent)
	_movement = tangent * signf(along) if absf(along) > 14.0 else Vector2.ZERO
	var climbing := difference.dot(down) < -18.0
	var danger := is_instance_valid(course) and course.hazard_ahead(self, along)
	var holding := get_held_object() != null
	if not holding:
		_held_time = 0.0
		var items := get_tree().get_nodes_in_group("grabbable")
		items.sort_custom(func(a, b):
			var a_score: float = global_position.distance_squared_to(a.global_position) * (0.5 if a.carry_name == preferred_item else 1.0)
			var b_score: float = global_position.distance_squared_to(b.global_position) * (0.5 if b.carry_name == preferred_item else 1.0)
			return a_score < b_score
		)
		for item in items:
			if item is Grabbable and try_begin_grab(item):
				break
		holding = get_held_object() != null
	else:
		_held_time += delta
	_commands["wall_grab"] = holding or (is_on_wall() and climbing)
	if is_on_wall() and climbing and not holding:
		_movement -= down
	var ahead := global_position + tangent * signf(along) * 80.0
	var floor_query := PhysicsRayQueryParameters2D.create(ahead, ahead + down * 100.0, 1, [get_rid(), target.get_rid()])
	var gap_ahead := get_world_2d().direct_space_state.intersect_ray(floor_query).is_empty()
	var needs_jump := ((is_on_floor() or _coyote_left > 0.0) and (climbing or gap_ahead or danger)) or (is_on_wall() and climbing) or (not is_on_floor() and velocity.dot(down) > -70.0 and (climbing or danger) and get_available_extra_jump_count() > 0)
	if needs_jump and _jump_clock <= 0.0:
		_commands["jump"] = true
		_jump_clock = 0.22
	if not _commands.get("jump", false) and is_dash_ready() and not is_on_floor() and difference.length() > 160.0 and velocity.dot(down) > (-350.0 if danger else -150.0):
		_commands["dash"] = true
		_movement = (-down if climbing and absf(along) < 70.0 else (tangent * signf(along) - down).normalized()) if danger else (difference.normalized() if climbing or absf(along) < 70.0 else tangent * signf(along))
	if holding and _held_time > 0.55 and _attack_cooldown <= 0.0 and global_position.distance_to(target.global_position) < 500.0 and _can_see_target():
		if _attack_left < 0.0:
			_attack_left = 0.45
		_attack_left -= delta
		throw_pose_left = 0.2
		if _attack_left <= 0.0:
			_movement = (target.global_position - global_position).normalized()
			_commands["dash"] = is_dash_ready()
			_commands["wall_grab"] = false
			_attack_left = -1.0
			_attack_cooldown = 2.0
	else:
		_attack_left = -1.0
	if holding and is_on_wall() and climbing and _held_time > 0.55:
		_commands["wall_grab"] = false


func _can_see_target() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1, [get_rid(), target.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func get_movement_input() -> Vector2:
	return _movement


func try_begin_grab(object: Grabbable) -> bool:
	return _pickup_left <= 0.0 and super.try_begin_grab(object)


func _pressed(action: StringName) -> bool:
	return bool(_commands.get(action, false))


func _just_pressed(action: StringName) -> bool:
	return _pressed(action) and not bool(_previous.get(action, false))


func reset_pursuit() -> void:
	respawn(false)
	route_index = 0
	_attack_left = -1.0
	_attack_cooldown = 1.8
	_pickup_left = 0.0
	_commands.clear()
	_previous.clear()
	_last_gravity = gravity_direction
