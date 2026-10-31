extends "res://scripts/refill_crystal.gd"


func _draw() -> void:
	draw_set_transform(Vector2(0, 2 * sin(_time * TAU / 4)))
	ArtDraw.polygon(self, PackedVector2Array([Vector2(0, -15), Vector2(12, 0), Vector2(0, 15), Vector2(-12, 0)]), Color("77d990"))
	draw_line(Vector2(0, -10), Vector2(-7, 0), Color("d4f6ce"), 2, true)
	draw_set_transform(Vector2.ZERO)
