extends Area2D

signal collected(body: PlayerController)

enum RefillKind { DASH, AIR_JUMP }

@export var refill_kind := RefillKind.DASH
@export var respawn_time := 2.5
var _respawn_left := 0.0
var _available := true
var _time := 0.0


func _ready() -> void:
	for child in get_children():
		if child is CanvasItem:
			child.hide()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time = fposmod(_time + delta, 4.0)
	if _available:
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2 * sin(_time * TAU / 4)))
	if refill_kind == RefillKind.AIR_JUMP:
		ArtDraw.boot(self)
	else:
		ArtDraw.dash(self)
	draw_set_transform(Vector2.ZERO)


func _on_body_entered(body: Node) -> void:
	if not _available or not body is PlayerController:
		return
	# Logical guard is immediate; physics-server changes must be deferred in callbacks.
	_available = false
	$CollisionShape2D.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	hide()
	collected.emit(body)
	if refill_kind == RefillKind.AIR_JUMP:
		body.grant_air_jump()
	else:
		body.refill_from_crystal()
	_respawn_left = respawn_time


func _physics_process(delta: float) -> void:
	if _available:
		return
	_respawn_left = maxf(_respawn_left - delta, 0.0)
	if _respawn_left <= 0.0:
		reset_for_respawn()


func reset_for_respawn() -> void:
	_respawn_left = 0.0
	_available = true
	show()
	$CollisionShape2D.set_deferred("disabled", false)
	set_deferred("monitoring", true)
