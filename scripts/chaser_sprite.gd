extends AnimatedSprite2D

const ART := "res://assets/enemies/star-mountain/"
const DISPLAY_HEIGHT := 128.0
const POSES := {
	"idle": ["idle"], "idle_left": ["idle-left"], "walk": ["walk-a", "walk-b"],
	"jump": ["jump"], "descend": ["descend"], "defeated": ["defeated"],
	"carry_walk": ["carry-a", "carry-b"], "wall_climb": ["wall-climb"],
	"dash": ["dash"], "superdash": ["superdash"], "throwback": ["throwback"],
}
var actor: PlayerController
var calibration: Dictionary
var superdash_left := 0.0


func _ready() -> void:
	calibration = JSON.parse_string(FileAccess.get_file_as_string(ART + "poses.json"))
	sprite_frames = SpriteFrames.new()
	for pose in POSES:
		sprite_frames.add_animation(pose)
		sprite_frames.set_animation_speed(pose, 6.0)
		for file in POSES[pose]:
			var source: Texture2D = load(ART + file + ".png")
			var cropped := AtlasTexture.new()
			cropped.atlas = source
			cropped.region = source.get_image().get_used_rect()
			sprite_frames.add_frame(pose, cropped)
	actor.movement_action.connect(func(action):
		if action == "superdash":
			superdash_left = 0.3
	)
	play("idle")


func _process(delta: float) -> void:
	superdash_left = maxf(0.0, superdash_left - delta)
	var down := actor.get_gravity_vector()
	var tangent := actor.get_walk_axis()
	var local_facing := actor.facing_direction * int(roundf(tangent.dot(Vector2.RIGHT.rotated(Vector2.DOWN.angle_to(down)))))
	rotation = 0.0
	var next := "idle_left" if local_facing < 0 else "idle"
	var walking := actor.is_on_floor() and absf(actor.velocity.dot(tangent)) > 15.0
	if actor.get("defeated"):
		next = "defeated"
	elif actor.get("throw_pose_left") > 0.0:
		next = "throwback"
	elif actor.stun_left > 0.0:
		next = "defeated"
	elif actor.get("active") and actor.controls_enabled:
		if actor.get_held_object() != null:
			next = "carry_walk" if walking else "descend"
		elif superdash_left > 0.0:
			next = "superdash"
		elif actor.is_dashing():
			next = "dash"
		elif actor.is_wall_grabbing():
			next = "wall_climb"
		elif not actor.is_on_floor():
			var speed := actor.velocity.dot(down)
			next = "descend" if speed > 45.0 and speed < 500.0 else "jump"
			if speed >= 500.0:
				rotation = -PI / 4.0 * local_facing
		elif walking:
			next = "walk"
	if animation != next:
		play(next)
	speed_scale = clampf(absf(actor.velocity.dot(tangent)) / actor.move_speed, 0.35, 1.5) if next in ["walk", "carry_walk"] else 1.0
	apply_frame(local_facing)


func apply_frame(local_facing: int) -> void:
	var file: String = POSES[animation][frame]
	var data: Dictionary = calibration[file]
	var texture := sprite_frames.get_frame_texture(animation, frame) as AtlasTexture
	# Exclude motion trails and the throwback vortex when measuring the body.
	scale = Vector2.ONE * DISPLAY_HEIGHT / float(data.reference_height)
	flip_h = local_facing < 0
	if animation == &"idle_left":
		flip_h = false
	elif animation == &"throwback":
		flip_h = local_facing > 0
	var anchor := Vector2(data.anchor[0], data.anchor[1])
	var offset := (texture.region.get_center() - anchor) * scale
	position = Vector2(offset.x * (-1.0 if flip_h else 1.0), 26.0 + offset.y)
