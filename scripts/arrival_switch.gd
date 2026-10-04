class_name ArrivalSwitch
extends Area2D

signal unlocked
signal activated

@export var mission_required := true

const TRAVEL := 32.0
const PRESS_TIME := 0.2
const BUBBLE := Vector2(-125, -230)
const INK := Color(0.055, 0.09, 0.17)
const GOLD := Color(1, 0.8, 0.22)
const CYAN := Color(0.35, 0.92, 1)
const ART := preload("res://assets/arrival/arrival-switch-atlas.png")
const BASE_ART := Rect2(30, 256, 484, 190)
const BASE_FRONT_ART := Rect2(30, 300, 484, 146)
const CAP_ART := Rect2(558, 202, 423, 241)
const CASE_ART := Rect2(1022, 128, 487, 311)
const LOCK_ART := Rect2(118, 550, 342, 385)
const OPEN_LOCK_ART := Rect2(618, 550, 342, 385)
const BASE_SCALE := 140.0 / BASE_ART.size.x
const CAP_SCALE := 108.0 / CAP_ART.size.x
const BASE_SIZE := BASE_ART.size * BASE_SCALE
const CAP_SIZE := CAP_ART.size * CAP_SCALE
const CASE_SIZE := CASE_ART.size * (128.0 / CASE_ART.size.x)
const LOCK_SIZE := LOCK_ART.size * (54.0 / LOCK_ART.size.x)
const SEAT_Y := -40.0
const CAP_SEAT_Y := SEAT_Y + 12.0

var locked := true
var pressing := false
var _pressed := false
var _step := "jump"
var _unlock_fx := 1.0
var _unlock_tween: Tween
var _open_lock := AtlasTexture.new()

@onready var cap: AnimatableBody2D = $Cap
@onready var _closed_lock: Texture2D = $LockPivot/Lock.texture


func _ready() -> void:
	if not mission_required:
		locked = false
		$Case/Collision.disabled = true
		$Bubble.hide()
	$UnlockSound.stream = _sound([784.0, 1046.5, 1318.5])
	$PressSound.stream = _sound([260.0, 130.0])
	_open_lock.atlas = ART
	_open_lock.region = OPEN_LOCK_ART
	$Glass.scale = Vector2.ONE * (CASE_SIZE.x / CASE_ART.size.x)
	$FrontLip.scale = Vector2.ONE * BASE_SCALE
	$FrontLip.position = Vector2(-70, -BASE_SIZE.y + (BASE_FRONT_ART.position.y - BASE_ART.position.y) * BASE_SCALE)
	$LockPivot/Lock.scale = Vector2.ONE * (LOCK_SIZE.x / LOCK_ART.size.x)
	$LockPivot/Lock.position = Vector2(-27, 23 - LOCK_SIZE.y)
	_sync_case_visuals()


func set_progress(remaining: int, total: int, step: String, objective: String, cleared: bool = false) -> void:
	_step = step
	$Bubble/Progress.text = "クリア！" if cleared else "のこり %d/%d" % [remaining, total]
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
	_sync_case_visuals()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if locked or _pressed:
		return
	if not pressing:
		for body in get_overlapping_bodies():
			if not body is PlayerController or not body.controls_enabled or body.gravity_direction != 1 or not body.is_on_floor():
				continue
			for index in body.get_slide_collision_count():
				var contact: KinematicCollision2D = body.get_slide_collision(index)
				if contact.get_collider() == cap and contact.get_normal().dot(Vector2.UP) > 0.8:
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
	_sync_case_visuals()
	if not locked and _unlock_fx < 1.0:
		queue_redraw()


func _sync_case_visuals() -> void:
	var case_alpha := 1.0 if locked else 1.0 - _unlock_fx
	var opening := 0.0 if locked else _unlock_fx
	$Glass.visible = case_alpha > 0
	$Glass.modulate.a = case_alpha
	$Glass.position = Vector2(0, SEAT_Y - CASE_SIZE.y / 2 - opening * 12)
	$LockPivot.visible = case_alpha > 0
	$LockPivot.modulate.a = case_alpha
	$LockPivot.position = Vector2(0, SEAT_Y - 27 - opening * 36)
	$LockPivot.rotation = -opening * 0.6
	$LockPivot.scale = Vector2.ONE * (1.0 + 0.2 * sin(opening * PI))
	$LockPivot/Lock.texture = _closed_lock if locked else _open_lock


