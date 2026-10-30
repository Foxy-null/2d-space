extends PlayerController
## Uses the player's physics and abilities, with room-local decisions instead of Input.

signal needle_attack(origin: Vector2, directions: Array[Vector2], variant: int)
signal ash_attack(origin: Vector2, target_at: Vector2, down: Vector2)

const ENEMY_GROUP_NAME := "UMA妖怪エイリアン"
const ENEMY_NAME := "星間山荒・大赤斑"
const SPRITE = preload("res://scripts/chaser_sprite.gd")
const ATTACK_NAMES := ["長針3連射", "扇形の針", "追尾トゲ6発", "灰雲の雨", "山なりの長針", "短針の連射"]
const FAN_ANGLES := [-0.5, -0.25, 0.0, 0.25, 0.5]
const HOMING_ANGLES := [-0.75, -0.45, -0.15, 0.15, 0.45, 0.75]
var defeated := false
var _needle_cooldown := 1.0
var _needle_warning := -1.0
var _needle_aim := Vector2.RIGHT
var _ash_target := Vector2.ZERO
var _needle_variant := 0
var _needle_recovery := 0.0
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
var awareness := "patrol"
var capture_windup := -1.0
var capture_recovery := 0.0
var _has_seen := false
var _last_seen := Vector2.ZERO
var _last_gravity := 1
var _lost_left := 0.0
var _search_left := 2.5
var _volley_left := 0
var _volley_clock := 0.0
var _attack_origin := Vector2.ZERO
var _attack_down := Vector2.DOWN
var _stuck_left := 0.0
var _progress_at := Vector2.ZERO
var _detour_left := 0.0
var _detour_side := 1.0
var _patrol_origin := Vector2.ZERO
var _patrol_side := 1.0
var _ledge_body: StaticBody2D
var _ledge_goal := Vector2.ZERO
var _mobile_cast := false
var _warning_spans: Array[Vector2] = []
var _last_velocity := Vector2.ZERO
var _last_attack := -1
var _technique_wait := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


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
	var warning := Label.new()
	warning.name = "ThrowWarning"
	warning.position = Vector2(-48, -166)
	warning.text = "投げる！"
	warning.add_theme_font_size_override("font_size", 20)
	warning.add_theme_color_override("font_color", Color("ffdc78"))
	warning.add_theme_color_override("font_outline_color", Color("15162c"))
	warning.add_theme_constant_override("outline_size", 4)
	add_child(warning)
	var state := Label.new()
	state.name = "PursuitState"
	state.position = Vector2(-42, -194)
	state.add_theme_font_size_override("font_size", 15)
	state.add_theme_color_override("font_outline_color", Color("15162c"))
	state.add_theme_constant_override("outline_size", 4)
	add_child(state)
	var cue := AudioStreamPlayer2D.new()
	cue.name = "AttackCue"
	cue.max_distance = 1300.0
	cue.volume_db = -12.0
	add_child(cue)
	object_released.connect(func(_object, thrown):
		_pickup_left = 0.75
		if thrown:
			throw_pose_left = 0.25
	)


func _process(delta: float) -> void:
	throw_pose_left = maxf(0.0, throw_pose_left - delta)
	$ThrowWarning.visible = _attack_left >= 0.0 or _needle_warning >= 0.0 or _volley_left > 0 or _needle_recovery > 0.0 or capture_windup >= 0.0
	$ThrowWarning.text = "掴む！" if capture_windup >= 0.0 else ("隙！" if _needle_recovery > 0.0 and _volley_left == 0 else (ATTACK_NAMES[_needle_variant] + "！" if _needle_warning >= 0.0 or _volley_left > 0 else "投げる！"))
	$PursuitState.text = "準備中" if not active else {"pursuit": "追跡中", "search": "探索中", "patrol": "見失った"}[awareness]
	$PursuitState.modulate = Color("ff9b9b") if awareness == "pursuit" else Color("ffdc78")
	queue_redraw()



