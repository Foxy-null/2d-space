extends Area2D

@export_range(0.0, 3000.0) var minimum_bounce_speed := 800.0
@export_range(0.0, 3000.0) var maximum_bounce_speed := 1200.0
@export_range(0.0, 1000.0) var min_impact_normal_speed := 50.0
var _contacts: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body is PlayerController or _contacts.has(body.get_instance_id()):
		return
	_contacts[body.get_instance_id()] = true
	var normal := -global_transform.y.normalized()
	var incoming: Vector2 = body.get_environment_velocity()
	var impact := -incoming.dot(normal)
	if (body.global_position - global_position).dot(normal) < 0.0 or impact < maxf(min_impact_normal_speed, 0.001):
		return
	var reflected := incoming.bounce(normal)
	# Positive incident normal speed guarantees an outward reflected normal.
	var speed := clampf(incoming.length(), minimum_bounce_speed, maxf(minimum_bounce_speed, maximum_bounce_speed))
	body.launch_from_spring(reflected.normalized() * speed)


func _on_body_exited(body: Node2D) -> void:
	_contacts.erase(body.get_instance_id())
