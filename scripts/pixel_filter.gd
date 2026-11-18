class_name PixelFilter
extends CanvasLayer
## Graphics > Screen filter: draws the 3D view at a low resolution, either in
## big square pixels (Pixel) or smoothly upscaled like an old TV (Soft).
##
## A CanvasLayer's `layer` sets its draw order among 2D layers. At -100 it's
## drawn before every other one, so its screen texture is just the rendered 3D
## world, and the HUD (layer 0 and up) lands crisp on top.
##
## Menus and buttons sit on higher layers, so they stay crisp too.
##
## Lives under the Game autoload so it survives scene changes.

const PIXEL_SHADER: Shader = preload("res://shaders/pixel_filter.gdshader")
const SOFT_SHADER: Shader = preload("res://shaders/soft_filter.gdshader")

var _rect: ColorRect
var _material: ShaderMaterial


func _init() -> void:
	layer = -100
	_material = ShaderMaterial.new()
	_material.shader = PIXEL_SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)


## Swaps between the chunky and the soft shader. Both take `target_rows`.
func set_soft(soft: bool) -> void:
	_material.shader = SOFT_SHADER if soft else PIXEL_SHADER


func is_soft() -> bool:
	return _material.shader == SOFT_SHADER


## `rows` is how many low-res pixels tall the screen is.
func set_rows(rows: float) -> void:
	_material.set_shader_parameter("target_rows", rows)

