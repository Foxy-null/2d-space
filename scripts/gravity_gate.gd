extends Area2D

@export var moving_enabled := false
@export var move_offset := Vector2(300, 0)
@export_range(0.0, 2000.0) var move_speed := 120.0
@export_range(0.0, 10.0) var endpoint_wait_time := 0.5

var _initial_position := Vector2.ZERO
var _toward_b := true
var _endpoint_wait_left := 0.0

@export_enum("Down:1", "Up:-1") var target_gravity := -1:
	set(value):
		target_gravity = value
		if is_node_ready():
			_update_visuals()


func _ready() -> void:
	_initial_position = position
	_update_visuals()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# Disabling movement pauses both travel and waiting; enabling resumes them.
	if not moving_enabled or move_speed <= 0.0 or move_offset.is_zero_approx():
		return
	if _endpoint_wait_left > 0.0:
		var waited := minf(delta, _endpoint_wait_left)
		_endpoint_wait_left -= waited
		delta -= waited
	var target := _initial_position + move_offset if _toward_b else _initial_position
	position = position.move_toward(target, move_speed * delta)
	if position.is_equal_approx(target):
		_toward_b = not _toward_b
		_endpoint_wait_left = endpoint_wait_time


func _update_visuals() -> void:
	var tint := Color(1.0, 0.3, 0.35) if target_gravity < 0 else Color(0.55, 0.98, 1.0)
	$Arrow.text = "↓" if target_gravity > 0 else "↑"
	$Arrow.add_theme_color_override("font_color", tint)
	$Glow.color = Color(tint, 0.22)
	$Glow.hide()
	$Arrow.add_theme_color_override("font_outline_color", ArtDraw.INK)
	$Arrow.add_theme_constant_override("outline_size", 5)
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = ($CollisionShape2D.shape as RectangleShape2D).size * 0.5
	var tint := ArtDraw.CORAL if target_gravity < 0 else ArtDraw.CYAN
	for side in [0.0, PI]:
		var points := PackedVector2Array()
		for i in 25:
			var angle: float = side - PI / 2 + 0.3 + i * (PI - 0.6) / 24
			points.append(Vector2(cos(angle), sin(angle)) * half)
		draw_polyline(points, ArtDraw.INK, 13, true)
		draw_polyline(points, tint, 8, true)
		for tip in [points[0], points[-1]]:
			draw_circle(tip, 6, ArtDraw.INK)
			draw_circle(tip, 3.5, Color("84848b"))
	if moving_enabled:
		var direction := move_offset.normalized()
		var center := Vector2(0, -half.y - 20)
		ArtDraw.arrow(self, center - direction * 16, center + direction * 16, Color("bdb5c7"), 2)
		ArtDraw.arrow(self, center + direction * 16, center - direction * 16, Color("bdb5c7"), 2)


func reset_for_respawn() -> void:
	position = _initial_position
	_toward_b = true
	_endpoint_wait_left = 0.0


func _on_body_entered(body: Node) -> void:
	if not body is PlayerController:
		return
	# Enter notifications can arrive after retry; retain the player’s last swept contact.
	var body_shape: CollisionShape2D = body.get_node("CollisionShape2D")
	var previous_motion: Vector2 = -body.get_environment_velocity() * get_physics_process_delta_time()
	if not $CollisionShape2D.shape.collide_with_motion($CollisionShape2D.global_transform, Vector2.ZERO, body_shape.shape, body_shape.global_transform, previous_motion):
		return
	body.set_gravity_direction(target_gravity)
