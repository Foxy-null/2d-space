extends Grabbable

@export var parachute_fall_speed := 180.0


func fall_speed_limit() -> float:
	return parachute_fall_speed
