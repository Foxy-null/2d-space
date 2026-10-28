class_name ArrivalSwitch
extends Area2D

signal unlocked
signal activated

@export var mission_required := true

const TRAVEL := 32.0
const PRESS_TIME := 0.2
const INK := Color(0.055, 0.09, 0.17)
const GOLD := Color(1, 0.8, 0.22)
const CYAN := Color(0.35, 0.92, 1)
const BASE_SIZE := Vector2(140, 54.958678)
const CAP_SIZE := Vector2(108, 61.531915)
const CASE_SIZE := Vector2(128, 81.741273)
const SEAT_Y := -40.0
const CAP_SEAT_Y := SEAT_Y + 12.0

var locked := true
var pressing := false
var _pressed := false
var _step := "jump"
var _unlock_fx := 1.0
var _unlock_tween: Tween
var _hint_occluded := false

@onready var cap: AnimatableBody2D = $Cap


func _ready() -> void:
	$Bubble.visibility_changed.connect(queue_redraw)
	set_hints_visible(false)
	if not mission_required:
		locked = false
		$Case/Collision.disabled = true
		$Bubble.hide()
	$UnlockSound.stream = _sound([784.0, 1046.5, 1318.5])
	$PressSound.stream = _sound([260.0, 130.0])
	queue_redraw()


func set_progress(remaining: int, total: int, step: String, objective: String, cleared: bool = false) -> void:
	_step = step
	$Bubble/Progress.text = "完了 ✓" if cleared else ("のこり %d/%d" % [remaining, total] if remaining > 0 else "乗ろう ↓")
	$Bubble/Objective.text = "出口がひらいた！" if cleared else (objective if remaining > 0 else "押せるよ！\nスイッチに乗ろう")
	var next_locked := remaining > 0 and not cleared
	if next_locked != locked:
		locked = next_locked
		$Case/Collision.set_deferred("disabled", not locked)
		if _unlock_tween:
			_unlock_tween.kill()
		if not locked and not cleared:
			_unlock_fx = 0.0
			_unlock_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_unlock_tween.tween_property(self, "_unlock_fx", 1.0, 0.5)
			$UnlockSound.play()
			unlocked.emit()
		else:
			_unlock_fx = 1.0
	if cleared:
		_pressed = true
		pressing = false
		cap.position.y = TRAVEL
	elif locked:
		pressing = false
		cap.position.y = 0.0
		$UnlockSound.stop()
	queue_redraw()


func reset_for_respawn() -> void:
	if _pressed:
		return
	pressing = false
	cap.position.y = 0.0
	queue_redraw()


func set_hints_visible(value: bool) -> void:
	$Bubble/Objective.visible = value
	$Bubble/Progress.add_theme_font_size_override("font_size", 20 if value else 16)
	$Bubble/Progress.position = Vector2(-130, -69) if value else Vector2(88, -13)
	$Bubble/Progress.size = Vector2(260, 32) if value else Vector2(86, 30)
	queue_redraw()


func get_hint_rect() -> Rect2:
	return Rect2(-150, -84, 300, 136) if $Bubble/Objective.visible else Rect2(20, -32, 160, 64)


func _physics_process(delta: float) -> void:
	# AnimatableBody may still apply a movement queued before the retry.
	if not pressing and not _pressed:
		cap.position.y = 0.0
	if locked or _pressed:
		return
	if not pressing:
		for body in get_overlapping_bodies():
			if not body is PlayerController or not body.controls_enabled or body.gravity_direction != 1 or not body.is_on_floor():
				continue
			# Cached slide contacts can still point to this cap after a respawn.
			var contact := KinematicCollision2D.new()
			if body.test_move(body.global_transform, Vector2.DOWN, contact) and contact.get_collider() == cap and contact.get_normal().dot(Vector2.UP) > 0.8:
				pressing = true
	if pressing:
		cap.position.y = move_toward(cap.position.y, TRAVEL, TRAVEL / PRESS_TIME * delta)
		queue_redraw()
		if is_equal_approx(cap.position.y, TRAVEL):
			_pressed = true
			pressing = false
			$PressSound.play()
			activated.emit()


