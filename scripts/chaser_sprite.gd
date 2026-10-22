extends AnimatedSprite2D

const ART := "res://assets/enemies/star-mountain/"
const POSES := {
	"idle": ["idle"], "walk": ["walk-a", "walk-b"],
	"jump": ["jump"], "descend": ["descend"], "defeated": ["defeated"],
}
var actor: PlayerController


func _ready() -> void:
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
	play("idle")


func _process(_delta: float) -> void:
	var down := actor.get_gravity_vector()
	var tangent := actor.get_walk_axis()
	var local_facing := actor.facing_direction * int(roundf(tangent.dot(Vector2.RIGHT.rotated(Vector2.DOWN.angle_to(down)))))
	flip_h = local_facing < 0
	rotation = 0.0
	var next := "idle"
	if actor.get("defeated") or actor.stun_left > 0.0:
		next = "defeated"
	elif not actor.get("active") or not actor.controls_enabled:
		next = "idle"
	elif actor.get_held_object() != null:
		next = "descend"
	elif actor.is_dashing() or actor.is_wall_grabbing():
		next = "jump"
	elif not actor.is_on_floor():
		var speed := actor.velocity.dot(down)
		next = "descend" if speed > 45.0 and speed < 500.0 else "jump"
		if speed >= 500.0:
			# Falling reuses the jump tilted left; defeated is never a fall frame.
			rotation = -PI / 4.0 * local_facing
	elif absf(actor.velocity.dot(tangent)) > 15.0:
		next = "walk"
	if animation != next:
		play(next)
	speed_scale = clampf(absf(actor.velocity.dot(tangent)) / actor.move_speed, 0.35, 1.5) if next == "walk" else 1.0
	var texture := sprite_frames.get_frame_texture(animation, frame)
	var height := 58.0 if next == "defeated" else 96.0
	scale = Vector2.ONE * height / texture.get_height()
	# Calibrate the torso, rather than centering the changing spread of the hair.
	var anchor: float = {"idle": 0.50, "walk": 0.58 if frame == 0 else 0.61, "jump": 0.55, "descend": 0.54, "defeated": 0.50}[next]
	position = Vector2((0.5 - anchor) * texture.get_width() * scale.x * local_facing, 26.0 - height * 0.5)
