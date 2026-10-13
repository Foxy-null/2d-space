@tool
extends Area2D

signal launched(body: PlayerController)

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
	launched.emit(body)


func _on_body_exited(body: Node2D) -> void:
	_contacts.erase(body.get_instance_id())


func _draw() -> void:
	ArtDraw.ellipse(self, Vector2.ZERO, Vector2(31, 31), ArtDraw.CORAL, 3)
	for angle in [0.0, PI / 2, PI, PI * 1.5]:
		var p := Vector2.from_angle(angle) * 23
		var radius := Vector2(5, 10) if absf(p.x) > 10 else Vector2(10, 5)
		ArtDraw.ellipse(self, p, radius, ArtDraw.CREAM, 2)