func is_pressed() -> bool:
	return _pressed


func _process(_delta: float) -> void:
	var occluded: bool = mission_required and $Bubble.visible and _hint_covers_player()
	if occluded != _hint_occluded:
		_hint_occluded = occluded
		$Bubble.modulate.a = 0.0 if occluded else 1.0
		queue_redraw()
	if not locked and _unlock_fx < 1.0:
		queue_redraw()


func _hint_covers_player() -> bool:
	var bounds: Rect2 = $Bubble.global_transform * get_hint_rect()
	for player in get_tree().get_nodes_in_group("player"):
		if _artwork_overlaps(player, bounds):
			return true
		var held: Grabbable = player.get_held_object()
		if held != null and _artwork_overlaps(held, bounds):
			return true
	return false


func _artwork_overlaps(body: Node2D, bounds: Rect2) -> bool:
	var sprite := body.get_node("Visuals/Body")
	if sprite is AnimatedSprite2D:
		var size: Vector2 = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size()
		return bounds.intersects(sprite.global_transform * Rect2(-size * 0.5, size))
	var collider: CollisionShape2D = body.get_node("CollisionShape2D")
	return bounds.intersects(collider.global_transform * collider.shape.get_rect())


func _draw() -> void:
	if not is_node_ready():
		return
	var support := ArtDraw.support_color(ArtDraw.environment(self))
	ArtDraw.box(self, Rect2(-70, -BASE_SIZE.y, 140, BASE_SIZE.y), support, 8)
	var top := CAP_SEAT_Y - CAP_SIZE.y + cap.position.y
	ArtDraw.box(self, Rect2(-54, top + 9, 108, -28 - top - 9), support.darkened(0.16), 5)
	ArtDraw.ellipse(self, Vector2(0, top + 25), Vector2(54, 9), ArtDraw.GOLD)
	ArtDraw.box(self, Rect2(-54, top + 10, 108, 15), ArtDraw.GOLD, 1)
	ArtDraw.ellipse(self, Vector2(0, top + 10), Vector2(54, 10), Color("f6df8a"))
	ArtDraw.footprints(self, Vector2(0, top + 10), 0.8)
	# The front lip occludes the moving cap without changing its physical travel.
	ArtDraw.box(self, Rect2(-70, SEAT_Y, 140, -SEAT_Y), support, 6)
	draw_line(Vector2(-64, SEAT_Y + 5), Vector2(64, SEAT_Y + 5), support.lightened(0.22), 3, true)
	draw_line(Vector2(48, top - 40), Vector2(48, top + 7), ArtDraw.INK, 3, true)
	ArtDraw.box(self, Rect2(48, top - 40, 32, 24), ArtDraw.CREAM, 1)
	for row in 3:
		for column in 4:
			if (row + column) % 2 == 0:
				draw_rect(Rect2(49 + column * 7.5, top - 39 + row * 7, 7.5, 7), ArtDraw.INK)
	var opening := 0.0 if locked else _unlock_fx
	var alpha := 1.0 if locked else 1.0 - _unlock_fx
	if alpha > 0:
		var hood := Rect2(-64, SEAT_Y - CASE_SIZE.y - opening * 12, CASE_SIZE.x, CASE_SIZE.y)
		_box(hood, Color(0.58, 0.8, 0.95, 0.14 * alpha), Color(0.68, 0.84, 0.94, alpha), 14)
		draw_line(hood.position + Vector2(8, 19), hood.position + Vector2(8, hood.size.y - 8), Color(0.86, 0.94, 1, 0.5 * alpha), 3, true)
		draw_set_transform(Vector2(0, SEAT_Y - 27 - opening * 36), -opening * 0.6, Vector2.ONE * (1.0 + 0.2 * sin(opening * PI)))
		_box(Rect2(-16, -9, 32, 27), Color(ArtDraw.INK, alpha), Color(ArtDraw.INK, alpha), 5)
		draw_arc(Vector2(5 * opening, -9 - 6 * opening), 11, PI, TAU, 16, Color(ArtDraw.INK, alpha), 5, true)
		draw_line(Vector2(-11 + 5 * opening, -9 - 6 * opening), Vector2(-11, -1), Color(ArtDraw.INK, alpha), 5, true)
		draw_circle(Vector2(0, 1), 3, Color(ArtDraw.CREAM, alpha))
		draw_line(Vector2(0, 2), Vector2(0, 9), Color(ArtDraw.CREAM, alpha), 3, true)
		draw_set_transform(Vector2.ZERO)
	if not locked and _unlock_fx < 1:
		for i in 7:
			var angle := i * TAU / 7.0
			var center := Vector2(0, SEAT_Y - CASE_SIZE.y / 2) + Vector2.from_angle(angle) * (30 + 66 * _unlock_fx)
			_star(center, (1.0 - _unlock_fx) * 8, Color(GOLD, 1.0 - _unlock_fx))
	if not mission_required or not $Bubble.visible or _hint_occluded:
		return
	draw_set_transform($Bubble.position)
	var border := GOLD if locked else Color(0.4, 1, 0.7)
	_box(get_hint_rect(), Color(0.07, 0.12, 0.23, 0.97), border, 12)
	draw_set_transform($Bubble.position + Vector2(-110, 5))
	if not $Bubble/Objective.visible:
		draw_set_transform($Bubble.position + Vector2(54, 0), 0, Vector2.ONE * 0.7)
	_draw_icon("complete" if _pressed else (_step if locked else "ready"))
	draw_set_transform(Vector2.ZERO)


