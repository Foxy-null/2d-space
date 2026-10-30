class_name SpikeBlock
extends Area2D
## A moving lethal volume, including a swept test for fast dashes.

signal player_hit

@export var travel := Vector2(0, 240)
@export var period := 3.0
@export_range(0.0, 1.0) var phase := 0.0
@export var room_number := 0
@export var half_size := 20.0
@export var ceiling_strip := false
@export var external_collision := false
@export var strip_half_width := 640.0
@export var stage_group := &"stage_four"

var elapsed := 0.0
var origin := Vector2.ZERO
var previous_player := Vector2.ZERO
var tracking := false
var pending_hit := false
var previous_position := Vector2.ZERO


func _ready() -> void:
	# Run after the character so collision uses its current movement segment.
	process_physics_priority = 10
	origin = position
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	if external_collision:
		var surface := AnimatableBody2D.new()
		surface.collision_layer = 2
		surface.collision_mask = 0
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = hit_extent() * 2.0
		surface.add_child(shape)
		add_child(surface)
	reset_for_respawn()


func reset_for_respawn() -> void:
	elapsed = 0.0
	position = origin + travel * _progress()
	previous_position = global_position
	tracking = false
	pending_hit = false
	queue_redraw()


func _progress() -> float:
	return (1.0 - cos(TAU * (elapsed / maxf(period, 0.1) + phase))) * 0.5


func _physics_process(delta: float) -> void:
	if external_collision:
		return
	var stage := get_tree().get_first_node_in_group(stage_group)
	if stage == null or stage.room_index != room_number or stage.transitioning:
		tracking = false
		return
	var player: PlayerController = stage.player
	if not player.controls_enabled:
		tracking = false
		return
	var before := global_position
	advance(delta)
	var player_shape := player.get_node("CollisionShape2D") as CollisionShape2D
	var local_extent := hit_extent()
	var hazard_extent := global_transform.x.abs() * local_extent.x + global_transform.y.abs() * local_extent.y
	var extent := (player_shape.shape as RectangleShape2D).size * 0.5 + hazard_extent
	var end := player.global_position - global_position
	var start := end
	if tracking and previous_player.distance_to(player.global_position) < 200.0:
		start = previous_player - before
	previous_player = player.global_position
	tracking = true
	if not pending_hit and segment_hits_box(start, end, extent):
		pending_hit = true
		_hit.call_deferred(player)


func advance(delta: float) -> void:
	previous_position = global_position
	elapsed += delta
	position = origin + travel * _progress()
	if not travel.is_zero_approx():
		queue_redraw()


static func segment_hits_box(start: Vector2, end: Vector2, extent: Vector2) -> bool:
	var lower := 0.0
	var upper := 1.0
	var direction := end - start
	for axis in 2:
		if absf(direction[axis]) < 0.00001:
			if absf(start[axis]) > extent[axis]:
				return false
		else:
			var first := (-extent[axis] - start[axis]) / direction[axis]
			var last := (extent[axis] - start[axis]) / direction[axis]
			lower = maxf(lower, minf(first, last))
			upper = minf(upper, maxf(first, last))
			if lower > upper:
				return false
	return true


func _hit(player: PlayerController) -> void:
	if not pending_hit or not is_instance_valid(player):
		return
	var stage := get_tree().get_first_node_in_group(stage_group)
	if stage != null and stage.room_index == room_number and player.controls_enabled and not stage.transitioning:
		player_hit.emit()
		player.die()
	pending_hit = false


func hit_extent() -> Vector2:
	return Vector2(strip_half_width, 16) if ceiling_strip else Vector2.ONE * half_size


func _draw() -> void:
	if ceiling_strip:
		draw_rect(Rect2(-strip_half_width, -16, strip_half_width * 2, 16), Color("333b50"))
		for x in range(-int(strip_half_width), int(strip_half_width), 20):
			var points := PackedVector2Array([Vector2(x, 0), Vector2(x + 10, 16), Vector2(x + 20, 0)])
			draw_colored_polygon(points, Color("ff5361"))
			draw_polyline(points, Color("6c263c"), 1.5, true)
		return
	var a := origin - position
	var b := a + travel
	var amber := Color("e6ad6477")
	if not travel.is_zero_approx():
		var length := travel.length()
		var direction := travel / length
		for distance in range(0, int(length), 14):
			draw_line(a + direction * distance, a + direction * minf(distance + 6, length), amber, 1.5, true)
		for endpoint in [a, b]:
			draw_circle(endpoint, 4, amber)
	var core := half_size - 8.0
	draw_rect(Rect2(Vector2.ONE * -core, Vector2.ONE * core * 2), Color("333b50"))
	draw_rect(Rect2(Vector2.ONE * -core, Vector2.ONE * core * 2), Color("a1a8b8"), false, 2)
	for side in 4:
		for offset in [-core * 0.65, 0.0, core * 0.65]:
			var triangle := PackedVector2Array()
			for point in [Vector2(offset - 4, -core), Vector2(offset, -half_size), Vector2(offset + 4, -core)]:
				triangle.append(point.rotated(side * PI / 2))
			draw_colored_polygon(triangle, Color("ff5361"))
			draw_polyline(triangle, Color("6c263c"), 1.2, true)
	draw_circle(Vector2.ZERO, 4, Color("8793a8"))
