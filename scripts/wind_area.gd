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
var _time := 0.0


func _process(delta: float) -> void:
	_time = fposmod(_time + delta, 6.0)
	queue_redraw()


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
	draw_rect(rect, Color(0.55, 0.8, 1.0, 0.035))
	# Convert the world direction into local coordinates, including editor rotation.
	var direction := global_transform.basis_xform_inv(wind_direction).normalized()
	if direction.is_zero_approx():
		return
	var tint := Color(0.65, 0.88, 1.0, 0.55)
	for i in 9:
		var phase := fposmod(_time / 6.0 + float(i) / 9, 1.0)
		var offset := Vector2(fposmod(i * 73.0, maxf(area_size.x - 20, 1)), fposmod(i * 97.0, maxf(area_size.y - 20, 1)))
		if absf(direction.x) > absf(direction.y):
			offset.x = (phase if direction.x > 0 else 1.0 - phase) * maxf(area_size.x - 20, 1)
		else:
			offset.y = (phase if direction.y > 0 else 1.0 - phase) * maxf(area_size.y - 20, 1)
		var center := rect.position + Vector2(10, 10) + offset
		ArtDraw.arrow(self, center - direction * 9, center + direction * 9, Color(tint, tint.a * sin(phase * PI)), 1.5)
	var distance := absf(direction.x) * area_size.x / 2 + absf(direction.y) * area_size.y / 2
	var fan := -direction * (distance - 16)
	ArtDraw.ellipse(self, fan, Vector2(14, 14), Color("8e939f"))
	ArtDraw.ellipse(self, fan, Vector2(10, 10), Color("444756"), 1.5)
	for i in 3:
		var angle := _time * TAU / 6 + i * TAU / 3
		draw_line(fan, fan + Vector2.from_angle(angle) * 8, Color("b9c4cf"), 3, true)
