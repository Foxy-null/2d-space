extends Area2D

signal pressed_changed(is_pressed: bool)

@export var required_weight := 2.0
@export var include_player := false
var total_weight := 0.0
var _pressed := false


func _ready() -> void:
	$Plate.hide()


func _physics_process(_delta: float) -> void:
	refresh_weight()


func refresh_weight() -> void:
	# The engine returns each body once, including bodies with multiple shapes.
	total_weight = 0.0
	for body in get_overlapping_bodies():
		if body is Grabbable and not is_instance_valid(body.carrier):
			total_weight += body.weight
		elif include_player and body is PlayerController:
			total_weight += body.weight
	var next := total_weight >= required_weight
	if next != _pressed:
		_pressed = next
		pressed_changed.emit(_pressed)
		queue_redraw()
	$Plate.color = Color(0.3, 1.0, 0.5) if _pressed else Color(0.7, 0.3, 0.15)
	$Plate.position.y = 3.0 if _pressed else 0.0


func is_pressed() -> bool:
	return _pressed


func reset_for_respawn() -> void:
	total_weight = 0.0
	if _pressed:
		_pressed = false
		pressed_changed.emit(false)
	queue_redraw()


func _draw() -> void:
	var width: float = ($CollisionShape2D.shape as RectangleShape2D).size.x
	ArtDraw.box(self, Rect2(-width / 2, -3, width, 20), Color("777681"))
	ArtDraw.box(self, Rect2(-width / 2 + 3, -12 + (3 if _pressed else 0), width - 6, 12), Color("b2afa9"), 2)
	draw_circle(Vector2(-width / 2 + 12, 8), 4, ArtDraw.INK)
	draw_circle(Vector2(-width / 2 + 12, 8), 2.5, Color("86e7a4") if _pressed else ArtDraw.CORAL)
	ArtDraw.cube_mark(self, Vector2(8, 6), 0.55)
