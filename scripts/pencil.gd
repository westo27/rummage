extends Prop
## A pencil: one scene, painted per copy.

@export var paint: Color = Color(0.88, 0.22, 0.2)


func _ready() -> void:
	var body := $Body as MeshInstance3D
	# Materials are shared between copies; give this one its own to paint.
	var mat := (body.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_color = paint
	body.material_override = mat
	super()
