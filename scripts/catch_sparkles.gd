class_name CatchSparkles
extends CPUParticles3D
## A one-off burst of star-shaped sparkles where a creature is caught: white
## glints that tint to the creature's colour, spin, pop to full size and
## twinkle out. Removes itself when done.
##
## CPUParticles3D is Godot's particle emitter that runs on the processor
## rather than the graphics card: for a few dozen particles it's simpler and
## works in the headless tests too. The star shape is drawn into an image in
## code, so there's still no image file.

const LIFETIME: float = 0.7

static var _star: ImageTexture = null


## Makes a burst at `at` in `color`, under `parent`, and returns it.
static func burst(parent: Node, at: Vector3, color: Color) -> CatchSparkles:
	var sparkles := CatchSparkles.new()
	sparkles._setup(color)
	parent.add_child(sparkles)
	sparkles.global_position = at
	sparkles.emitting = true
	return sparkles


func _setup(color: Color) -> void:
	amount = 26
	lifetime = LIFETIME
	one_shot = true
	explosiveness = 0.9
	# Every direction, a little more upward than down.
	direction = Vector3.UP
	spread = 180.0
	initial_velocity_min = 1.2
	initial_velocity_max = 3.0
	gravity = Vector3(0.0, -2.0, 0.0)
	damping_min = 2.0
	damping_max = 3.0
	angle_min = 0.0
	angle_max = 360.0
	angular_velocity_min = -220.0
	angular_velocity_max = 220.0
	scale_amount_min = 0.6
	scale_amount_max = 1.4
	# Pop up to full size quickly, then shrink away: the twinkle.
	var size_over_life := Curve.new()
	size_over_life.add_point(Vector2(0.0, 0.2))
	size_over_life.add_point(Vector2(0.12, 1.0))
	size_over_life.add_point(Vector2(1.0, 0.0))
	scale_amount_curve = size_over_life
	# White at the start, the creature's colour in the middle, gone at the end.
	var tint := Gradient.new()
	tint.set_color(0, Color.WHITE)
	tint.set_color(1, Color(color, 0.0))
	tint.add_point(0.35, color.lightened(0.3))
	color_ramp = tint

	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Additive: sparkles brighten what's behind them, like light, rather than
	# covering it.
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Always face the camera, and take each particle's colour from the ramp.
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _star_texture()
	quad.material = material
	mesh = quad

	finished.connect(queue_free)


## A soft four-pointed star with a bright middle, 64x64, built once.
static func _star_texture() -> ImageTexture:
	if _star != null:
		return _star
	const SIZE: int = 64
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var u: float = (x - 31.5) / 31.5
			var v: float = (y - 31.5) / 31.5
			var r: float = sqrt(u * u + v * v)
			# Two thin bright rays, across and down, plus a glowing core.
			var rays: float = maxf(exp(-absf(u) * 14.0) * exp(-absf(v) * 2.4),
				exp(-absf(v) * 14.0) * exp(-absf(u) * 2.4))
			var core: float = exp(-r * r * 18.0)
			var alpha: float = clampf(rays + core, 0.0, 1.0) * clampf(1.0 - r, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_star = ImageTexture.create_from_image(image)
	return _star
