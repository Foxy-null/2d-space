@tool
extends Area2D

@export_range(0.0, 3000.0) var minimum_bounce_speed := 800.0
@export_range(0.0, 3000.0) var maximum_bounce_speed := 1200.0
@export_range(0.0, 1000.0) var min_impact_normal_speed := 50.0
var _contacts: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body is PlayerController or _contacts.has(body.get_instance_id()):
		return
	_contacts[body.get_instance_id()] = true
	var incoming: Vector2 = body.get_environment_velocity()
	# Every point on the circular bumper has its own outward surface normal.
	var normal := (body.global_position - global_position).normalized()
	if normal.is_zero_approx():
		normal = -incoming.normalized()
	var impact := -incoming.dot(normal)
	if impact < maxf(min_impact_normal_speed, 0.001):
		return
	var reflected := incoming.bounce(normal)
	# Positive incident normal speed guarantees an outward reflected normal.
	var speed := clampf(incoming.length(), minimum_bounce_speed, maxf(minimum_bounce_speed, maximum_bounce_speed))
	body.launch_from_spring(reflected.normalized() * speed)


func _on_body_exited(body: Node2D) -> void:
	_contacts.erase(body.get_instance_id())


func _draw() -> void:
	draw_circle(Vector2.ZERO, 32.0, Color(0.45, 0.15, 0.4))
	draw_circle(Vector2.ZERO, 28.0, Color(1.0, 0.45, 0.85))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 64, Color(1.0, 0.85, 0.95), 3.0, true)
	draw_circle(Vector2.ZERO, 9.0, Color(0.45, 0.15, 0.4))