func _physics_process(delta: float) -> void:
	_commands.clear()
	_movement = Vector2.ZERO
	if not is_instance_valid(target):
		return
	_update_perception(delta)
	if not active:
		return
	_jump_clock = maxf(0.0, _jump_clock - delta)
	_dash_clock = maxf(0.0, _dash_clock - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_pickup_left = maxf(0.0, _pickup_left - delta)
	capture_recovery = maxf(0.0, capture_recovery - delta)
	_scan_left -= delta
	_update_needle_attack(delta)
	if stun_left <= 0.0 and controls_enabled and capture_windup < 0.0 and (_mobile_cast or (_needle_warning < 0.0 and _volley_left == 0 and _needle_recovery <= 0.0)):
		_steer(delta)
	super._physics_process(delta)
	_cache_warning_spans()
	_previous = _commands.duplicate()


func _steer(delta: float) -> void:
	if not _has_seen or awareness == "patrol":
		_commands["wall_grab"] = get_held_object() != null
		if is_on_floor():
			var axis := get_walk_axis()
			var ahead := position + axis * _patrol_side * 65.0
			var query := PhysicsRayQueryParameters2D.create(ahead, ahead + get_gravity_vector() * 100.0, collision_mask, [get_rid(), target.get_rid()])
			if (position - _patrol_origin).dot(axis) * _patrol_side > 150.0 or is_on_wall() or get_world_2d().direct_space_state.intersect_ray(query).is_empty():
				_patrol_side *= -1.0
			_movement = axis * _patrol_side * 0.4
		return
	var down := get_gravity_vector()
	var tangent := get_walk_axis()
	while _trail_index < _trail.size() - 1 and gravity_direction == _trail[_trail_index].gravity and global_position.distance_to(_trail[_trail_index].at) < 75.0:
		_trail_index += 1
	var destination: Vector2 = _trail[_trail_index].at if not _trail.is_empty() else _last_seen
	var desired_gravity: int = _trail[_trail_index].gravity if not _trail.is_empty() else _last_gravity
	var to_target := _last_seen - position
	var visible_climb := to_target.dot(down) < 0.0 and absf(to_target.dot(tangent)) < 360.0
	if gravity_direction == _last_gravity and (absf(to_target.dot(down)) < 65.0 or visible_climb) and _can_see_target():
		destination = _last_seen
		_trail_index = maxi(0, _trail.size() - 1)
	elif gravity_direction != desired_gravity:
		var nearest := INF
		for gate in course.get_children():
			if gate.get("target_gravity") == desired_gravity:
				var distance := global_position.distance_to(gate.global_position)
				if distance < nearest:
					nearest = distance
					destination = gate.global_position
	if is_instance_valid(_ledge_body):
		if not _ledge_body.visible or position.dot(down) <= _ledge_goal.dot(down) + 2.0:
			_ledge_body = null
		else:
			destination = _ledge_goal
	var difference := destination - global_position
	var along := difference.dot(tangent)
	var climbing := difference.dot(down) < -8.0 or (is_on_wall() and (difference.dot(down) < 30.0 or is_wall_grabbing()) and absf(along) > 26.0)
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
				if climbing and item.carry_name in ["OBJECT", "HEAVY"]:
					continue
				if item.carry_name in ["OBJECT", "HEAVY"] and _needle_cooldown < 1.0 and to_target.length() < 700.0 and is_on_floor():
					continue
				if item.carry_name == "HEAVY" and to_target.length() > 500.0:
					continue
				if distance < score:
					score = distance
					closest = item
			if closest != null:
				try_begin_grab(closest)
		holding = get_held_object() != null
	else:
		_held_time += delta
	_movement = tangent * signf(along) if absf(along) > 14.0 else Vector2.ZERO
	# Recover locally without inventing a hidden target position or teleporting.
	_stuck_left = _stuck_left + delta if position.distance_to(_progress_at) < 18.0 else 0.0
	if position.distance_to(_progress_at) >= 18.0:
		_progress_at = position
	if _stuck_left > 1.4:
		_stuck_left = 0.0
		_detour_left = 0.6
		_detour_side = -signf(along) if along != 0.0 else -_detour_side
	_detour_left = maxf(0.0, _detour_left - delta)
	if _detour_left > 0.0 and is_on_floor():
		_movement = tangent * _detour_side
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
					var height := absf(down.x) * half.x + absf(down.y) * half.y + 28.0
					_ledge_body = body
					_ledge_goal = body.global_position + tangent * extent * side - down * height
					difference = _ledge_goal - global_position
					along = difference.dot(tangent)
					_movement = tangent * signf(along) if absf(along) > 10.0 else Vector2.ZERO
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
	if _contacts_valid and not wall_climb and not _commands.get("jump", false) and is_dash_ready() and not is_on_floor() and (difference.length() > 160.0 or (climbing and difference.dot(down) < -55.0)) and velocity.dot(down) > (-350.0 if danger else -150.0):
		_commands["dash"] = true
		_movement = (-down if climbing and absf(along) < 70.0 else (tangent * signf(along) - down).normalized()) if danger else (difference.normalized() if climbing or absf(along) < 70.0 else tangent * signf(along))
	var needs_umbrella := holding and is_finite(get_held_object().fall_speed_limit()) and not is_on_floor()
	if holding and not needs_umbrella and _held_time > 0.55 and _attack_cooldown <= 0.0 and _needle_warning < 0.0 and _volley_left == 0 and _needle_recovery <= 0.0 and global_position.distance_to(target.global_position) < 500.0 and _can_see_target() and not _large_attack_active():
		if _attack_left < 0.0:
			_attack_left = 0.45
		_attack_left -= delta
		if _attack_left <= 0.0:
			_movement = (target.global_position - global_position).normalized()
			_commands["dash"] = is_dash_ready()
			_commands["wall_grab"] = false
			_attack_left = -1.0
			_attack_cooldown = 2.0
			_needle_recovery = 0.65
	else:
		_attack_left = -1.0
	if holding and is_on_wall() and climbing and _held_time > 0.55 and not needs_umbrella:
		_commands["wall_grab"] = false


func _can_see_target() -> bool:
	# The taller enemy can see over a small box; solid cover must block both sight heights.
	for height in [72.0, 18.0]:
		var eye: Vector2 = global_position - get_gravity_vector() * height
		for point in [target.global_position, target.global_position - target.get_gravity_vector() * 26.0]:
			var query := PhysicsRayQueryParameters2D.create(eye, point, 1, [get_rid(), target.get_rid()])
			query.hit_from_inside = true
			if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
				return true
	return false


func get_movement_input() -> Vector2:
	return _movement


func can_begin_grab(object: Grabbable) -> bool:
	return _pickup_left <= 0.0 and super.can_begin_grab(object) and (not is_instance_valid(course) or not course.item_on_switch(object))


func _pressed(action: StringName) -> bool:
	return bool(_commands.get(action, false))


func _just_pressed(action: StringName) -> bool:
	return _pressed(action) and not bool(_previous.get(action, false))


func _apply_variable_jump() -> void:
	# Pursuit issues jump pulses and needs the full jump arc for its steering.
	pass


func reset_pursuit(keep_path := false) -> void:
	respawn(false, false)
	defeated = false
	_needle_variant = course.attack_patterns[0] if is_instance_valid(course) else 0
	_technique_wait.fill(0.0)
	_last_attack = -1
	_last_velocity = Vector2.ZERO
	throw_pose_left = 0.0
	_needle_warning = -1.0
	_needle_cooldown = 1.0
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
	awareness = "search" if keep_path and not _trail.is_empty() else "patrol"
	_has_seen = keep_path and not _trail.is_empty()
	if _has_seen:
		_last_seen = _trail.back().at
		_last_gravity = _trail.back().gravity
	_lost_left = 0.0
	_search_left = 2.5
	_volley_left = 0
	_volley_clock = 0.0
	capture_windup = -1.0
	capture_recovery = 0.0
	_progress_at = position
	_stuck_left = 0.0
	_detour_left = 0.0
	_patrol_origin = position
	_ledge_body = null
	_mobile_cast = false
	$AttackCue.stop()


func _update_perception(delta: float) -> void:
	if _can_see_target():
		_has_seen = true
		awareness = "pursuit"
		_last_seen = target.global_position
		_last_velocity = target.velocity.limit_length(700.0)
		_last_gravity = target.gravity_direction
		_lost_left = 0.0
		_search_left = 2.5
		if _trail.is_empty() or _last_seen.distance_to(_trail.back().at) > 55.0 or _last_gravity != _trail.back().gravity:
			_trail.append({"at": _last_seen, "gravity": _last_gravity})
			# shortcut: 512 observed points; add an ability graph if courses outgrow this history.
			if _trail.size() > 512:
				_trail.pop_front()
				_trail_index = maxi(0, _trail_index - 1)
	elif _has_seen and active:
		_lost_left += delta
		if awareness == "pursuit":
			awareness = "search"
		if position.distance_to(_last_seen) < 100.0:
			_search_left -= delta
		if _search_left <= 0.0 or _lost_left > 8.0:
			if awareness != "patrol":
				_patrol_origin = position
			awareness = "patrol"


func can_capture() -> bool:
	return active and controls_enabled and not defeated and stun_left <= 0.0 and get_held_object() == null and _needle_warning < 0.0 and _volley_left == 0 and _needle_recovery <= 0.0 and capture_recovery <= 0.0


func action_description() -> String:
	if not active:
		return "壁の向こうから近づいている" if course.number > 0 else "こちらに気づいた！ 走って逃げよう"
	if stun_left > 0.0:
		return "箱が命中して怯んでいる — 移動・反撃のチャンス"
	if capture_windup >= 0.0:
		return "掴もうとしている！ 離れて空振りさせよう"
	if _needle_warning >= 0.0:
		return "%sを構えている（あと%.1f秒）" % [ATTACK_NAMES[_needle_variant], maxf(0.0, _needle_warning)]
	if _volley_left > 0:
		return "%sを撃っている — 箱で受けるか、狙いから外れよう" % ATTACK_NAMES[_needle_variant]
	if _needle_recovery > 0.0:
		return "攻撃後の隙 — 今は掴まれない"
	if _attack_left >= 0.0:
		return "持っている物を投げようとしている"
	return {"pursuit": "こちらを追っている — 離れると灰雲で先回りする", "search": "最後に見た場所を探している", "patrol": "見失い、周辺を巡回している"}[awareness]


func _finish_volley() -> void:
	_needle_recovery = 0.75
	_needle_cooldown = 1.8
	_last_attack = _needle_variant
	_technique_wait[_needle_variant] = [3.5, 4.0, 7.0, 7.5, 6.0, 5.0][_needle_variant]


func _large_attack_active() -> bool:
	if course.get_node("AshClouds").get_child_count() > 0:
		return true
	for needle in course.needles.get_children():
		if not needle.stuck and needle.variant == 2 and not needle.is_queued_for_deletion():
			return true
	return false


func _choose_attack() -> int:
	if not _has_seen or _lost_left > 2.0 or _large_attack_active():
		return -1
	var distance := position.distance_to(_last_seen)
	var selected := -1
	var best := -INF
	for kind in course.attack_patterns:
		if _technique_wait[kind] > 0.0:
			continue
		var score := -INF
		match kind:
			0:
				if distance > 130.0 and distance < 850.0: score = 45.0
			1:
				if distance > 130.0 and distance < 500.0: score = 65.0
			2:
				if distance > 250.0 and distance < 1300.0: score = 85.0
			3:
				if distance > 600.0: score = 140.0 + minf(distance, 2400.0) * 0.02
				elif distance > 220.0: score = 50.0
			4:
				if distance > 500.0 and distance < 1900.0: score = 105.0
			5:
				if distance > 180.0 and distance < 1100.0: score = 95.0 if _last_velocity.length() > 60.0 else 60.0
		if kind == _last_attack:
			score -= 30.0
		if score > best:
			best = score
			selected = kind
	return selected


func _aim_at_observed_target(turn_limit: float) -> void:
	var origin := global_position - get_gravity_vector() * 65.0
	var lead := _last_velocity * clampf(origin.distance_to(_last_seen) / 1800.0, 0.0, 0.2)
	var desired := (_last_seen + lead - origin).normalized()
	_needle_aim = _needle_aim.rotated(clampf(_needle_aim.angle_to(desired), -turn_limit, turn_limit))


func _update_needle_attack(delta: float) -> void:
	_needle_cooldown = maxf(0.0, _needle_cooldown - delta)
	_needle_recovery = maxf(0.0, _needle_recovery - delta)
	for i in _technique_wait.size():
		_technique_wait[i] = maxf(0.0, _technique_wait[i] - delta)
	if _needle_warning < 0.0 and _needle_recovery <= 0.0 and _volley_left == 0:
		_mobile_cast = false
	if stun_left > 0.0 or not controls_enabled or defeated:
		_needle_warning = -1.0
		_volley_left = 0
		_mobile_cast = false
		$AttackCue.stop()
		_needle_cooldown = maxf(_needle_cooldown, 1.0)
		return
	if _attack_down != get_gravity_vector() and (_needle_warning >= 0.0 or _volley_left > 0):
		_needle_warning = -1.0
		_volley_left = 0
		_mobile_cast = false
		$AttackCue.stop()
		_needle_cooldown = 1.0
		return
	if _volley_left > 0:
		_volley_clock -= delta
		if _volley_clock <= 0.0:
			if _lost_left > 0.7:
				_volley_left = 0
				_finish_volley()
				return
			_aim_at_observed_target(0.18 if _needle_variant == 5 else 0.28)
			_attack_origin = global_position - _attack_down * 65.0
			var directions: Array[Vector2] = [_needle_aim]
			needle_attack.emit(_attack_origin, directions, _needle_variant)
			_volley_left -= 1
			_volley_clock = 0.08 if _needle_variant == 5 else 0.2
			if _volley_left == 0:
				_finish_volley()
		return
	if _needle_warning >= 0.0:
		_needle_warning -= delta
		if _needle_warning <= 0.0:
			_attack_origin = global_position - _attack_down * 65.0
			_needle_warning = -1.0
			if _needle_variant == 3:
				ash_attack.emit(_attack_origin, _ash_target, _attack_down)
				_finish_volley()
			elif _needle_variant in [1, 2]:
				var directions: Array[Vector2] = []
				for angle in (FAN_ANGLES if _needle_variant == 1 else HOMING_ANGLES):
					directions.append(_needle_aim.rotated(angle))
				needle_attack.emit(_attack_origin, directions, _needle_variant)
				_finish_volley()
			elif _needle_variant == 4:
				var directions: Array[Vector2] = []
				var time := clampf(position.distance_to(_ash_target) / 650.0, 1.1, 2.1)
				for i in 10:
					var landing := _ash_target + get_walk_axis() * (i - 4.5) * 44.0
					directions.append((landing - _attack_origin - _attack_down * 600.0 * time * time) / time)
				needle_attack.emit(_attack_origin, directions, 4)
				_finish_volley()
			else:
				_volley_left = 18 if _needle_variant == 5 else 3
				_volley_clock = 0.0
		return
	if _needle_cooldown > 0.0 or _needle_recovery > 0.0 or capture_windup >= 0.0:
		return
	var selected := _choose_attack()
	if selected < 0:
		return
	var origin := global_position - get_gravity_vector() * 65.0
	var count: int = [3, 5, 6, 36, 10, 18][selected]
	if not course.can_launch_projectiles(origin, [get_rid(), target.get_rid()], count):
		return
	_needle_variant = selected
	_needle_aim = (_last_seen - origin).normalized()
	_ash_target = _last_seen + _last_velocity.limit_length(420.0) * (1.4 if selected == 3 else 0.45)
	_ash_target = _ash_target.clamp(Vector2(80, 100), course.size - Vector2(80, 100))
	_attack_down = get_gravity_vector()
	_needle_warning = 1.1 if selected in [2, 3, 4] else 0.8
	_mobile_cast = true
	$AttackCue.stream = ArrivalSwitch._sound([[330.0, 440.0], [440.0, 440.0, 660.0], [260.0, 390.0, 520.0], [180.0, 240.0, 300.0], [240.0, 420.0], [700.0, 700.0]][selected])
	$AttackCue.play()


func _cache_warning_spans() -> void:
	_warning_spans.clear()
	if _needle_warning < 0.0 and _volley_left == 0:
		return
	if _needle_variant in [3, 4]:
		return
	var origin := global_position - _attack_down * 65.0
	var angles := FAN_ANGLES if _needle_variant == 1 else (HOMING_ANGLES if _needle_variant == 2 else [0.0])
	for angle in angles:
		var end: Vector2 = origin + _needle_aim.rotated(angle) * 900.0
		var query := PhysicsRayQueryParameters2D.create(origin, end, 1, [get_rid(), target.get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		_warning_spans.append(origin)
		_warning_spans.append(hit.position if not hit.is_empty() else end)


func _draw() -> void:
	if _needle_warning < 0.0 and _volley_left == 0:
		return
	var ink := Color("ffc57999")
	if _needle_variant in [3, 4]:
		draw_set_transform(to_local(_ash_target), Vector2.DOWN.angle_to(_attack_down))
		draw_rect(Rect2(-360, -12, 720, 24), Color("ffdc7833"))
		for slot in 9:
			draw_line(Vector2((slot - 4) * 80, -22), Vector2((slot - 4) * 80, 22), ink, 2)
		draw_set_transform(Vector2.ZERO)
	else:
		for index in range(0, _warning_spans.size(), 2):
			draw_line(to_local(_warning_spans[index]), to_local(_warning_spans[index + 1]), ink, 2.0, true)
