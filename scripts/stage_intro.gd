class_name StageIntro
extends CanvasLayer

const HOLD_TIME := 0.5
const RETURN_TIME := 0.2
const IRIS_RADIUS := 96.0

var _player: PlayerController
var _camera: Camera2D
var _intro_camera: Camera2D
var _curtain: ColorRect
var _stage_mode: ProcessMode
var _was_paused := false
var _controls_enabled := true
var _holding := true
var _elapsed := 0.0
var _start_position := Vector2.ZERO
var _start_zoom := Vector2.ONE
var _reduced_motion := false


static func play(stage: Node, player: PlayerController, camera: Camera2D) -> void:
	var intro := StageIntro.new()
	intro.name = "StageIntro"
	intro._player = player
	intro._camera = camera
	stage.add_child(intro)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	_stage_mode = get_parent().process_mode
	_was_paused = get_tree().paused
	_controls_enabled = _player.controls_enabled
	_reduced_motion = DisplayServer.accessibility_should_reduce_animation() == 1
	_player.controls_enabled = false
	_player.respawned.connect(finish)
	# The tutorial and stage 6 normally process even while the tree is paused.
	get_parent().process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	_camera.reset_smoothing()
	_intro_camera = Camera2D.new()
	add_child(_intro_camera)
	_start_zoom = _camera.zoom * (1.0 if _reduced_motion else 1.4)
	var half_view := get_viewport().get_visible_rect().size * 0.5 / _camera.zoom
	var half_intro := get_viewport().get_visible_rect().size * 0.5 / _start_zoom
	# Keep the enlarged view inside the stage camera's already bounded view.
	_start_position = _player.global_position.clamp(_camera.global_position - half_view + half_intro, _camera.global_position + half_view - half_intro)
	_intro_camera.zoom = _start_zoom
	_intro_camera.global_position = _start_position
	_intro_camera.make_current()
	_intro_camera.force_update_scroll()
	_curtain = ColorRect.new()
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.material = ShaderMaterial.new()
	_curtain.material.shader = preload("res://assets/ui/stage-intro.gdshader")
	add_child(_curtain)
	_update_iris(0.0)


func _process(delta: float) -> void:
	var pause_menu := get_parent().get_node("PauseMenu")
	if pause_menu.overlay.visible or get_node("/root/InputSettings").panel.visible or get_node("/root/DemoMode").warning_active or (not _holding and get_tree().paused):
		return
	_elapsed += delta
	if _holding:
		if _elapsed < HOLD_TIME:
			return
		_release_world()
		if _reduced_motion:
			finish()
			return
	var progress := minf((_elapsed - HOLD_TIME) / RETURN_TIME, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3)
	_intro_camera.zoom = _start_zoom.lerp(_camera.zoom, eased)
	_intro_camera.global_position = _start_position.lerp(_camera.global_position, eased)
	_intro_camera.force_update_scroll()
	_update_iris(eased)
	if progress >= 1.0:
		finish()


func _update_iris(progress: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var center := get_viewport().get_canvas_transform() * _player.global_position
	_curtain.size = size
	_curtain.material.set_shader_parameter("viewport_size", size)
	_curtain.material.set_shader_parameter("center", center)
	_curtain.material.set_shader_parameter("radius", lerpf(IRIS_RADIUS, size.length(), progress))


func _release_world() -> void:
	if not _holding:
		return
	_holding = false
	get_parent().process_mode = _stage_mode
	get_tree().paused = _was_paused
	_player.controls_enabled = _controls_enabled


func finish() -> void:
	if is_queued_for_deletion():
		return
	_release_world()
	_restore_camera()
	hide()
	set_process(false)
	queue_free()


func _restore_camera() -> void:
	if is_instance_valid(_camera) and _camera.is_inside_tree():
		_camera.make_current()
		_camera.reset_smoothing()
		_camera.force_update_scroll()


func _exit_tree() -> void:
	_release_world()
	_restore_camera()
