extends Control

var _elapsed := 0.0
var _landing_pulse := 0.0
var _launch_progress := 0.0
var _starting := false
var _intro: Tween
var _breathing: Tween
var _new_game_dialog: ConfirmationDialog
var _save_error: AcceptDialog

@onready var _logo: TextureRect = $Center/Content/Logo
@onready var _start_button: Button = $Center/Content/Start
@onready var _continue_button: Button = $Center/Content/Continue
@onready var _controls: Label = $Center/Content/Controls
@onready var _ninja: AnimatedSprite2D = $Mascot/Ninja
@onready var _effects: Node2D = $Effects
@onready var _demo_button: Button = $DemoMode


func _ready() -> void:
	$AudioCredit.meta_clicked.connect(OS.shell_open)
	DemoMode.bind_button(_demo_button)
	_continue_button.disabled = not CollectionProgress.has_save()
	_continue_button.pressed.connect(_continue)
	_start_button.focus_neighbor_top = _start_button.get_path_to(_demo_button)
	_demo_button.focus_neighbor_bottom = _demo_button.get_path_to(_start_button)
	var bottom_button := _start_button if _continue_button.disabled else _continue_button
	bottom_button.focus_neighbor_bottom = bottom_button.get_path_to(_demo_button)
	_demo_button.focus_neighbor_top = _demo_button.get_path_to(bottom_button)
	(_continue_button if not _continue_button.disabled else _start_button).grab_focus.call_deferred()
	_new_game_dialog = ConfirmationDialog.new()
	_new_game_dialog.title = "はじめから"
	_new_game_dialog.dialog_text = "クリア状況・巻物・操作設定・画面設定を\nすべて初期化して、ステージ1から始めます。"
	_new_game_dialog.ok_button_text = "初期化してはじめる"
	_new_game_dialog.cancel_button_text = "戻る"
	_new_game_dialog.confirmed.connect(_begin.bind(true))
	add_child(_new_game_dialog)
	_save_error = AcceptDialog.new()
	_save_error.dialog_text = "初期化を保存できませんでした。保存先を確認して、もう一度お試しください。"
	add_child(_save_error)
	# OS設定を取得できない場合の戻り値は-1、動きの抑制が指定された場合は1。
	if DisplayServer.accessibility_should_reduce_animation() == 1:
		$Backdrop.set_process(false)
		set_process(false)
		return

	_logo.resized.connect(func(): _logo.pivot_offset = _logo.size * 0.5)
	_logo.pivot_offset = _logo.size * 0.5
	_logo.draw.connect(_draw_sparkles)
	_effects.draw.connect(_draw_effects)
	_ninja.play("jump")
	_fly_ninja(0.0)
	_logo.scale = Vector2.ONE * 0.92
	_logo.modulate.a = 0.0
	_start_button.modulate.a = 0.0
	_continue_button.modulate.a = 0.0
	_demo_button.modulate.a = 0.0
	_continue_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.modulate.a = 0.0
	_intro = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_logo, "modulate:a", 1.0, 0.65)
	_intro.parallel().tween_property(_logo, "scale", Vector2.ONE, 0.65)
	_intro.tween_interval(0.15)
	_intro.tween_callback(_start_button.set.bind("mouse_filter", Control.MOUSE_FILTER_STOP))
	_intro.tween_callback(_continue_button.set.bind("mouse_filter", Control.MOUSE_FILTER_STOP))
	_intro.tween_callback(_demo_button.set.bind("mouse_filter", Control.MOUSE_FILTER_STOP))
	_intro.tween_property(_start_button, "modulate:a", 1.0, 0.3)
	_intro.parallel().tween_property(_continue_button, "modulate:a", 1.0, 0.3)
	_intro.parallel().tween_property(_demo_button, "modulate:a", 1.0, 0.3)
	_intro.parallel().tween_property(_controls, "modulate:a", 1.0, 0.25).set_delay(0.1)
	_intro.parallel().tween_method(_fly_ninja, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_LINEAR)
	_intro.tween_callback(_land_ninja)
	_intro.tween_callback(_breathe_logo)


