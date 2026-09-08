extends Grabbable

var _jump_ready := true


func extra_jump_count() -> int:
	return int(_jump_ready)


func consume_extra_jump() -> bool:
	if not _jump_ready:
		return false
	_jump_ready = false
	return true


func refill_extra_jump() -> void:
	_jump_ready = true


func _process(_delta: float) -> void:
	$Count.visible = is_instance_valid(carrier)
	if is_instance_valid(carrier):
		$Count.text = str(carrier.get_available_extra_jump_count())
		$Count.rotation = -global_rotation
