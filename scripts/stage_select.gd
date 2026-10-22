extends Control

const NINJA := preload("res://assets/characters/ninja-frames.tres")
const CREATURE := preload("res://assets/characters/jump-creature-rest.png")


func _ready() -> void:
	for index in $Margin/Content/Stages.get_child_count():
		var card := $Margin/Content/Stages.get_child(index) as Button
		var lines := card.text.split("\n", false)
		card.accessibility_name = "ステージ " + card.text.replace("\n", " ")
		card.text = ""
		var content := VBoxContainer.new()
		content.name = "Content"
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 12)
		card.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 16
		content.offset_right = -16
		content.offset_top = 24
		content.offset_bottom = -24
		var number := Label.new()
		number.text = lines[0]
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(number)
		var art := Control.new()
		art.name = "Art"
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.custom_minimum_size = Vector2(160, 120)
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(art)
		art.draw.connect(_draw_card.bind(art, index))
		var title := Label.new()
		title.name = "Title"
		title.text = lines[1]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(title)
	$Margin/Content/Stages/Stage1.grab_focus.call_deferred()


func _draw_card(canvas: Control, index: int) -> void:
	canvas.draw_set_transform(canvas.size * 0.5)
	var pose := &"jump"
	var ninja_position := Vector2(-44, -50)
	match index:
		0:
			ArtDraw.box(canvas, Rect2(-70, 40, 44, 12), ArtDraw.CREAM)
			ArtDraw.box(canvas, Rect2(-8, 12, 40, 12), ArtDraw.CREAM)
			ArtDraw.box(canvas, Rect2(50, -16, 24, 12), ArtDraw.CREAM)
			ArtDraw.arrow(canvas, Vector2(-58, 10), Vector2(-26, -22), ArtDraw.MINT)
			canvas.draw_circle(Vector2(62, -31), 6, ArtDraw.GOLD)
		1:
			ArtDraw.box(canvas, Rect2(-22, -52, 44, 104), Color("51495f"))
			for y in [-38, 2, 42]:
				ArtDraw.box(canvas, Rect2(-38, y, 76, 10), ArtDraw.CREAM)
			ArtDraw.arrow(canvas, Vector2(61, 42), Vector2(61, -43), ArtDraw.CYAN)
			ninja_position = Vector2(-83, -50)
		2:
			ArtDraw.box(canvas, Rect2(-70, -48, 14, 102), ArtDraw.CREAM)
			ArtDraw.box(canvas, Rect2(55, -48, 14, 102), ArtDraw.CREAM)
			ArtDraw.arrow(canvas, Vector2(1, 36), Vector2(1, -39), ArtDraw.CORAL)
			ArtDraw.arrow(canvas, Vector2(32, -39), Vector2(32, 36), ArtDraw.CYAN)
			pose = &"wall_grab"
			ninja_position = Vector2(-82, -45)
		3:
			ArtDraw.box(canvas, Rect2(-70, 43, 140, 12), ArtDraw.CREAM)
			canvas.draw_texture_rect(CREATURE, Rect2(-19, -45, 36, 36 * CREATURE.get_height() / float(CREATURE.get_width())), false)
			ArtDraw.arrow(canvas, Vector2(47, 25), Vector2(47, -17), ArtDraw.MINT)
			pose = &"carry_idle"
			ninja_position = Vector2(-40, -22)
		4:
			for center in [Vector2(-46, 22), Vector2(44, -30)]:
				ArtDraw.ellipse(canvas, center, Vector2(19, 19), ArtDraw.CORAL)
				ArtDraw.ellipse(canvas, center + Vector2(0, -12), Vector2(7, 3), ArtDraw.CREAM, 1)
			for y in [-46, -33]:
				ArtDraw.arrow(canvas, Vector2(-72, y), Vector2(-18, y), ArtDraw.CYAN, 2.5)
			ArtDraw.arrow(canvas, Vector2(-20, 10), Vector2(20, -13), ArtDraw.GOLD)
			ninja_position = Vector2(-12, -8)
	canvas.draw_texture_rect(NINJA.get_frame_texture(pose, 0), Rect2(ninja_position, Vector2(80, 80)), false)
	canvas.draw_set_transform(Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_return_to_title()


func _return_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _start_tutorial() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")


func _start_stage_two() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_2.tscn")


func _preview_environments() -> void:
	get_tree().change_scene_to_file("res://scenes/environment_preview.tscn")


func _start_stage_three() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_3.tscn")


func _start_stage_four() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_4.tscn")


func _start_stage_five() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_5.tscn")
