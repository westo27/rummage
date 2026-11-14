class_name PendantLamp
extends Node3D
## A ceiling lamp that hangs on its cord and swings when something hits it.
##
## The node itself sits on the ceiling, where the cord is fixed. The shade,
## bulb and light all belong to `Lamp`, a RigidBody3D hanging below, held to
## that point by a PinJoint3D: a joint that keeps one point of a body fixed
## and lets it turn freely around it, which makes it a pendulum. Hit it with
## a thrown book, or swing a held crate into it, and it swings; the light
## goes with it, so the shadows and the warm pool of light sweep around the
## room until it settles.
##
## It's on the props collision layer, so props bump into it, but it isn't a
## Prop, so the beam can't grab it (and can't yank it off the ceiling).

## The lamp's brightness and how far its light reaches, set per room.
@export var light_energy: float = 0.55
@export var light_range: float = 6.5
## Half the width (x) and depth (z) of the lamp's room, measured from the
## lamp. The lamp casts shadows only while the camera is in that room or
## close to it; its light stays on either way. A swinging lamp's shadow is
## redrawn in six directions every frame, which is most of the game's GPU
## cost, and from another room it's mostly hidden by walls anyway.
@export var room_half_size: Vector2 = Vector2(2.45, 2.2)
## How far outside the room the camera can be and still get the shadows, so
## they're already on as you come through a doorway.
const SHADOW_MARGIN: float = 0.8

## Switch off to stop this lamp casting shadows anywhere.
var shadows_allowed: bool = true

const LAYER_PROPS: int = 4
const MASK_WORLD_PROPS_CLUTTER: int = 1 | 4 | 16

@onready var _lamp: RigidBody3D = $Lamp
@onready var _light: OmniLight3D = $Lamp/Light
## A weaker light with no shadows: the glow that comes through the fabric of
## the shade. Without it, everything the shade blocks gets no lamp light at
## all and its shadow ends in a hard line on the walls; with it, that's a
## gentle step from bright to dimmer.
@onready var _glow: OmniLight3D = $Lamp/GlowThroughShade

## How bright the glow through the shade is, compared with the lamp itself.
const SHADE_GLOW_SHARE: float = 0.2
@onready var _cord: MeshInstance3D = $Cord


func _ready() -> void:
	# Lets the Graphics > Lighting setting find every lamp (Settings.apply_lighting).
	add_to_group("lamps")
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_glow.light_energy = light_energy * SHADE_GLOW_SHARE
	_glow.omni_range = light_range * 0.875
	_lamp.collision_layer = LAYER_PROPS
	_lamp.collision_mask = MASK_WORLD_PROPS_CLUTTER
	# The cord is redrawn every frame from the ceiling to the top of the shade,
	# so it's placed in world space rather than following its parent.
	_cord.top_level = true
	_cord.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(_delta: float) -> void:
	_place_cord()
	_light.shadow_enabled = shadows_allowed and _camera_is_near()


func _camera_is_near() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return true
	var offset: Vector3 = camera.global_position - global_position
	return absf(offset.x) < room_half_size.x + SHADOW_MARGIN 		and absf(offset.z) < room_half_size.y + SHADOW_MARGIN


## Stretches the cord (a cylinder one metre tall) between the fixing on the
## ceiling and the top of the shade, using where the shade is *drawn* this
## frame so the two never come apart.
func _place_cord() -> void:
	var top: Vector3 = global_position
	var shade_top: Vector3 = _lamp.get_global_transform_interpolated() * Vector3(0.0, 0.13, 0.0)
	var along: Vector3 = shade_top - top
	var length: float = along.length()
	if length < 0.001:
		return
	# A basis whose y axis runs along the cord (scaled to its length), so the
	# cylinder's height lies along it.
	var y_axis: Vector3 = along / length
	var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD)
	if x_axis.length() < 0.01:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis)
	_cord.global_transform = Transform3D(Basis(x_axis, y_axis * length, z_axis), (top + shade_top) * 0.5)


## How soft the lamp's shadows are. `size` is the light's size in metres:
## bigger makes shadows blur more the further they fall from the shade,
## which looks best and costs the most. `blur` softens every shadow evenly,
## which is cheap. Set by Settings.apply_lighting.
func set_shadow_softness(size: float, blur: float) -> void:
	_light.light_size = size
	_light.shadow_blur = blur


## The lamp's light, for tests.
func light() -> OmniLight3D:
	return _light


## Where the light is right now: for tests.
func light_position() -> Vector3:
	return _light.global_position


## How far the shade has swung sideways from hanging straight down, in metres.
func swing() -> float:
	return Vector2(_lamp.global_position.x - global_position.x,
		_lamp.global_position.z - global_position.z).length()


## How far the shade is from the fixing on the ceiling: for tests (it should
## never change, however hard the lamp is hit).
func hang_length() -> float:
	return _lamp.global_position.distance_to(global_position)
