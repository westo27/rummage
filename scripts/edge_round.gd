class_name EdgeRound
extends MeshInstance3D
## Puts edge_round.gdshader over the whole 3D view: a quad that the shader
## stretches over the screen. Child of the camera so it's never culled.


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/edge_round.gdshader")
	material_override = mat
	# The quad is placed by the shader, not by its transform, so stop Godot
	# deciding it's off screen.
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
