extends SceneTree

var failed := false


func _initialize() -> void:
	var drawing := Image.load_from_file("res://docs/stage-2-redesign/layout-reference.png")
	if drawing == null:
		push_error("Original stage drawing is required")
		quit(1)
		return
	for index in 10:
		if index == 6:
			continue # The rocket room's floor is an unfilled outline in the drawing.
		var bounds: Rect2 = TowerLandscape.REFERENCE_BOUNDS[index]
		var polygons := TowerLandscape.landforms(index)
		var intersection := 0
		var union := 0
		for y in range(2, int(bounds.size.y) - 2, 2):
			for x in range(2, int(bounds.size.x) - 2, 2):
				var color := drawing.get_pixel(int(bounds.position.x) + x, int(bounds.position.y) + y)
				var darkest := minf(color.r, minf(color.g, color.b))
				var brightest := maxf(color.r, maxf(color.g, color.b))
				var painted := brightest - darkest < 0.08 and darkest > 0.35 and brightest < 0.9
				var solid := false
				for polygon in polygons:
					if Geometry2D.is_point_in_polygon(Vector2(x, y) * TowerLandscape.SCALE, polygon):
						solid = true
						break
				intersection += int(painted and solid)
				union += int(painted or solid)
		# Dice tolerates the pen outlines and unfilled pillars in the hand drawing.
		var overlap := 2.0 * intersection / (union + intersection)
		print("REFERENCE_ROOM ", "ABCDEFGXYZ"[index], " overlap=", snappedf(overlap, 0.001))
		if overlap < 0.8:
			failed = true
			push_error("Room outline differs from the reference: %d" % index)
	print("STAGE_2_REFERENCE_TEST_%s (9 room silhouettes)" % ["FAILED" if failed else "OK"])
	quit(1 if failed else 0)