func _draw() -> void:
	if not is_node_ready():
		return
	# The scene origin is the pedestal's bottom, on the supporting floor.
	draw_texture_rect_region(ART, Rect2(Vector2(-70, -BASE_SIZE.y), BASE_SIZE), BASE_ART)
	# Slide one uniformly scaled cap into the socket; crop instead of squashing it.
	var visible_height := CAP_SIZE.y - cap.position.y
	var cap_source := Rect2(CAP_ART.position, Vector2(CAP_ART.size.x, visible_height / CAP_SCALE))
	# The lower rounded corners start below the front lip even before pressing.
	draw_texture_rect_region(ART, Rect2(Vector2(-54, CAP_SEAT_Y - visible_height), Vector2(108, visible_height)), cap_source)
	# Child sprites draw the glass, then the seating lip, then the lock.
	if not locked and _unlock_fx < 1:
		for i in 7:
			var angle := i * TAU / 7.0
			var center := Vector2(0, SEAT_Y - CASE_SIZE.y / 2) + Vector2.from_angle(angle) * (30 + 66 * _unlock_fx)
			_star(center, (1.0 - _unlock_fx) * 8, Color(GOLD, 1.0 - _unlock_fx))
	if not mission_required:
		return
	draw_set_transform(BUBBLE)
	var border := GOLD if locked else Color(0.4, 1, 0.7)
	_box(Rect2(-150, -84, 300, 144), Color(0.07, 0.12, 0.23, 0.97), border, 16)
	draw_colored_polygon(PackedVector2Array([Vector2(75, 59), Vector2(98, 59), Vector2(117, 89)]), border)
	draw_colored_polygon(PackedVector2Array([Vector2(81, 58), Vector2(94, 58), Vector2(111, 80)]), Color(0.07, 0.12, 0.23))
	draw_set_transform(BUBBLE + Vector2(-110, 5))
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
		"ready", "button_on", "button_off", "throw_button":
			_box(Rect2(-23, 9, 46, 12), Color(1, 0.36, 0.4), INK, 4)
			_arrow(Vector2(0, -27), Vector2(0, 3), GOLD)
			if step != "ready":
				_box(Rect2(-9, -25, 18, 18), Color(0.68, 0.75, 0.82), INK, 3)
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
			var color := Color(0.65, 0.4, 1) if step != "dash_refill" else Color(0.3, 1, 0.6)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -26), Vector2(22, 0), Vector2(0, 26), Vector2(-22, 0)]), color)
			_arrow(Vector2(-11, 0) if step == "dash_refill" else Vector2(0, 13), Vector2(11, 0) if step == "dash_refill" else Vector2(0, -13), Color.WHITE)
		"climb", "wall_jump", "wind_grab":
			draw_line(Vector2(-22, -28), Vector2(-22, 28), Color(0.6, 0.7, 0.84), 7, true)
			draw_circle(Vector2(-7, -3), 8, CYAN)
			_arrow(Vector2(10, 21), Vector2(10, -23))
		"floor_spring", "wall_spring":
			draw_polyline(PackedVector2Array([Vector2(-22, 23), Vector2(15, 14), Vector2(-15, 5), Vector2(15, -4), Vector2(-15, -13), Vector2(22, -22)]), Color(0.7, 1, 0.3), 4, true)
		"pinball":
			draw_circle(Vector2.ZERO, 19, Color(1, 0.36, 0.76))
			draw_arc(Vector2.ZERO, 23, 0, TAU, 32, Color.WHITE, 2, true)
			_arrow(Vector2(-25, 25), Vector2(-10, 10), Color.WHITE)
			_arrow(Vector2(10, -10), Vector2(25, -25), Color.WHITE)
		"wind_walk", "wind_dash", "wind_lift":
			for y in [-16, 0, 16]:
				_arrow(Vector2(-25, y), Vector2(24, y), Color(0.6, 0.85, 1))
		"glide", "parachute_release", "fast_fall":
			draw_arc(Vector2(0, 1), 25, PI, TAU, 24, GOLD, 4, true)
			draw_line(Vector2(-25, 1), Vector2(25, 1), GOLD, 3, true)
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
