extends Grabbable

var _jump_ready := true
var _reaction_left := 0.0


func _process(delta: float) -> void:
	_reaction_left = maxf(0.0, _reaction_left - delta)
	$Visuals/Body.frame = int(_reaction_left > 0.0)
	super._process(delta)


func extra_jump_count() -> int:
	return int(_jump_ready)


func consume_extra_jump() -> bool:
	if not _jump_ready:
		return false
	_jump_ready = false
	_reaction_left = 0.18
	return true


func refill_extra_jump() -> void:
	_jump_ready = true
	_reaction_left = 0.0
