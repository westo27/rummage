extends StaticBody3D
## The stable door between the playroom and the bedroom: two halves, one
## above the other. The glazed top half is bolted shut, so you can see into
## the bedroom but have to crouch through the bottom half. That starts shut:
## it's a light Prop on a hinge, so the beam pulls it open toward you, into
## the playroom, as with the wardrobe's doors.
##
## Built from boxes here rather than in the scene, since it's all repeats of
## the same few pieces. The node sits on the floor in the middle of the
## doorway; the wall runs along z and the bedroom is on +x.

## The doorway's hole in the wall, and the white lining round it.
const OPENING_WIDTH: float = 1.0
const OPENING_HEIGHT: float = 2.1
const LINING: float = 0.04
const LINING_DEPTH: float = 0.26
## Where the two halves meet. The player is 1.3 m tall standing and 0.95 m
## crouched, so this is what makes you duck.
const SPLIT_HEIGHT: float = 1.1
## The leaves sit this far toward the playroom, flush with that side's wall.
const LEAF_X: float = -0.075
const LEAF_THICK: float = 0.05
const STILE: float = 0.1
## The bottom half: its gap above the floor and below the top half, how far
## it swings into the playroom (nearly flat against the wall), its weight
## (over 3 kg, so it blocks you like furniture rather than being walked
## through) and its hinges' stiffness, which stops it flapping.
const BOTTOM_GAP: float = 0.02
const SWING: float = deg_to_rad(165.0)
const BOTTOM_MASS: float = 3.5
const HINGE_DAMP: float = 3.0

const WOOD := Color(0.82, 0.58, 0.34)
const FRAME_WHITE := Color(0.98, 0.97, 0.94)
const CHROME := Color(0.8, 0.8, 0.83)

## The bottom half, for the beam to grab.
var bottom_half: Prop

var _wood: StandardMaterial3D
var _white: StandardMaterial3D
var _chrome: StandardMaterial3D
var _glass: StandardMaterial3D


func _ready() -> void:
	collision_layer = 1  # world: stops the player, creatures, props and the beam
	collision_mask = 0
	_wood = _material(WOOD, 0.5, 0.0)
	_white = _material(FRAME_WHITE, 0.3, 0.0)
	_chrome = _material(CHROME, 0.25, 0.9)
	_glass = _material(Color(0.8, 0.9, 1.0, 0.12), 0.6, 0.0)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# No shine: a lamp's highlight on smooth glass blooms into a blinding glare.
	_glass.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_build_lining()
	var leaf_width: float = OPENING_WIDTH - LINING * 2.0
	_build_top_half(leaf_width)
	_build_bottom_half(leaf_width)


## The white lining round the opening: two jambs and a head.
func _build_lining() -> void:
	for side: float in [-1.0, 1.0]:
		_box(self, _white, Vector3(LINING_DEPTH, OPENING_HEIGHT, LINING),
			Vector3(0.0, OPENING_HEIGHT * 0.5, side * (OPENING_WIDTH - LINING) * 0.5))
	_box(self, _white, Vector3(LINING_DEPTH, LINING, OPENING_WIDTH - LINING * 2.0),
		Vector3(0.0, OPENING_HEIGHT - LINING * 0.5, 0.0))


## Fixed shut: just meshes, and one collision box filling the upper opening.
func _build_top_half(width: float) -> void:
	var height: float = OPENING_HEIGHT - LINING - SPLIT_HEIGHT - 0.01
	var top := Node3D.new()
	top.name = "TopHalf"
	top.position = Vector3(LEAF_X, SPLIT_HEIGHT + 0.01 + height * 0.5, 0.0)
	add_child(top)
	_build_leaf(top, width, height, true)
	_build_bolt(top, width, height)
	var shape := _box_shape(Vector3(LEAF_THICK, OPENING_HEIGHT - SPLIT_HEIGHT, OPENING_WIDTH))
	shape.position = Vector3(LEAF_X, (SPLIT_HEIGHT + OPENING_HEIGHT) * 0.5, 0.0)
	add_child(shape)


