extends Node2D

var jump_count := 0
var _pulse: Tween

@onready var player: PlayerController = owner


func _process(_delta: float) -> void:
	var next_count := player.get_available_extra_jump_count()
	if next_count == jump_count:
		return
	if _pulse:
		_pulse.kill()
	scale = Vector2.ONE
	if next_count > jump_count:
		scale = Vector2.ONE * 1.18
		_pulse = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pulse.tween_property(self, "scale", Vector2.ONE, 0.18)
	jump_count = next_count
	visible = jump_count > 0
	queue_redraw()


func _draw() -> void:
	for index in jump_count:
		var y := (index - (jump_count - 1) * 0.5) * 7.0
		var chevron := PackedVector2Array([Vector2(-6, y + 2), Vector2(0, y - 2), Vector2(6, y + 2)])
		draw_polyline(chevron, Color(0.035, 0.08, 0.18), 5.0, true)
		draw_polyline(chevron, Color.WHITE, 2.5, true)
