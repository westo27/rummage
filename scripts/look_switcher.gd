class_name LookSwitcher
extends CanvasLayer
## Temporary art-direction tool: number keys switch between the looks being
## compared. Doesn't save to the settings file; the Graphics menu takes over
## again as soon as it's touched. Remove once a look is chosen.
##   1 = filter off (smooth, Wii-like)
##   2 = smooth pixels at 270p (no dither, no texel snap)
##   3 = smooth pixels at 360p
##   4 = rim light and gloss on/off (on top of any of the above)

var _label: Label
var _hide_at: float = 0.0
## Each lit material's original [roughness, specular, rim on, rim, rim tint],
## so key 4 can put it back.
var _originals: Dictionary = {}
var wii_finish: bool = false


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(24, 60)
	_label.add_theme_font_size_override("font_size", 36)
	_label.visible = false
	add_child(_label)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: set_look("1: filter off", false, 3)
		KEY_2: set_look("2: smooth 270p", true, 3)
		KEY_3: set_look("3: smooth 360p", true, 2)
		KEY_4: set_wii_finish(not wii_finish)


func set_look(title: String, filter: bool, strength: int) -> void:
	Game.settings.pixel_filter = filter
	Game.settings.pixel_strength = strength
	Game.settings.apply_pixel_filter()
	Game.pixel_filter.set_colour_limit(false)
	# No texel snapping on surfaces (apply_pixel_filter just turned it on).
	RenderingServer.global_shader_parameter_set("pixel_texels", 0.0)
	_show(title)


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
