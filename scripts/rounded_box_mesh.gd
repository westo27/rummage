@tool
class_name RoundedBoxMesh
extends PrimitiveMesh
## A BoxMesh with rounded edges and corners, so they catch a soft highlight
## instead of a hard crease. Drop-in for BoxMesh: same `size`, centred on the
## origin. Collision can stay a plain BoxShape3D.
##
## Extending PrimitiveMesh means Godot calls _create_mesh_array() to build the
## surface whenever a property changes, like its own primitives. @tool makes
## that happen in the editor too.

@export var size: Vector3 = Vector3.ONE:
	set(v):
		size = v
		request_update()
## How round the edges are, in metres. Clamped to just under half the
## smallest side, so thin boards still work.
@export_range(0.0, 0.5, 0.001, "or_greater") var radius: float = 0.03:
	set(v):
		radius = v
		request_update()
## Steps around each rounded edge. 4 is smooth enough at game distances.
@export_range(1, 12) var segments: int = 4:
	set(v):
		segments = v
		request_update()


func _create_mesh_array() -> Array:
	var half := size * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.98)
	var inner := half - Vector3.ONE * r
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	# Each face is a grid over the face's two in-plane axes. Along each axis the
	# grid steps through the rounded band, jumps across the flat middle, then
	# steps through the far band. Every grid point sits on the box's surface
	# (`c`); pushing it out from the nearest point of the shrunken inner box by
	# `r` rounds it. The same point on two neighbouring faces lands in the same
	# place with the same normal, so the faces meet without a seam.
	for axis in 3:
		for sgn: float in [-1.0, 1.0]:
			var u_axis := (axis + 1) % 3
			var v_axis := (axis + 2) % 3
			var us := _steps(half[u_axis], inner[u_axis])
			var vs := _steps(half[v_axis], inner[v_axis])
			var start := verts.size()
			for j in vs.size():
				for i in us.size():
					var c := Vector3.ZERO
					c[axis] = half[axis] * sgn
					c[u_axis] = us[i]
					c[v_axis] = vs[j]
					var core := c.clamp(-inner, inner)
					var n := (c - core).normalized()
					if n == Vector3.ZERO:
						n[axis] = sgn
					verts.append(core + n * r)
					normals.append(n)
					uvs.append(Vector2(float(i) / (us.size() - 1), float(j) / (vs.size() - 1)))
			var w := us.size()
			for j in vs.size() - 1:
				for i in w - 1:
					var a := start + j * w + i
					var b := a + 1
					var d := a + w
					var e := d + 1
					# Godot draws clockwise triangles as the front, so the
					# winding flips with the face's side.
					if sgn > 0.0:
						indices.append_array([a, d, b, b, d, e])
					else:
						indices.append_array([a, b, d, b, e, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## Grid positions along one axis: the rounded band at each end in `segments`
## steps, eased so the steps are even in angle rather than distance.
func _steps(h: float, inner_h: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var band := h - inner_h
	for k in segments + 1:
		out.append(-inner_h - band * cos(PI * 0.5 * k / segments))
	for k in segments + 1:
		out.append(inner_h + band * sin(PI * 0.5 * k / segments))
	return out
