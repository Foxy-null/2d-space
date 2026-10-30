extends Area2D

signal launched(body: PlayerController)

@export_range(0.0, 3000.0) var spring_speed := 900.0
var _contacts: Dictionary = {}
var _reaction := 0.0


func _ready() -> void:
	$Base.hide()
	$Arrow.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body is PlayerController or _contacts.has(body.get_instance_id()):
		return
	# Retry may move the player away before a queued enter notification arrives.
	var body_shape: CollisionShape2D = body.get_node("CollisionShape2D")
	var previous_motion: Vector2 = -body.get_environment_velocity() * get_physics_process_delta_time()
	if not $CollisionShape2D.shape.collide_with_motion($CollisionShape2D.global_transform, Vector2.ZERO, body_shape.shape, body_shape.global_transform, previous_motion):
		return
	_contacts[body.get_instance_id()] = true
	var normal := -global_transform.y.normalized()
	var incoming: Vector2 = body.get_environment_velocity()
	if (body.global_position - global_position).dot(normal) < 0.0 or incoming.dot(normal) > 0.01:
		return
	body.launch_from_spring(incoming + normal * (spring_speed - incoming.dot(normal)))
	_reaction = 0.18
	launched.emit(body)


func _on_body_exited(body: Node2D) -> void:
	_contacts.erase(body.get_instance_id())


func _process(delta: float) -> void:
	if _reaction > 0:
		_reaction = maxf(_reaction - delta, 0)
		queue_redraw()


func _draw() -> void:
	ArtDraw.box(self, Rect2(-27, 13, 54, 9), Color("8d909a"))
	var coil := PackedVector2Array()
	for i in 9:
		coil.append(Vector2(-13 if i % 2 == 0 else 13, 11 - i * 2.0))
	draw_polyline(coil, ArtDraw.INK, 5, true)
	draw_polyline(coil, Color("c0bec3"), 2.5, true)
	ArtDraw.polygon(self, PackedVector2Array([Vector2(-31, -7), Vector2(-25, -16), Vector2(24, -16), Vector2(31, -7), Vector2(29, -2), Vector2(-29, -2)]), ArtDraw.CORAL)
	draw_polyline(PackedVector2Array([Vector2(-8, -7), Vector2(0, -12), Vector2(8, -7)]), ArtDraw.CREAM, 3, true)
	if _reaction > 0:
		for x in [-19.0, 0.0, 19.0]:
			draw_line(Vector2(x, -23), Vector2(x, -27 - _reaction * 20), Color(ArtDraw.CREAM, _reaction / 0.18), 2, true)