func _box(rect: Rect2, fill: Color, border: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	draw_style_box(style, rect)


func _arrow(start: Vector2, end: Vector2, color: Color = CYAN) -> void:
	draw_line(start, end, color, 4, true)
	var back := (start - end).normalized()
	draw_polyline(PackedVector2Array([end + back.rotated(0.65) * 10, end, end + back.rotated(-0.65) * 10]), color, 4, true)


func _star(center: Vector2, radius: float, color: Color) -> void:
	if radius < 0.5:
		return
	var points := PackedVector2Array()
	for i in 10:
		points.append(center + Vector2.from_angle(-PI / 2 + i * PI / 5) * radius * (1.0 if i % 2 == 0 else 0.45))
	draw_colored_polygon(points, color)


func _draw_icon(step: String) -> void:
	match step:
		"complete":
			_star(Vector2.ZERO, 26, GOLD)
			draw_polyline(PackedVector2Array([Vector2(-9, 0), Vector2(-2, 8), Vector2(13, -9)]), INK, 4, true)
		"ready":
			ArtDraw.ellipse(self, Vector2(0, 12), Vector2(24, 9), ArtDraw.GOLD)
			ArtDraw.footprints(self, Vector2(0, 12), 0.5)
			_arrow(Vector2(0, -27), Vector2(0, 3), GOLD)
		"button_on", "button_off", "throw_button":
			_box(Rect2(-23, 9, 46, 12), Color("92919a"), INK, 4)
			ArtDraw.cube_mark(self, Vector2(0, -10), 1.1)
			_arrow(Vector2(19, -25), Vector2(19, 3), GOLD)
			if step == "button_off":
				_arrow(Vector2(15, 2), Vector2(15, -26))
		"up", "down", "inverted_glide":
			draw_circle(Vector2.ZERO, 25, Color(0.14, 0.22, 0.35))
			_arrow(Vector2(0, 20 if step == "up" else -20), Vector2(0, -20 if step == "up" else 20), Color(1, 0.35, 0.5) if step == "up" else CYAN)
		"dash", "air_dash", "refilled_dash", "spring_dash", "superdash":
			_arrow(Vector2(-23, 0), Vector2(25, 0))
			for y in [-13, 13]:
				draw_line(Vector2(-26, y), Vector2(-7, y), Color(0.5, 0.7, 1), 3, true)
		"dash_refill", "jump_crystal", "two_jumps":
			if step == "dash_refill":
				ArtDraw.dash(self)
			else:
				ArtDraw.boot(self)
		"climb", "wall_jump", "wind_grab":
			draw_line(Vector2(-22, -28), Vector2(-22, 28), Color(0.6, 0.7, 0.84), 7, true)
			draw_circle(Vector2(-7, -3), 8, CYAN)
			_arrow(Vector2(10, 21), Vector2(10, -23))
		"floor_spring", "wall_spring":
			ArtDraw.box(self, Rect2(-23, -22, 46, 10), ArtDraw.CORAL)
			draw_polyline(PackedVector2Array([Vector2(-11, -8), Vector2(11, -2), Vector2(-11, 4), Vector2(11, 10), Vector2(-11, 16)]), Color("b9b7c0"), 3, true)
			ArtDraw.box(self, Rect2(-20, 19, 40, 7), Color("8d909a"))
		"pinball":
			ArtDraw.ellipse(self, Vector2.ZERO, Vector2(20, 20), ArtDraw.CORAL)
			ArtDraw.ellipse(self, Vector2(0, -15), Vector2(7, 3), ArtDraw.CREAM, 1)
			ArtDraw.ellipse(self, Vector2(0, 15), Vector2(7, 3), ArtDraw.CREAM, 1)
			_arrow(Vector2(-25, 25), Vector2(-10, 10), Color.WHITE)
			_arrow(Vector2(10, -10), Vector2(25, -25), Color.WHITE)
		"wind_walk", "wind_dash", "wind_lift":
			for y in [-16, 0, 16]:
				_arrow(Vector2(-25, y), Vector2(24, y), Color(0.6, 0.85, 1))
		"glide", "parachute_release", "fast_fall":
			draw_arc(Vector2(0, 1), 25, PI, TAU, 24, Color(0.85, 0.2, 0.12), 4, true)
			draw_line(Vector2(-25, 1), Vector2(25, 1), Color(0.85, 0.2, 0.12), 3, true)
			for x in [-25, 25]:
				draw_line(Vector2(x, 1), Vector2(0, 18), Color.WHITE, 2, true)
			draw_circle(Vector2(0, 22), 6, CYAN)
		"light_grab", "light_drop", "heavy_move", "throw":
			_box(Rect2(-19, -19, 38, 38), Color(0.66, 0.72, 0.82) if step == "heavy_move" else GOLD, INK, 5)
			if step in ["heavy_move", "throw"]:
				_arrow(Vector2(-23, 27), Vector2(24, 27))
			else:
				draw_polyline(PackedVector2Array([Vector2(-26, -5), Vector2(-26, 26), Vector2(26, 26), Vector2(26, -5)]), Color.WHITE, 3, true)
		_:
			draw_circle(Vector2(-10, 13), 11, Color(0.4, 1, 0.65) if "creature" in step else CYAN)
			_arrow(Vector2(13, 22), Vector2(13, -25))
			if step == "creature_landed":
				_arrow(Vector2(-10, -25), Vector2(-10, -3), GOLD)


static func _sound(notes: Array) -> AudioStreamWAV:
	# Short synthesized toy chimes; no imported audio or runtime dependency.
	var data := PackedByteArray()
	var rate := 22050
	var length := 0.11
	var count := int(rate * length)
	data.resize(count * notes.size() * 2)
	for note in notes.size():
		for sample in count:
			var t := float(sample) / rate
			var phase: float = TAU * notes[note] * t
			var envelope := sin(PI * t / length) * exp(-t * 12.0)
			var value := (sin(phase) + 0.2 * sin(phase * 2.0)) * envelope * 0.55
			var pcm := int(32767 * value)
			var offset := (note * count + sample) * 2
			data[offset] = pcm & 0xff
			data[offset + 1] = (pcm >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
