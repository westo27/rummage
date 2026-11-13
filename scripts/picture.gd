extends Prop
## A framed picture on the wall. It hangs still (frozen, see Prop) until the
## beam takes it down; sometimes there's a hole in the wall behind it.

## Which picture is painted on it: 0 sunny hills, 1 moon and stars, 2 rainbow.
@export_range(0, 2) var art: int = 0


func _ready() -> void:
	super()
	# Every copy shares one material, so give this one its own before painting.
	var canvas := $Art as MeshInstance3D
	var material := canvas.material_override.duplicate() as ShaderMaterial
	material.set_shader_parameter("art", art)
	canvas.material_override = material
