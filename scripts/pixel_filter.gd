class_name PixelFilter
extends CanvasLayer
## Graphics > Pixel filter: draws the 3D view in big square pixels.
##
## A CanvasLayer's `layer` sets its draw order among 2D layers. At -100 it's
## drawn before every other one, so its screen texture is just the rendered 3D
## world, and the HUD (layer 0 and up) lands crisp on top.
##
## Menus and buttons sit on higher layers, so they stay crisp too.
##
## Lives under the Game autoload so it survives scene changes.

var _rect: ColorRect
var _material: ShaderMaterial


func _init() -> void:
	layer = -100
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/pixel_filter.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)


## `rows` is how many chunky pixels tall the screen is.
func set_rows(rows: float) -> void:
	_material.set_shader_parameter("target_rows", rows)


func set_dither(on: bool) -> void:
	_material.set_shader_parameter("dither", on)

