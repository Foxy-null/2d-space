@tool
extends Area2D

@export var wind_direction := Vector2.RIGHT:
	set(value):
		wind_direction = value
		_refresh()
@export_range(0.0, 5000.0) var wind_acceleration := 900.0:
	set(value):
		wind_acceleration = value
		_refresh()
@export_range(0.0, 3000.0) var max_wind_speed := 500.0:
	set(value):
		max_wind_speed = value
		_refresh()
@export var area_size := Vector2(260, 240):
	set(value):
		area_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		if is_node_ready():
			_update_shape()
		queue_redraw()

var _players: Dictionary = {}


func _ready() -> void:
	set_notify_transform(true)
	_update_shape()
	queue_redraw()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _update_shape() -> void:
	var shape := RectangleShape2D.new()
	shape.size = area_size
	$CollisionShape2D.set_deferred("shape", shape)


func _refresh() -> void:
	queue_redraw()
	for reference: WeakRef in _players.values():
		var player = reference.get_ref()
		if is_instance_valid(player):
			player.register_wind(self, wind_direction.normalized() * wind_acceleration, max_wind_speed)


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		_players[body.get_instance_id()] = weakref(body)
		body.register_wind(self, wind_direction.normalized() * wind_acceleration, max_wind_speed)


func _on_body_exited(body: Node2D) -> void:
	if body is PlayerController:
		body.unregister_wind(self)
		_players.erase(body.get_instance_id())


func _exit_tree() -> void:
	for reference: WeakRef in _players.values():
		var player = reference.get_ref()
		if is_instance_valid(player):
			player.unregister_wind(self)
	_players.clear()


func _draw() -> void:
	var rect := Rect2(-area_size * 0.5, area_size)
	draw_rect(rect, Color(0.55, 0.8, 1.0, 0.13))
	draw_rect(rect, Color(0.55, 0.8, 1.0, 0.45), false, 2.0)
	# Convert the world direction into local coordinates, including editor rotation.
	var direction := global_transform.basis_xform_inv(wind_direction).normalized()
	if direction.is_zero_approx():
		return
	var tip := direction * minf(40.0, minf(area_size.x, area_size.y) * 0.3)
	var tint := Color(0.75, 0.9, 1.0, 0.8)
	draw_line(-tip, tip, tint, 4.0)
	draw_line(tip, tip - direction.rotated(0.6) * 16.0, tint, 4.0)
	draw_line(tip, tip - direction.rotated(-0.6) * 16.0, tint, 4.0)