## A Prop of its own, tied to the wall by a HingeJoint3D down one edge, so it
## swings by physics when the beam pulls or pushes it.
func _build_bottom_half(width: float) -> void:
	var height: float = SPLIT_HEIGHT - BOTTOM_GAP * 2.0
	bottom_half = Prop.new()
	bottom_half.name = "BottomHalf"
	bottom_half.mass = BOTTOM_MASS
	bottom_half.hold_radius = 0.5
	bottom_half.jointed_to_room = true
	bottom_half.angular_damp = HINGE_DAMP
	bottom_half.position = Vector3(LEAF_X, BOTTOM_GAP + height * 0.5, 0.0)
	_build_leaf(bottom_half, width, height, false)
	for side: float in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.03
		ball.height = 0.06
		knob.mesh = ball
		knob.material_override = _chrome
		knob.position = Vector3(side * (LEAF_THICK * 0.5 + 0.025), height * 0.5 - 0.2, (width - STILE) * 0.5)
		bottom_half.add_child(knob)
	# A little smaller than it looks, so it clears the wall as it swings.
	var shape := _box_shape(Vector3(LEAF_THICK - 0.01, height - 0.02, width - 0.06))
	shape.position.z = 0.02
	bottom_half.add_child(shape)
	add_child(bottom_half)

	# A hinge turns about its own z axis: this basis stands that axis upright.
	# It sits on the leaf's playroom-side edge, so the leaf can fold right back.
	var hinge := HingeJoint3D.new()
	hinge.name = "BottomHinge"
	hinge.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)),
		Vector3(LEAF_X - LEAF_THICK * 0.5, SPLIT_HEIGHT * 0.5, -width * 0.5))
	add_child(hinge)
	hinge.node_a = hinge.get_path_to(self)
	hinge.node_b = hinge.get_path_to(bottom_half)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	# Which way round is "open into the playroom" was found by trying it.
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -SWING)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, 0.0)


## How far the bottom half is open, in radians (0 = shut).
func open_angle() -> float:
	return global_basis.z.angle_to(bottom_half.global_basis.z)


## Flings the bottom half open. For tests.
func swing_open() -> void:
	# Shut, it rests on its hinge's limit, which soaks up most of one fling,
	# so keep flinging for a few physics ticks until it's clear.
	for i in 10:
		bottom_half.sleeping = false
		bottom_half.angular_velocity = Vector3.DOWN * 16.0
		await get_tree().physics_frame
		if open_angle() > deg_to_rad(20.0):
			return


## One half of the door, centred on `leaf`: a frame of stiles (uprights) and
## rails (crosspieces), filled with nine panes of glass or with boards.
func _build_leaf(leaf: Node3D, width: float, height: float, glazed: bool) -> void:
	for side: float in [-1.0, 1.0]:
		_box(leaf, _wood, Vector3(LEAF_THICK, height, STILE), Vector3(0.0, 0.0, side * (width - STILE) * 0.5))
		_box(leaf, _wood, Vector3(LEAF_THICK, STILE, width - STILE * 2.0), Vector3(0.0, side * (height - STILE) * 0.5, 0.0))
	var inner_width: float = width - STILE * 2.0
	var inner_height: float = height - STILE * 2.0
	if glazed:
		const BAR: float = 0.03
		for side: float in [-1.0, 1.0]:
			_box(leaf, _wood, Vector3(LEAF_THICK * 0.8, inner_height, BAR), Vector3(0.0, 0.0, side * inner_width / 6.0))
			_box(leaf, _wood, Vector3(LEAF_THICK * 0.8, BAR, inner_width), Vector3(0.0, side * inner_height / 6.0, 0.0))
		var pane := _box(leaf, _glass, Vector3(0.008, inner_height, inner_width), Vector3.ZERO)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		const BOARDS: int = 5
		const GAP: float = 0.008
		var board_width: float = inner_width / BOARDS
		for i in BOARDS:
			_box(leaf, _wood, Vector3(LEAF_THICK * 0.6, inner_height, board_width - GAP),
				Vector3(0.0, 0.0, board_width * (i + 0.5) - inner_width * 0.5))
		# A thin backing so the gaps between boards read as grooves, not holes.
		_box(leaf, _material(WOOD.darkened(0.45), 0.7, 0.0), Vector3(LEAF_THICK * 0.3, inner_height, inner_width),
			Vector3.ZERO)


## The little barrel bolt that keeps the top half shut: on the playroom face,
## low on the latch side, shot across into a keep on the lining.
func _build_bolt(leaf: Node3D, width: float, height: float) -> void:
	var face_x: float = -LEAF_THICK * 0.5
	var y: float = (STILE - height) * 0.5
	var edge: float = width * 0.5
	_box(leaf, _chrome, Vector3(0.004, 0.04, 0.13), Vector3(face_x - 0.002, y, edge - 0.075))
	_box(leaf, _chrome, Vector3(0.012, 0.04, 0.03), Vector3(face_x - 0.006, y, edge + 0.02))  # the keep
	var bar := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.008
	rod.bottom_radius = 0.008
	rod.height = 0.17
	bar.mesh = rod
	bar.material_override = _chrome
	bar.rotation.x = PI / 2.0  # a cylinder stands upright; lay it along z
	bar.position = Vector3(face_x - 0.012, y, edge - 0.05)
	leaf.add_child(bar)
	var handle := MeshInstance3D.new()
	var nub := CylinderMesh.new()
	nub.top_radius = 0.007
	nub.bottom_radius = 0.007
	nub.height = 0.03
	handle.mesh = nub
	handle.material_override = _chrome
	handle.rotation.z = PI / 2.0  # sticking out toward the playroom
	handle.position = Vector3(face_x - 0.03, y, edge - 0.08)
	leaf.add_child(handle)


func _box(parent: Node3D, material: Material, size: Vector3, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _box_shape(size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	return shape


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