func _fly_ninja(progress: float) -> void:
	_ninja.position = Vector2(-size.x * 0.5, -20).bezier_interpolate(Vector2(-360, -300), Vector2(-100, -170), Vector2.ZERO, progress)
	_ninja.rotation = -0.35 * sin(progress * PI)


func _land_ninja() -> void:
	_ninja.play("idle")
	_landing_pulse = 1.0
	create_tween().tween_property(self, "_landing_pulse", 0.0, 0.4)


func _breathe_logo() -> void:
	_breathing = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathing.tween_property(_logo, "scale", Vector2.ONE * 1.012, 2.8)
	_breathing.tween_property(_logo, "scale", Vector2.ONE, 2.8)


func _process(delta: float) -> void:
	_elapsed += delta
	_logo.queue_redraw()
	_effects.queue_redraw()


func _draw_sparkles() -> void:
	var center := _logo.size * 0.5
	var texture_size := _logo.texture.get_size()
	var picture_size := texture_size * minf(_logo.size.x / texture_size.x, _logo.size.y / texture_size.y)
	for index in 8:
		var phase := fposmod(_elapsed / 3.6 + float(index) / 8.0, 1.0)
		var glow := pow(sin(phase * PI), 2.0)
		var angle := TAU * (float(index) + 0.5) / 8.0 + 0.025 * sin(_elapsed * TAU / 24.0 + index)
		var point := center + Vector2(cos(angle), sin(angle)) * (picture_size * 0.5 + Vector2(16, 16))
		var radius := 5.0 + glow * 6.0
		var points := PackedVector2Array()
		for corner in 8:
			var distance := radius if corner % 2 == 0 else radius * 0.28
			points.append(point + Vector2.RIGHT.rotated(corner * TAU / 8.0 + _elapsed * 0.18 + index) * distance)
		_logo.draw_colored_polygon(points, Color(1.0, 0.84, 0.38, glow * 0.8))
		_logo.draw_circle(point, radius * 0.14, Color(1.0, 0.96, 0.77, glow * 0.9))


func _draw_effects() -> void:
	if _landing_pulse > 0.0:
		var radius := 8.0 + (1.0 - _landing_pulse) * 50.0
		for index in 8:
			var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
			var point: Vector2 = $Mascot.position + Vector2(0, 48) + direction * Vector2(radius, radius * 0.35)
			_effects.draw_circle(point, 2.0 + _landing_pulse * 2.0, Color(1, 0.85, 0.45, _landing_pulse * 0.8))
	if _starting:
		_effects.draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.027, 0.075, _launch_progress))
		for index in 24:
			var direction := Vector2.RIGHT.rotated(TAU * float(index) / 24.0)
			var start := _logo.get_global_rect().get_center() + direction * (120.0 + _launch_progress * 240.0)
			var end := start + direction * _launch_progress * 420.0
			_effects.draw_line(start, end, Color(1, 0.89, 0.62, sin(_launch_progress * PI) * 0.75), 1.0 + _launch_progress * 2.0, true)


func _start() -> void:
	if _starting:
		return
	if CollectionProgress.has_save() or InputSettings.has_custom_settings() or DisplaySettings.has_custom_settings():
		_new_game_dialog.popup_centered(Vector2i(620, 250))
		_new_game_dialog.get_cancel_button().grab_focus.call_deferred()
	else:
		_begin(true)


func _continue() -> void:
	if CollectionProgress.has_save():
		_begin(false)


func _begin(new_game: bool) -> void:
	if _starting:
		return
	if new_game and CollectionProgress.start_new_game() != OK:
		_save_error.popup_centered(Vector2i(620, 230))
		return
	var destination := "res://scenes/tutorial.tscn" if new_game else "res://scenes/stage_select.tscn"
	_starting = true
	if DisplayServer.accessibility_should_reduce_animation() == 1:
		get_tree().change_scene_to_file(destination)
		return
	_intro.kill()
	if _breathing != null:
		_breathing.kill()
	_start_button.disabled = true
	_continue_button.disabled = true
	_demo_button.disabled = true
	_ninja.play("jump")
	var launch := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	launch.tween_property(self, "_launch_progress", 1.0, 0.28)
	launch.tween_property(_ninja, "position", _ninja.position + Vector2(320, -640), 0.28)
	launch.chain().tween_callback(get_tree().change_scene_to_file.bind(destination))
