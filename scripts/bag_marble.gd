class_name BagMarble
extends RigidBody2D
## One caught creature in the HUD's marble bag: a glass marble like the menu
## text, with a swirl in the creature's colour, and eyes. It's a real 2D
## physics body, so it rolls, bounces and settles on the pile, which is why
## the eyes end up at odd angles.
##
## The glass (shaders/glass_marble.gdshader) is drawn by a child node, since
## a material covers everything its node draws and the eyes should stay
## plain. The light always comes from the top left of the screen while the
## swirl and eyes turn with the ball.

## Emitted the first time it hits anything (the bag or another marble), with
## how fast it was going. The bag uses it to squash.
signal landed(speed: float)

## Sized so all 25 fill a little over half the bag: it looks properly full by
## the end without spilling out of the neck.
const RADIUS: float = 21.0
## Slower bumps than this (px/s) are settling, not impacts, and make no sound.
const CLACK_SPEED: float = 70.0
## How far below full volume the hardest clack plays (dB).
const CLACK_QUIETER_DB: float = 20.0

var color: Color = Color.WHITE

const GLASS_SHADER: Shader = preload("res://shaders/glass_marble.gdshader")

var _has_landed: bool = false
## Speed on the previous physics tick. By the time body_entered fires the
## collision has already slowed it, so the speed just before is the useful one.
var _last_speed: float = 0.0
var _voice: AudioStreamPlayer
var _glass: Node2D
var _face: Node2D
var _glass_material: ShaderMaterial


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

	# Each ball has its own material: its colour, swirl and spin differ.
	_glass_material = ShaderMaterial.new()
	_glass_material.shader = GLASS_SHADER
	_glass_material.set_shader_parameter("tint", color)
	_glass_material.set_shader_parameter("seed", randf())
	_glass = Node2D.new()
	_glass.material = _glass_material
	_glass.draw.connect(_draw_glass)
	add_child(_glass)
	_face = Node2D.new()
	_face.draw.connect(_draw_face)
	add_child(_face)

	_voice = AudioStreamPlayer.new()
	_voice.stream = Tones.clack(0)
	add_child(_voice)


func _physics_process(_delta: float) -> void:
	_last_speed = linear_velocity.length()


func _process(_delta: float) -> void:
	# The glass quad is drawn counter-rotated, so it's redrawn as the ball
	# turns. (The face turns with the node by itself.)
	if not sleeping:
		_glass_material.set_shader_parameter("spin", rotation)
		_glass.queue_redraw()


func _on_body_entered(_body: Node) -> void:
	# The bag moving onto the win card takes every ball out of the scene
	# for a moment, and a bump during that can't play a sound.
	if not is_inside_tree():
		return
	if _last_speed > CLACK_SPEED:
		# One of three takes, a little higher or lower each time, so a pile of
		# balls settling sounds like a handful of marbles, not one sound repeated.
		_voice.stream = Tones.clack(randi() % 3)
		_voice.pitch_scale = randf_range(0.88, 1.08)
		# Harder knocks are louder; the hardest well under the squeaks.
		_voice.volume_db = linear_to_db(clampf(_last_speed / 400.0, 0.2, 1.0)) - CLACK_QUIETER_DB
		_voice.play()
	if not _has_landed:
		_has_landed = true
		landed.emit(_last_speed)


## Draws the face: eyes that turn with the ball. The glass body is drawn by
## _glass (a child with the glass_marble shader) underneath.
func _draw_face() -> void:
	for side: float in [-1.0, 1.0]:
		var eye := Vector2(0.36 * side, -0.18) * RADIUS
		_face.draw_circle(eye, RADIUS * 0.27, Color.WHITE)
		_face.draw_circle(eye + Vector2(0.0, 0.07) * RADIUS, RADIUS * 0.13, Color(0.05, 0.05, 0.06))


## The glass body: one quad over the ball, kept upright on screen so the
## shader's light stays at the top left. The shader turns the swirl by `spin`.
func _draw_glass() -> void:
	_glass.draw_set_transform(Vector2.ZERO, -rotation)
	var r: float = RADIUS
	_glass.draw_primitive(
		PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]),
		PackedColorArray([Color.WHITE]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
