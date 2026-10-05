extends Area2D

signal collected(body: PlayerController)

enum RefillKind { DASH, AIR_JUMP }

@export var refill_kind := RefillKind.DASH
@export var respawn_time := 2.5
var _respawn_left := 0.0
var _available := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not _available or not body is PlayerController:
		return
	var player_shape: CollisionShape2D = body.get_node("CollisionShape2D")
	var crystal_shape: CollisionShape2D = $CollisionShape2D
	# A queued entry can arrive after the player has respawned elsewhere.
	if not crystal_shape.shape.collide(crystal_shape.global_transform, player_shape.shape, player_shape.global_transform):
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
