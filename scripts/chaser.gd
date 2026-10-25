extends PlayerController
## Uses the player's physics and abilities, with room-local decisions instead of Input.

signal needle_attack(origin: Vector2, directions: Array[Vector2], variant: int)
signal ash_attack(origin: Vector2, target_at: Vector2, down: Vector2)

const ENEMY_GROUP_NAME := "UMA妖怪エイリアン"
const ENEMY_NAME := "星間山荒・大赤斑"
const SPRITE = preload("res://scripts/chaser_sprite.gd")
var defeated := false
var _needle_cooldown := 3.0
var _needle_warning := -1.0
var _needle_aim := Vector2.RIGHT
var _ash_target := Vector2.ZERO
var _needle_variant := 0
var _needle_recovery := 0.0
var _aim_line: Line2D
var target: PlayerController
var course: StageSixRoom
var preferred_item := ""
var active := false
var throw_pose_left := 0.0
var _movement := Vector2.ZERO
var _commands: Dictionary = {}
var _previous: Dictionary = {}
var _jump_clock := 0.0
var _dash_clock := 0.0
var _attack_left := -1.0
var _attack_cooldown := 1.8
var _held_time := 0.0
var _pickup_left := 0.0
var _trail: Array[Dictionary] = []
var _trail_index := 0
var _scan_left := 0.0


func _ready() -> void:
	super._ready()
	remove_from_group("player")
	add_to_group("spike_immune")
	collision_mask |= 2
	$Camera2D.enabled = false
	$Visuals/Body.hide()
	$Visuals/Body.set_process(false)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "EnemySprite"
	sprite.set_script(SPRITE)
	sprite.set("actor", self)
	visuals.add_child(sprite)
	carry_offset.y = -94.0
	_aim_line = Line2D.new()
	_aim_line.width = 2.0
	_aim_line.default_color = Color("ffc57999")
	add_child(_aim_line)
	var warning := Label.new()
	warning.name = "ThrowWarning"
	warning.position = Vector2(-48, -166)
	warning.text = "投げる！"
	warning.add_theme_font_size_override("font_size", 20)
	warning.add_theme_color_override("font_color", Color("ffdc78"))
	warning.add_theme_color_override("font_outline_color", Color("15162c"))
	warning.add_theme_constant_override("outline_size", 4)
	add_child(warning)
	var nameplate := Label.new()
	nameplate.position = Vector2(-90, -140)
	nameplate.text = ENEMY_NAME
	nameplate.add_theme_font_size_override("font_size", 15)
	nameplate.add_theme_color_override("font_outline_color", Color("15162c"))
	nameplate.add_theme_constant_override("outline_size", 4)
	add_child(nameplate)
	object_released.connect(func(_object, thrown):
		_pickup_left = 0.75
		if thrown:
			throw_pose_left = 0.25
	)


func _process(delta: float) -> void:
	throw_pose_left = maxf(0.0, throw_pose_left - delta)
	$ThrowWarning.visible = _attack_left >= 0.0 or _needle_warning >= 0.0
	$ThrowWarning.text = ["針：直線！", "針：三方向！", "追尾トゲ！", "灰の雨！"][_needle_variant] if _needle_warning >= 0.0 else "投げる！"
	_aim_line.visible = _needle_warning >= 0.0
	_aim_line.points = PackedVector2Array([-get_gravity_vector() * 65.0, -get_gravity_vector() * 65.0 + _needle_aim * 260.0])



