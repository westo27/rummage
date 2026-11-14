class_name PixelFilter
extends CanvasLayer
## Graphics > Pixel filter: draws the 3D view in big square pixels.
##
## A CanvasLayer's `layer` sets its draw order among 2D layers. At -100 it's
## drawn before every other one, so its screen texture is just the rendered 3D
## world, and the HUD (layer 0 and up) lands crisp on top.
##
## Menus get the look too: while any menu button is on screen, a second copy
## of the filter is drawn above all the UI, so it pixelates the menu along
## with everything under it. Running the filter over the already-filtered 3D
## changes nothing (same grid, colours already on their shades).
##
## Lives under the Game autoload so it survives scene changes.

## Above the pause menu (10) and the HUD.
const MENU_LAYER: int = 50

var _rect: ColorRect
var _menu_layer: CanvasLayer


func _init() -> void:
	layer = -100
	# Keeps checking for menus while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/pixel_filter.gdshader")
	_rect = _make_rect(material)
	add_child(_rect)
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = MENU_LAYER
	_menu_layer.visible = false
	_menu_layer.add_child(_make_rect(material))
	add_child(_menu_layer)


func _make_rect(material: ShaderMaterial) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	return rect


func _process(_delta: float) -> void:
	var menu_open: bool = false
	if visible:
		for panel: Control in get_tree().get_nodes_in_group("menu_panels"):
			if panel.is_visible_in_tree():
				menu_open = true
				break
	_menu_layer.visible = menu_open


## `rows` is how many chunky pixels tall the screen is.
func set_rows(rows: float) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("target_rows", rows)
