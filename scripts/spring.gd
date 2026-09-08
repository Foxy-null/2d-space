extends Area2D

@export_range(0.0, 3000.0) var spring_speed := 900.0
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
	if (body.global_position - global_position).dot(normal) < 0.0 or incoming.dot(normal) > 0.01:
		return
	body.launch_from_spring(incoming + normal * (spring_speed - incoming.dot(normal)))


func _on_body_exited(body: Node2D) -> void:
	_contacts.erase(body.get_instance_id())
