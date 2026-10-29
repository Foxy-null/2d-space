class_name TutorialBridge
extends Node2D

const BOARD := preload("res://assets/tutorial/bridge-board.png")
var planks: Array[StaticBody2D] = []
var front := 224.0
var running := false
var tip_collapsed := false
var elapsed := 0.0


func _ready() -> void:
	for section in TutorialLandscape.bridge_sections():
		var x := section.x
		while x < section.y:
			var width := minf(60.0, section.y - x)
			var body := StaticBody2D.new()
			body.position = Vector2(x + width / 2, 634)
			var collision := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(width, 28)
			collision.shape = shape
			body.add_child(collision)
			body.set_meta("width", width)
			body.set_meta("fall", -1.0)
			add_child(body)
			planks.append(body)
			x += width


func reset() -> void:
	front = 224.0
	running = false
	tip_collapsed = false
	elapsed = 0.0
	for plank in planks:
		plank.set_meta("fall", -1.0)
		plank.collision_layer = 1
	queue_redraw()


func collapse_tip() -> void:
	if tip_collapsed:
		return
	tip_collapsed = true
	for plank in planks:
		if plank.position.x >= 2600 and float(plank.get_meta("fall")) < 0:
			plank.collision_layer = 0
			plank.set_meta("fall", elapsed)


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	elapsed += delta
	if running:
		front += 362.0 * delta
	for plank in planks:
		var fall: float = plank.get_meta("fall")
		if fall < 0 and (plank.position.x < front or (tip_collapsed and plank.position.x >= 2600)):
			plank.collision_layer = 0
			plank.set_meta("fall", elapsed)
	queue_redraw()


func _draw() -> void:
	for plank in planks:
		var fall: float = plank.get_meta("fall")
		var age := elapsed - fall if fall >= 0 else 0.0
		if age > 1.2:
			continue
		var width: float = plank.get_meta("width")
		var offset := Vector2(0, 250.0 * age * age)
		draw_set_transform(plank.position + offset, age * 0.8, Vector2.ONE)
		draw_texture_rect(BOARD, Rect2(-width / 2 - 1, -14, width + 2, 28), false, Color(1, 1, 1, 1.0 - age / 1.2))
	draw_set_transform(Vector2.ZERO)
