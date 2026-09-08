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


func _on_body_entered(body: Node) -> void:
	if body.has_method("set_gravity_direction"):
		body.set_gravity_direction(target_gravity)
