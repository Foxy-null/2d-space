extends AnimatedSprite2D

const BASE_SCALE := 52.0 / 661.0
var _was_grounded := false
var _was_ceiling := false
var _landing_left := 0.0
var _bonk_left := 0.0
var _release_left := 0.0
var _was_thrown := false
var _sweat := Node2D.new()
var _sweat_time := 0.0
var _fatigue_phase := 0.0
@onready var player: PlayerController = owner


func _ready() -> void:
	player.object_released.connect(_on_release)
	player.respawned.connect(_reset_pose)
	_sweat.name = "WallSweat"
	_sweat.draw.connect(_draw_sweat)
	_sweat.hide()
	add_child(_sweat)
	play("idle")


func _process(delta: float) -> void:
	_landing_left = maxf(0.0, _landing_left - delta)
	_bonk_left = maxf(0.0, _bonk_left - delta)
	_release_left = maxf(0.0, _release_left - delta)
	var grounded := player.is_on_floor()
	var ceiling := player.is_on_ceiling()
	if grounded and not _was_grounded:
		_landing_left = 0.12
	if ceiling and not _was_ceiling and not grounded:
		_bonk_left = 0.16
	_was_grounded = grounded
	_was_ceiling = ceiling
	var tangent := player.get_walk_axis()
	var down := player.get_gravity_vector()
	var facing := player.facing_direction
	if absf(player.velocity.dot(tangent)) > player.move_speed:
		facing = int(signf(player.velocity.dot(tangent)))
	if player.is_wall_grabbing() and absf(player.get_wall_normal().dot(tangent)) > 0.5:
		facing = -int(signf(player.get_wall_normal().dot(tangent)))
	var visual_right := Vector2.RIGHT.rotated(Vector2.DOWN.angle_to(down))
	var local_facing := facing * int(roundf(tangent.dot(visual_right)))
	flip_h = local_facing < 0
	rotation = 0.0
	speed_scale = 1.0
	var held := player.get_held_object() != null
	var moving := absf(player.get_movement_input().dot(tangent)) > 0.1 and absf(player.velocity.dot(tangent)) > 15.0
	var next: StringName = &"idle"
	if player.is_dashing():
		next = &"carry_idle" if held else &"jump"
		rotation = local_facing * 0.3 if absf(player.velocity.dot(tangent)) > 1.0 else 0.0
	elif not player.controls_enabled and grounded:
		next = &"carry_idle" if held else &"idle"
	elif held:
		next = &"carry_walk" if grounded and moving else &"carry_idle"
	elif player.is_wall_grabbing():
		next = &"wall_climb" if absf(player.velocity.dot(down)) > 10.0 else &"wall_grab"
		speed_scale = clampf(absf(player.velocity.dot(down)) / player.wall_climb_speed, 0.4, 1.0)
	elif _bonk_left > 0.0:
		next = &"bonk"
	elif _release_left > 0.0:
		next = &"jump" if _was_thrown else &"idle"
	elif not grounded:
		var falling := player.velocity.dot(down) > 45.0
		var sliding := player.wall_actions_enabled and player.is_on_wall() and player.get_movement_input().dot(tangent) * player.get_wall_normal().dot(tangent) < -0.1
		next = &"jump" if not falling or sliding else &"fall"
	elif moving:
		next = &"walk"
	if next in [&"walk", &"carry_walk"]:
		speed_scale = clampf(absf(player.velocity.dot(tangent)) / player.move_speed, 0.25, 1.5)
	if animation != next:
		play(next)
	var squash := sin((1.0 - _landing_left / 0.12) * PI) * 0.1 if grounded and _landing_left > 0.0 else 0.0
	scale = Vector2(1.0 + squash, 1.0 - squash) * BASE_SCALE
	position.y = 26.0 * squash
	if next in [&"walk", &"carry_walk"]:
		position.y -= sin(frame_progress * PI) * 0.7
	position.x = local_facing * 4.0 if next in [&"wall_grab", &"wall_climb"] else 0.0
	_update_wall_effects(delta, local_facing, down)


func _update_wall_effects(delta: float, local_facing: int, down: Vector2) -> void:
	var grabbing := player.is_wall_grabbing() and player.controls_enabled
	_sweat.visible = grabbing and not player.is_on_floor() and player.get_movement_input().dot(down) < -0.5
	if _sweat.visible:
		_sweat_time = fposmod(_sweat_time + delta, 0.6)
		_sweat.position = Vector2(-local_facing * 20.0, -24.0) / BASE_SCALE
		_sweat.scale = Vector2.ONE / scale
		_sweat.queue_redraw()
	else:
		_sweat_time = 0.0
	var ratio := player.get_wall_stamina() / player.wall_stamina_max
	var tint := 0.0
	if grabbing and ratio < 0.3:
		var frequency := lerpf(2.5, 1.0, clampf(ratio / 0.3, 0.0, 1.0))
		_fatigue_phase = fposmod(_fatigue_phase + delta * frequency, 1.0)
		tint = (1.0 - cos(_fatigue_phase * TAU)) * 0.5
	else:
		_fatigue_phase = 0.0
	material.set_shader_parameter("fatigue_tint", tint)


func _draw_sweat() -> void:
	var progress := _sweat_time / 0.6
	var alpha := sin(progress * PI)
	var away := 1.0 if flip_h else -1.0
	for index in 3:
		var direction := Vector2(away, (index - 1) * 0.7 - 0.4).normalized()
		_sweat.draw_set_transform(direction * (4.0 + progress * 10.0), direction.angle() - PI / 2.0)
		_sweat.draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(-3.5, 0), Vector2(3.5, 0)]), Color(0.03, 0.12, 0.22, alpha))
		_sweat.draw_circle(Vector2.ZERO, 3.5, Color(0.03, 0.12, 0.22, alpha), true, -1.0, true)
		_sweat.draw_colored_polygon(PackedVector2Array([Vector2(0, -5), Vector2(-2.5, 0), Vector2(2.5, 0)]), Color(0.25, 0.78, 1.0, alpha))
		_sweat.draw_circle(Vector2.ZERO, 2.5, Color(0.25, 0.78, 1.0, alpha), true, -1.0, true)
		_sweat.draw_circle(Vector2(-0.8, -0.4), 0.8, Color(0.8, 0.96, 1.0, alpha), true, -1.0, true)


func _on_release(_object: Grabbable, was_thrown: bool) -> void:
	_release_left = 0.12 if was_thrown else 0.06
	_was_thrown = was_thrown


func _reset_pose() -> void:
	_was_grounded = false
	_was_ceiling = false
	_landing_left = 0.0
	_bonk_left = 0.0
	_release_left = 0.0
	_sweat_time = 0.0
	_fatigue_phase = 0.0
	_sweat.hide()
	material.set_shader_parameter("fatigue_tint", 0.0)
	rotation = 0.0
	scale = Vector2.ONE * BASE_SCALE
	position = Vector2.ZERO
	play("idle")
