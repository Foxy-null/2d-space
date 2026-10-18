extends Node2D
## Room-local geometry. Gaps are deliberately wide; timing supplies the danger.

const TERRAIN = preload("res://scripts/terrain_art.gd")
const SPIKE = preload("res://scenes/spike_block.tscn")
const CREATURE = preload("res://scenes/jump_creature.tscn")
const GOAL = preload("res://scenes/arrival_switch.tscn")

@export_range(0, 5) var room_number := 0
var walls: Array[Rect2] = []
var exit_top := 500.0


func _ready() -> void:
	var items := Node2D.new()
	items.name = "Items"
	add_child(items)
	var hazards := Node2D.new()
	hazards.name = "Hazards"
	add_child(hazards)
	# A safe entry shaft introduces the alternating wall kicks used throughout.
	_block("LeftWall", Rect2(0, 180, 36, 540))
	_block("Entrance", Rect2(36, 620, 184, 40))
	var first_top: float = [240, 220, 220, 200, 200, 180][room_number]
	var middle_top: float = [350, 300, 340, 300, 350, 330][room_number]
	var high_top: float = [220, 210, 210, 190, 190, 180][room_number]
	var final_top: float = [350, 330, 300, 320, 330, 300][room_number]
	var high_x: float = 780 if room_number == 5 else 800
	var final_x: float = 1070 if room_number in [2, 5] else 1040
	for rect in [Rect2(270, first_top, 40, 720 - first_top), Rect2(550, middle_top, 40, 700 - middle_top), Rect2(high_x, high_top, 40, 670 - high_top), Rect2(final_x, final_top, 40, 700 - final_top)]:
		walls.append(rect)
		_block("Wall%d" % walls.size(), rect)
	if room_number == 0:
		_block("Rest", Rect2(550, 510, 145, 35))
	exit_top = 480 if room_number in [2, 3, 5] else 500
	_block("Exit", Rect2(1160, exit_top, 120, 40))
	_block("ExitBarrier", Rect2(1280, 100, 24, 620))
	_label("Checkpoint", Vector2(45, 667), "CHECKPOINT %02d / 06" % (room_number + 1), Color("81f6c2"), 16)
	_label("ExitLabel", Vector2(1155, exit_top + 48), "ゴール" if room_number == 5 else "次の部屋 →", Color.WHITE, 16)
	# Every patrol intersects an actual wall-kick or transfer lane. No filler spikes.
	match room_number:
		0:
			_spike(Vector2(155, 250), Vector2(0, 190), 3.5, 0.0)
			_spike(Vector2(690, 220), Vector2(0, 240), 3.4, 0.0)
		1:
			_spike(Vector2(110, 370), Vector2(95, 0), 2.9, 0.25)
			_spike(Vector2(680, 160), Vector2(0, 300), 3.1, 0.15)
		2:
			_spike(Vector2(155, 320), Vector2(0, 210), 3.2, 0.4)
			_spike(Vector2(885, 125), Vector2(110, 0), 2.8, 0.2)
		3:
			_spike(Vector2(100, 380), Vector2(105, 0), 2.6, 0.2)
			_spike(Vector2(365, 105), Vector2(240, 0), 2.8, 0.0)
			_spike(Vector2(890, 115), Vector2(95, 0), 2.5, 0.4)
		4:
			_spike(Vector2(160, 300), Vector2(0, 250), 2.7, 0.3)
			_spike(Vector2(680, 180), Vector2(0, 290), 2.6, 0.2)
			_spike(Vector2(945, 90), Vector2(0, 300), 2.8, 0.0)
		5:
			_spike(Vector2(150, 310), Vector2(0, 240), 2.6, 0.35)
			_spike(Vector2(365, 90), Vector2(240, 0), 2.5, 0.1)
			_spike(Vector2(950, 75), Vector2(0, 300), 2.7, 0.25)
	if room_number in [2, 5]:
		var creature := CREATURE.instantiate()
		creature.name = "JumpCreature"
		creature.position = Vector2(175, 580)
		items.add_child(creature)
		_label("CarryHint", Vector2(45, 115), "緑の相棒を出口まで運ぼう  /  Shift長押し：運ぶ  /  空中ジャンプ＋1", Color("a7f5ac"), 19)
	if room_number == 5:
		var goal := GOAL.instantiate()
		goal.name = "Goal"
		goal.position = Vector2(1220, exit_top)
		add_child(goal)


func _block(label: String, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = label
	body.position = rect.get_center()
	var collider := CollisionShape2D.new()
	collider.name = "Collision"
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	var art := Polygon2D.new()
	art.name = "Visual"
	art.set_script(TERRAIN)
	var half := rect.size * 0.5
	art.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	body.add_child(art)
	add_child(body)


func _spike(at: Vector2, travel: Vector2, period: float, phase: float) -> void:
	var spike := SPIKE.instantiate()
	spike.name = "Spike%d" % ($Hazards.get_child_count() + 1)
	spike.position = at
	spike.travel = travel
	spike.period = period
	spike.phase = phase
	spike.room_number = room_number
	$Hazards.add_child(spike)


func _label(label: String, at: Vector2, value: String, tint: Color, font_size: int) -> void:
	var text := Label.new()
	text.name = label
	text.position = at
	text.text = value
	text.modulate = tint
	text.add_theme_font_size_override("font_size", font_size)
	add_child(text)
