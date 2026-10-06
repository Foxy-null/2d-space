extends Grabbable

@export var parachute_fall_speed := 180.0


func _process(delta: float) -> void:
	var open := is_instance_valid(carrier) and not carrier.is_on_floor() and not carrier.is_dashing()
	$Visuals/Body.frame = int(open)
	super._process(delta)
	if open:
		visuals.rotation += sin(Time.get_ticks_msec() * 0.012) * 0.025


func fall_speed_limit() -> float:
	return parachute_fall_speed
