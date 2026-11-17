extends Prop
## A framed picture on the wall. It hangs still (frozen, see Prop) until the
## beam takes it down; sometimes there's a hole in the wall behind it.

## Which picture is painted on it: 0 sunny hills, 1 moon and stars, 2 rainbow.
@export_range(0, 2) var art: int = 0
## Outside size of the frame in metres (width, height). The canvas, the
## collision box, the weight and how far the beam holds it all follow it.
@export var size := Vector2(0.52, 0.42)

## The size the scene's meshes, mass and hold radius were set up for.
const BASE_SIZE := Vector2(0.52, 0.42)
const FRAME := 0.04
const DEPTH := 0.03


func _ready() -> void:
	if size != BASE_SIZE:
		_resize()
	super()
	# Every copy shares one material, so give this one its own before painting.
	var canvas := $Art as MeshInstance3D
	var material := canvas.material_override.duplicate() as ShaderMaterial
	material.set_shader_parameter("art", art)
	# Keeps the pixel filter's texels about the same size on every canvas.
	material.set_shader_parameter("texel_scale", (size.x - 2.0 * FRAME) / (BASE_SIZE.x - 2.0 * FRAME))
	canvas.material_override = material


## Gives this copy its own meshes and shape at `size` (sub-resources are shared
## between instances of a scene, so editing them in place would resize all).
func _resize() -> void:
	var side := BoxMesh.new()
	side.size = Vector3(FRAME, size.y, DEPTH)
	var top := BoxMesh.new()
	top.size = Vector3(size.x, FRAME, DEPTH)
	var x := size.x / 2.0 - FRAME / 2.0
	var y := size.y / 2.0 - FRAME / 2.0
	for pair: Array in [["FrameL", side, Vector3(-x, 0, 0)], ["FrameR", side, Vector3(x, 0, 0)],
			["FrameTop", top, Vector3(0, y, 0)], ["FrameBottom", top, Vector3(0, -y, 0)]]:
		var piece := get_node(pair[0]) as MeshInstance3D
		piece.mesh = pair[1]
		piece.position = pair[2]
	var quad := QuadMesh.new()
	quad.size = size - Vector2(2.0 * FRAME, 2.0 * FRAME)
	($Art as MeshInstance3D).mesh = quad
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, DEPTH)
	($Shape as CollisionShape3D).shape = box
	mass *= (size.x * size.y) / (BASE_SIZE.x * BASE_SIZE.y)
	hold_radius *= maxf(size.x, size.y) / BASE_SIZE.x