func _physics_process(delta: float) -> void:
	_commands.clear()
	_movement = Vector2.ZERO
	if not is_instance_valid(target):
		return
	# Follow the path actually taken, including gravity gates, rather than racing to the exit.
	if _trail.is_empty() or target.position.distance_to(_trail.back().at) > 55.0 or target.gravity_direction != _trail.back().gravity:
		_trail.append({"at": target.position, "gravity": target.gravity_direction})
		# shortcut: retain 512 breadcrumbs; use a navigation graph for much longer rooms.
		if _trail.size() > 512:
			_trail.pop_front()
			_trail_index = maxi(0, _trail_index - 1)
	if not active:
		return
	_jump_clock = maxf(0.0, _jump_clock - delta)
	_dash_clock = maxf(0.0, _dash_clock - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_pickup_left = maxf(0.0, _pickup_left - delta)
	_scan_left -= delta
	_update_needle_attack(delta)
	if stun_left <= 0.0 and controls_enabled and _needle_warning < 0.0 and _needle_recovery <= 0.0:
		_steer(delta)
	super._physics_process(delta)
	_previous = _commands.duplicate()


func _steer(delta: float) -> void:
	var down := get_gravity_vector()
	var tangent := get_walk_axis()
	while _trail_index < _trail.size() - 1 and gravity_direction == _trail[_trail_index].gravity and global_position.distance_to(_trail[_trail_index].at) < 75.0:
		_trail_index += 1
	var destination: Vector2 = _trail[_trail_index].at if not _trail.is_empty() else target.position
	var to_target := target.position - position
	if gravity_direction == target.gravity_direction and to_target.length() < 280.0 and absf(to_target.dot(down)) < 65.0 and _can_see_target() and not course.hazard_ahead(self, to_target.dot(tangent)):
		destination = target.position
		_trail_index = maxi(0, _trail.size() - 1)
	var difference := destination - global_position
	var along := difference.dot(tangent)
	var climbing := difference.dot(down) < -8.0 or (is_on_wall() and difference.dot(down) < 30.0 and absf(along) > 26.0)
	var holding := get_held_object() != null
	if not holding:
		_held_time = 0.0
		if _scan_left <= 0.0 and not is_wall_grabbing():
			_scan_left = 0.15
			var closest: Grabbable
			var score := INF
			for item in get_tree().get_nodes_in_group("grabbable"):
				if not item is Grabbable or item.carrier != null or is_instance_valid(item.pinned_to) or course.item_on_switch(item):
					continue
				var distance := position.distance_squared_to(item.position)
				if distance > pow(grab_range + 30.0, 2):
					continue
				if item.carry_name == preferred_item:
					distance *= 0.5
				if distance < score:
					score = distance
					closest = item
			if closest != null:
				try_begin_grab(closest)
		holding = get_held_object() != null
	else:
		_held_time += delta
	_movement = tangent * signf(along) if absf(along) > 14.0 else Vector2.ZERO
	# Move around a platform's underside instead of pressing the umbrella into it forever.
	if climbing and is_on_ceiling():
		for index in get_slide_collision_count():
			var collision := get_slide_collision(index)
			var body := collision.get_collider()
			if collision.get_normal().dot(down) > 0.5 and body is StaticBody2D and body.get_child(0) is CollisionShape2D:
				var shape: CollisionShape2D = body.get_child(0)
				if shape.shape is RectangleShape2D:
					var half: Vector2 = shape.shape.size * 0.5
					var extent := absf(tangent.x) * half.x + absf(tangent.y) * half.y + 45.0
					var side := signf((position - body.position).dot(tangent))
					if side == 0.0:
						side = signf(along) if along != 0.0 else 1.0
					along = (body.position - position).dot(tangent) + extent * side
					_movement = tangent * signf(along)
	var danger := course.hazard_ahead(self, along)
	var wall_climb := is_on_wall() and climbing and not holding and get_wall_stamina() > 0.15
	_commands["wall_grab"] = holding or wall_climb
	if wall_climb:
		_movement -= down
	var ahead := global_position + tangent * signf(along) * 80.0
	var query := PhysicsRayQueryParameters2D.create(ahead, ahead + down * 100.0, collision_mask, [get_rid(), target.get_rid()])
	var gap_ahead := get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	var needs_jump := ((is_on_floor() or _coyote_left > 0.0) and (climbing or gap_ahead or danger)) or (is_on_wall() and climbing and not wall_climb) or (not is_on_floor() and not wall_climb and velocity.dot(down) > -70.0 and (climbing or danger) and get_available_extra_jump_count() > 0)
	if needs_jump and _jump_clock <= 0.0:
		_commands["jump"] = true
		_jump_clock = 0.22
	if not holding and _contacts_valid and is_on_floor() and not climbing and not gap_ahead and absf(along) > 420.0:
		if is_dashing() and _superdash_left > 0.0 and _dash_left < dash_duration - 0.05:
			_commands["jump"] = true
		elif is_dash_ready() and _dash_clock <= 0.0:
			_commands["dash"] = true
			_dash_clock = 1.8
	if _contacts_valid and not wall_climb and not _commands.get("jump", false) and is_dash_ready() and not is_on_floor() and difference.length() > 160.0 and velocity.dot(down) > (-350.0 if danger else -150.0):
		_commands["dash"] = true
		_movement = (-down if climbing and absf(along) < 70.0 else (tangent * signf(along) - down).normalized()) if danger else (difference.normalized() if climbing or absf(along) < 70.0 else tangent * signf(along))
	var needs_umbrella := holding and is_finite(get_held_object().fall_speed_limit()) and not is_on_floor()
	if holding and not needs_umbrella and _held_time > 0.55 and _attack_cooldown <= 0.0 and global_position.distance_to(target.global_position) < 500.0 and _can_see_target():
		if _attack_left < 0.0:
			_attack_left = 0.45
		_attack_left -= delta
		if _attack_left <= 0.0:
			_movement = (target.global_position - global_position).normalized()
			_commands["dash"] = is_dash_ready()
			_commands["wall_grab"] = false
			_attack_left = -1.0
			_attack_cooldown = 2.0
	else:
		_attack_left = -1.0
	if holding and is_on_wall() and climbing and _held_time > 0.55 and not needs_umbrella:
		_commands["wall_grab"] = false


func _can_see_target() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1, [get_rid(), target.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func get_movement_input() -> Vector2:
	return _movement


func try_begin_grab(object: Grabbable) -> bool:
	return _pickup_left <= 0.0 and (not is_instance_valid(course) or not course.item_on_switch(object)) and super.try_begin_grab(object)


func _pressed(action: StringName) -> bool:
	return bool(_commands.get(action, false))


func _just_pressed(action: StringName) -> bool:
	return _pressed(action) and not bool(_previous.get(action, false))


func reset_pursuit(keep_path := false) -> void:
	respawn(false)
	defeated = false
	_needle_variant = 0
	throw_pose_left = 0.0
	_needle_warning = -1.0
	_needle_cooldown = 3.0
	_needle_recovery = 0.0
	_attack_left = -1.0
	_attack_cooldown = 1.8
	_pickup_left = 0.0
	_commands.clear()
	_previous.clear()
	if not keep_path:
		_trail.clear()
	_trail_index = 0
	_scan_left = 0.0
	_held_time = 0.0
	_jump_clock = 0.0
	_dash_clock = 0.0


func _update_needle_attack(delta: float) -> void:
	_needle_cooldown = maxf(0.0, _needle_cooldown - delta)
	_needle_recovery = maxf(0.0, _needle_recovery - delta)
	if stun_left > 0.0 or not controls_enabled or defeated:
		_needle_warning = -1.0
		_needle_cooldown = maxf(_needle_cooldown, 1.0)
		return
	if _needle_warning >= 0.0:
		_needle_warning -= delta
		if _needle_warning <= 0.0:
			var directions: Array[Vector2] = [_needle_aim]
			if _needle_variant == 1:
				directions.assign([_needle_aim.rotated(-0.25), _needle_aim, _needle_aim.rotated(0.25)])
			var origin := global_position - get_gravity_vector() * 65.0
			if _needle_variant == 3:
				ash_attack.emit(origin, _ash_target, get_gravity_vector())
			else:
				needle_attack.emit(origin, directions, _needle_variant)
			_needle_variant = (_needle_variant + 1) % 4
			_needle_warning = -1.0
			_needle_cooldown = 3.0
			_needle_recovery = 0.65
		return
	var distance := global_position.distance_to(target.global_position)
	if _needle_cooldown <= 0.0 and get_held_object() == null and distance > 130.0 and distance < 700.0 and _can_see_target():
		_needle_aim = (target.global_position - (global_position - get_gravity_vector() * 65.0)).normalized()
		_ash_target = target.global_position
		_needle_warning = 0.8 if _needle_variant == 0 else 1.0
