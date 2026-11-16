extends StaticBody3D
## The stable door between the playroom and the bedroom: two halves, one
## above the other. The glazed top half is bolted shut, so you can see into
## the bedroom but have to crouch through the bottom half, which stands open
## against the bedroom wall.
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
## The leaves sit this far toward the bedroom, flush with that side's wall.
const LEAF_X: float = 0.075
const LEAF_THICK: float = 0.05
const STILE: float = 0.1
## How far round the bottom half stands open: nearly flat against the wall.
const OPEN_DEGREES: float = 168.0

const WOOD := Color(0.82, 0.58, 0.34)
const FRAME_WHITE := Color(0.98, 0.97, 0.94)
const CHROME := Color(0.8, 0.8, 0.83)

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
	var hinge_z: float = -leaf_width * 0.5
	# Each leaf's own node sits at its hinge-side bottom corner, the leaf
	# reaching along its +z, so turning the node swings the leaf.
	var top := Node3D.new()
	top.name = "TopHalf"
	top.position = Vector3(LEAF_X, SPLIT_HEIGHT + 0.01, hinge_z)
	add_child(top)
	var top_height: float = OPENING_HEIGHT - LINING - SPLIT_HEIGHT - 0.01
	_build_leaf(top, leaf_width, top_height, true)
	_build_bolt(top, leaf_width)
	# The top half's collision fills the whole upper opening, lining and all.
	_add_collision(Transform3D(Basis.IDENTITY, Vector3(LEAF_X, (SPLIT_HEIGHT + OPENING_HEIGHT) * 0.5, 0.0)),
		Vector3(LEAF_THICK, OPENING_HEIGHT - SPLIT_HEIGHT, OPENING_WIDTH))

	var bottom := Node3D.new()
	bottom.name = "BottomHalf"
	# Hinged on the bedroom face of the wall, so it can fold right back.
	bottom.position = Vector3(LEAF_X + LEAF_THICK * 0.5, 0.01, hinge_z)
	bottom.rotation.y = deg_to_rad(OPEN_DEGREES)
	add_child(bottom)
	var bottom_height: float = SPLIT_HEIGHT - 0.02
	var inner := Node3D.new()  # the leaf itself, set back from the hinge line
	inner.position.x = -LEAF_THICK * 0.5
	bottom.add_child(inner)
	_build_leaf(inner, leaf_width, bottom_height, false)
	for side: float in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.03
		ball.height = 0.06
		knob.mesh = ball
		knob.material_override = _chrome
		knob.position = Vector3(side * (LEAF_THICK * 0.5 + 0.025), bottom_height - 0.2, leaf_width - STILE * 0.5)
		inner.add_child(knob)
	_add_collision(bottom.transform * Transform3D(Basis.IDENTITY,
		Vector3(-LEAF_THICK * 0.5, bottom_height * 0.5, leaf_width * 0.5)),
		Vector3(LEAF_THICK, bottom_height, leaf_width))


## The white lining round the opening: two jambs and a head.
func _build_lining() -> void:
	for side: float in [-1.0, 1.0]:
		_box(self, _white, Vector3(LINING_DEPTH, OPENING_HEIGHT, LINING),
			Vector3(0.0, OPENING_HEIGHT * 0.5, side * (OPENING_WIDTH - LINING) * 0.5))
	_box(self, _white, Vector3(LINING_DEPTH, LINING, OPENING_WIDTH - LINING * 2.0),
		Vector3(0.0, OPENING_HEIGHT - LINING * 0.5, 0.0))


## One half of the door: a frame of stiles (uprights) and rails (crosspieces),
## filled with nine panes of glass or with boards.
func _build_leaf(leaf: Node3D, width: float, height: float, glazed: bool) -> void:
	for z: float in [STILE * 0.5, width - STILE * 0.5]:
		_box(leaf, _wood, Vector3(LEAF_THICK, height, STILE), Vector3(0.0, height * 0.5, z))
	var rail_length: float = width - STILE * 2.0
	for y: float in [STILE * 0.5, height - STILE * 0.5]:
		_box(leaf, _wood, Vector3(LEAF_THICK, STILE, rail_length), Vector3(0.0, y, width * 0.5))
	var inner_height: float = height - STILE * 2.0
	if glazed:
		const BAR: float = 0.03
		for i in [1, 2]:
			_box(leaf, _wood, Vector3(LEAF_THICK * 0.8, inner_height, BAR),
				Vector3(0.0, height * 0.5, STILE + rail_length * i / 3.0))
			_box(leaf, _wood, Vector3(LEAF_THICK * 0.8, BAR, rail_length),
				Vector3(0.0, STILE + inner_height * i / 3.0, width * 0.5))
		var pane := _box(leaf, _glass, Vector3(0.008, inner_height, rail_length),
			Vector3(0.0, height * 0.5, width * 0.5))
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		const BOARDS: int = 5
		const GAP: float = 0.008
		var board_width: float = rail_length / BOARDS
		for i in BOARDS:
			_box(leaf, _wood, Vector3(LEAF_THICK * 0.6, inner_height, board_width - GAP),
				Vector3(0.0, height * 0.5, STILE + board_width * (i + 0.5)))
		# A thin backing so the gaps between boards read as grooves, not holes.
		_box(leaf, _material(WOOD.darkened(0.45), 0.7, 0.0), Vector3(LEAF_THICK * 0.3, inner_height, rail_length),
			Vector3(0.0, height * 0.5, width * 0.5))


## The little barrel bolt that keeps the top half shut: on the playroom face,
## low on the latch side, shot across into a keep on the lining.
func _build_bolt(leaf: Node3D, width: float) -> void:
	var face_x: float = -LEAF_THICK * 0.5
	var y: float = STILE * 0.5
	_box(leaf, _chrome, Vector3(0.004, 0.04, 0.13), Vector3(face_x - 0.002, y, width - 0.075))
	_box(leaf, _chrome, Vector3(0.012, 0.04, 0.03), Vector3(face_x - 0.006, y, width + 0.02))  # the keep
	var bar := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.008
	rod.bottom_radius = 0.008
	rod.height = 0.17
	bar.mesh = rod
	bar.material_override = _chrome
	bar.rotation.x = PI / 2.0  # a cylinder stands upright; lay it along z
	bar.position = Vector3(face_x - 0.012, y, width - 0.05)
	leaf.add_child(bar)
	var handle := MeshInstance3D.new()
	var nub := CylinderMesh.new()
	nub.top_radius = 0.007
	nub.bottom_radius = 0.007
	nub.height = 0.03
	handle.mesh = nub
	handle.material_override = _chrome
	handle.rotation.z = PI / 2.0  # sticking out toward the playroom
	handle.position = Vector3(face_x - 0.03, y, width - 0.08)
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


func _add_collision(at: Transform3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = at
	add_child(shape)


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
