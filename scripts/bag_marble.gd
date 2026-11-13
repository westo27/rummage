class_name BagMarble
extends RigidBody2D
## One caught creature in the HUD's marble bag: a ball in the creature's
## colour, with eyes. It's a real 2D physics body, so it rolls, bounces and
## settles on the pile, which is why the eyes end up at odd angles.
##
## The shading and the shine are drawn counter-rotated, so the light always
## comes from the top left of the screen while the eyes turn with the ball.

## Emitted the first time it hits anything (the bag or another marble), with
## how fast it was going. The bag uses it to squash.
signal landed(speed: float)

## Sized so all 25 fill a little over half the bag: it looks properly full by
## the end without spilling out of the neck.
const RADIUS: float = 21.0
## Slower bumps than this (px/s) are settling, not impacts, and make no sound.
const CLACK_SPEED: float = 70.0

var color: Color = Color.WHITE

var _has_landed: bool = false
## Speed on the previous physics tick. By the time body_entered fires the
## collision has already slowed it, so the speed just before is the useful one.
var _last_speed: float = 0.0
var _voice: AudioStreamPlayer


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)

	var material := PhysicsMaterial.new()
	material.bounce = 0.25
	material.friction = 0.5
	physics_material_override = material
	# Checks along the path each tick rather than only where it ends up, so a
	# fast drop can't pass through the thin bag walls.
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# body_entered only fires with contact monitoring on.
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	_voice = AudioStreamPlayer.new()
	_voice.stream = Tones.clack()
	add_child(_voice)


func _physics_process(_delta: float) -> void:
	_last_speed = linear_velocity.length()


func _process(_delta: float) -> void:
	# _draw only re-runs when asked, and the shading depends on rotation.
	if not sleeping:
		queue_redraw()


func _on_body_entered(_body: Node) -> void:
	if _last_speed > CLACK_SPEED:
		_voice.pitch_scale = randf_range(0.85, 1.25)
		_voice.volume_db = linear_to_db(clampf(_last_speed / 600.0, 0.12, 1.0)) - 6.0
		_voice.play()
	if not _has_landed:
		_has_landed = true
		landed.emit(_last_speed)


func _draw() -> void:
	# Everything is laid out in units of the radius, so the ball can be resized
	# by changing RADIUS alone.
	var r: float = RADIUS
	# Body and shading, fixed to the screen so the light doesn't spin.
	draw_set_transform(Vector2.ZERO, -rotation)
	draw_circle(Vector2.ZERO, r, color.darkened(0.35))
	draw_circle(Vector2(-0.06, -0.09) * r, r * 0.88, color)
	draw_circle(Vector2(-0.15, -0.24) * r, r * 0.58, color.lightened(0.18))

	# Eyes, which turn with the ball.
	draw_set_transform(Vector2.ZERO, 0.0)
	for side: float in [-1.0, 1.0]:
		var eye := Vector2(0.36 * side, -0.18) * r
		draw_circle(eye, r * 0.27, Color.WHITE)
		draw_circle(eye + Vector2(0.0, 0.07) * r, r * 0.13, Color(0.05, 0.05, 0.06))

	# Shine on top of everything, back in screen space.
	draw_set_transform(Vector2.ZERO, -rotation)
	draw_circle(Vector2(-0.36, -0.48) * r, r * 0.22, Color(1.0, 1.0, 1.0, 0.7))
	draw_circle(Vector2(-0.2, -0.63) * r, r * 0.1, Color(1.0, 1.0, 1.0, 0.85))
