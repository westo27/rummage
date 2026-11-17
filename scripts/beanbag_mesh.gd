@tool
extends MeshInstance3D
## The beanbag's shape, built in code: a slumped pear of fabric with a flat
## base, a dent where someone sat, a back that stands up a little higher,
## six stitched panels and a round cap on top. The collision shape next to it
## (Shape0) gets a convex hull of the same shape, so it sits and rolls like it.
##
## @tool: runs in the editor too, so the scene shows the real shape.

const RADIUS: float = 0.42
const HEIGHT: float = 0.5
const PANELS: int = 6
## Grid size: around, and bottom to top.
const AROUND: int = 72
const UP: int = 40

## Built once and shared by every beanbag.
static var _shared: ArrayMesh


func _ready() -> void:
	if _shared == null:
		_shared = _build()
	mesh = _shared
	var shape := get_parent().get_node_or_null("Shape0") as CollisionShape3D
	if shape != null and not Engine.is_editor_hint():
		shape.shape = _shared.create_convex_shape(true, true)


## A point on the surface. `a` goes round (radians), `u` from the bottom (0)
## to the top (1).
static func _point(a: float, u: float) -> Vector3:
	var phi: float = u * PI
	var s: float = sin(phi)
	var c: float = cos(phi)
	# Powers under 1 square off the base and top, so it sits flat.
	var radial: float = RADIUS * pow(s, 0.55)
	var y: float = -signf(c) * pow(absf(c), 0.55) * HEIGHT * 0.5
	# Pear: wide and slumped low, narrower up top.
	radial *= 1.0 + 0.1 * (1.0 - u) - 0.36 * u * u
	# Lumps of filling and loose wrinkles in the cloth.
	radial += 0.022 * sin(3.0 * a + 1.3) * sin(2.0 * phi)
	radial += 0.008 * sin(9.0 * a + 4.0 * phi) * s
	# Grooves where the panels are stitched together.
	radial -= 0.009 * _seam(a) * s
	var p := Vector3(cos(a) * radial, y, sin(a) * radial)
	# The back (towards -Z) bunches up into a backrest, the front slumps,
	# and the seat is a deep dip towards the front.
	var top: float = smoothstep(0.35, 1.0, u)
	var back: float = clampf(-sin(a), 0.0, 1.0)
	p.y += top * 0.17 * back * back
	p.y -= top * 0.05 * clampf(sin(a), 0.0, 1.0)
	var seat: float = Vector2(p.x, p.z - 0.08).length() / RADIUS
	p.y -= top * 0.13 * exp(-seat * seat / 0.2)
	# Leans back a little, as if pushed.
	p.z -= 0.06 * u * u
	return p


## 1 on a panel seam, falling to 0 a couple of centimetres either side.
static func _seam(a: float) -> float:
	var panel: float = TAU / PANELS
	var off: float = absf(fposmod(a + panel * 0.5, panel) - panel * 0.5)
	var width: float = 0.02 / RADIUS  # radians
	return exp(-pow(off / width, 2.0))


## Shade baked into the vertex colour: darker in seams and down at the base.
static func _shade(a: float, u: float) -> float:
	var cap: float = exp(-pow((u - 0.86) / 0.015, 2.0))  # the cap's stitching
	var seam: float = maxf(_seam(a) * smoothstep(0.03, 0.15, u) * (1.0 - smoothstep(0.84, 0.88, u)), cap)
	return (1.0 - 0.28 * seam) * lerpf(0.82, 1.0, smoothstep(0.0, 0.35, u))


static func _build() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var eps: float = 0.001
	for j in UP + 1:
		var u: float = float(j) / UP
		for i in AROUND + 1:
			var a: float = TAU * i / AROUND
			var p: Vector3 = _point(a, u)
			# Normal from the surface's slope both ways, which stays smooth
			# across the column where the grid wraps round.
			var da: Vector3 = _point(a + eps, u) - _point(a - eps, u)
			var du: Vector3 = _point(a, minf(u + eps, 1.0)) - _point(a, maxf(u - eps, 0.0))
			var n: Vector3 = du.cross(da)
			if j == 0 or n.length() < 1e-9:
				n = Vector3.DOWN
			elif j == UP:
				n = Vector3.UP
			verts.append(p)
			normals.append(n.normalized())
			var shade: float = _shade(a, u)
			colors.append(Color(shade, shade, shade))
	var row: int = AROUND + 1
	for j in UP:
		for i in AROUND:
			var k: int = j * row + i
			indices.append_array([k, k + 1, k + row, k + 1, k + row + 1, k + row])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return built
