@tool
extends Node2D

@export var heavy := false


func _draw() -> void:
	if heavy:
		ArtDraw.box(self, Rect2(-16, -13.75, 32, 27.5), Color("545969"))
		ArtDraw.box(self, Rect2(-16, 6, 32, 7.75), Color("a2a2a7"), 1)
		for x in [-11.0, 7.0]:
			ArtDraw.box(self, Rect2(x, -1, 4, 14), Color("a2a2a7"), 1)
		ArtDraw.box(self, Rect2(-6, -9, 12, 4), ArtDraw.INK, 1)
	else:
		ArtDraw.box(self, Rect2(-12, -12, 24, 24), ArtDraw.CREAM)
		ArtDraw.box(self, Rect2(-8, -2, 16, 10), Color("687d60"), 1)
		ArtDraw.box(self, Rect2(-6, -8, 12, 3), Color("687d60"), 1)
		for x in [-10.0, 7.0]:
			ArtDraw.box(self, Rect2(x, 8, 3, 3), Color("75996a"), 1)
