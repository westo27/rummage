class_name LookSwitcher
extends CanvasLayer
## Temporary art-direction tool: number keys switch between the looks being
## compared. Doesn't save to the settings file. Remove once a look is chosen.
##   4 = rim light and gloss on/off
##   5 = edge rounding filter on/off (edge_round.gd)
## Starts with 4 on and 5 off, reapplied each time a scene loads.

var _label: Label
var _hide_at: float = 0.0
## Each lit material's original [roughness, specular, rim on, rim, rim tint],
## so key 4 can put it back.
var _originals: Dictionary = {}
var wii_finish: bool = false
var edge_round: bool = false


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(24, 60)
	_label.add_theme_font_size_override("font_size", 36)
	_label.visible = false
	add_child(_label)


func _ready() -> void:
	get_tree().scene_changed.connect(_apply_defaults)
	_apply_defaults()


func _apply_defaults() -> void:
	set_wii_finish(true)
	set_edge_round(edge_round)
	_label.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_4: set_wii_finish(not wii_finish)
		KEY_5: set_edge_round(not edge_round)


## The Wii's "toy" finish: a soft sheen round each object's edge (Godot's
## built-in rim: brightens glancing angles on the lit side, tinted partly by
## the surface colour) and a glossier highlight from the lamp.
func set_wii_finish(on: bool) -> void:
	wii_finish = on
	var scene := get_tree().current_scene
	if scene:
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			for mat in _materials(node as MeshInstance3D):
				_apply_finish(mat)
	_show("4: rim + gloss " + ("ON" if on else "off"))


## Adds the filter to the current camera if it hasn't got one, and shows or
## hides it.
func set_edge_round(on: bool) -> void:
	edge_round = on
	var cam := get_viewport().get_camera_3d()
	if cam:
		var quad: Node = cam.get_node_or_null("EdgeRound")
		# Not built until wanted: its shader needs Forward+, so it fails in
		# the browser.
		if quad == null and not on:
			_show("5: edge rounding off")
			return
		if quad == null:
			quad = EdgeRound.new()
			quad.name = "EdgeRound"
			cam.add_child(quad)
		quad.visible = on
	_show("5: edge rounding " + ("ON" if on else "off"))


func _materials(mesh: MeshInstance3D) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	var candidates: Array = [mesh.material_override]
	if mesh.mesh:
		for i in mesh.mesh.get_surface_count():
			candidates.append(mesh.get_active_material(i))
	for m: Variant in candidates:
		var mat := m as StandardMaterial3D
		# Skip unlit and see-through things (glows, eyes, sparkles).
		if mat and mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
				and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not out.has(mat):
			out.append(mat)
	return out


func _apply_finish(mat: StandardMaterial3D) -> void:
	if not _originals.has(mat):
		_originals[mat] = [mat.roughness, mat.metallic_specular, mat.rim_enabled, mat.rim, mat.rim_tint]
	var o: Array = _originals[mat]
	if wii_finish:
		mat.roughness = minf(o[0], 0.4)
		mat.metallic_specular = maxf(o[1], 0.6)
		mat.rim_enabled = true
		mat.rim = 0.7
		mat.rim_tint = 0.4
	else:
		mat.roughness = o[0]
		mat.metallic_specular = o[1]
		mat.rim_enabled = o[2]
		mat.rim = o[3]
		mat.rim_tint = o[4]


func _show(text: String) -> void:
	_label.text = text
	_label.visible = true
	_hide_at = Time.get_ticks_msec() / 1000.0 + 2.0


func _process(_delta: float) -> void:
	if _label.visible and Time.get_ticks_msec() / 1000.0 > _hide_at:
		_label.visible = false
