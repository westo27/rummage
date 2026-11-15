class_name LookSwitcher
extends CanvasLayer
## Temporary art-direction tool: 1, 2, 3 switch between the looks being
## compared. Doesn't save to the settings file; the Graphics menu takes over
## again as soon as it's touched. Remove once a look is chosen.
##   1 = filter off (smooth, Wii-like)
##   2 = smooth pixels at 270p (no dither, no texel snap)
##   3 = smooth pixels at 360p

var _label: Label
var _hide_at: float = 0.0


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
		KEY_1: _set_look("1: filter off", false, 3)
		KEY_2: _set_look("2: smooth 270p", true, 3)
		KEY_3: _set_look("3: smooth 360p", true, 2)


func _set_look(title: String, filter: bool, strength: int) -> void:
	Game.settings.pixel_filter = filter
	Game.settings.pixel_strength = strength
	Game.settings.apply_pixel_filter()
	Game.pixel_filter.set_colour_limit(false)
	# No texel snapping on surfaces (apply_pixel_filter just turned it on).
	RenderingServer.global_shader_parameter_set("pixel_texels", 0.0)
	_label.text = title
	_label.visible = true
	_hide_at = Time.get_ticks_msec() / 1000.0 + 2.0


func _process(_delta: float) -> void:
	if _label.visible and Time.get_ticks_msec() / 1000.0 > _hide_at:
		_label.visible = false
