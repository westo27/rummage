extends Prop
## An ordinary glass marble: the same glass as the creatures, in one of their
## colours, but no face. A bowl of these hides one that has a face.


func _ready() -> void:
	super()
	var body := $Mesh as MeshInstance3D
	# Its own copy, so each marble gets its own colour and swirl.
	var mat := body.material_override.duplicate() as ShaderMaterial
	mat.set_shader_parameter("tint", Creature.BODY_COLORS.pick_random())
	mat.set_shader_parameter("seed", randf())
	body.material_override = mat
	# A random turn, so the swirls don't all line up.
	body.basis = Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU)
