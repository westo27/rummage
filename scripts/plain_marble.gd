extends Prop
## An ordinary glass marble: the same glass as the creatures but grey, and no
## face, so it's plainly not one of them. A bowl of these hides one that is.

## How light the grey is, picked between these per marble.
const GREY_MIN: float = 0.45
const GREY_MAX: float = 0.7


func _ready() -> void:
	super()
	var body := $Mesh as MeshInstance3D
	# Its own copy, so each marble gets its own shade and swirl.
	var mat := body.material_override.duplicate() as ShaderMaterial
	var grey: float = randf_range(GREY_MIN, GREY_MAX)
	mat.set_shader_parameter("tint", Color(grey, grey, grey * 1.04))
	mat.set_shader_parameter("seed", randf())
	body.material_override = mat
	# A random turn, so the swirls don't all line up.
	body.basis = Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU)
