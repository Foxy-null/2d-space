extends Area2D

@export var respawn_time := 2.5
var _respawn_left := 0.0
var _available := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not _available or not body is PlayerController:
		return
	# Logical guard is immediate; physics-server changes must be deferred in callbacks.
	_available = false
	$CollisionShape2D.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	hide()
	body.refill_from_crystal()
	_respawn_left = respawn_time


func _physics_process(delta: float) -> void:
	if _available:
		return
	_respawn_left = maxf(_respawn_left - delta, 0.0)
	if _respawn_left <= 0.0:
		_available = true
		show()
		$CollisionShape2D.set_deferred("disabled", false)
		set_deferred("monitoring", true)
