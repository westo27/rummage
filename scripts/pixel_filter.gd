class_name PixelFilter
extends CanvasLayer
## Graphics > Pixel filter: draws the 3D view in big square pixels.
##
## A CanvasLayer's `layer` sets its draw order among 2D layers. At -100 it's
## drawn before every other one, so its screen texture is just the rendered 3D
## world, and the HUD (layer 0 and up) lands crisp on top.
##
## Menus get the look too, all but their text: while a menu button is on
## screen, a second copy of the filter is drawn into that menu's own canvas
## layer at z_index FILTER_Z, so it pixelates the menu and everything under it.
## Text sits at UiStyle.TEXT_Z, higher still, so it's drawn after the filter
## and stays crisp. Running the filter over the already-filtered 3D changes
## nothing (same grid, colours already on their shades).
##
## Lives under the Game autoload so it survives scene changes.

## Above every panel and picture in a menu, below its text (UiStyle.TEXT_Z).
const FILTER_Z: int = 1000

var _rect: ColorRect
var _material: ShaderMaterial
## The menu copy is a bare RenderingServer canvas item rather than a node, so it
## can be hung under whichever layer the open menu is in without becoming a
## child of (and being freed with) that menu's nodes.
var _menu_item: RID
var _menu_canvas: RID


func _init() -> void:
	layer = -100
	# Keeps checking for menus while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/pixel_filter.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)

	_menu_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_material(_menu_item, _material.get_rid())
	RenderingServer.canvas_item_set_z_index(_menu_item, FILTER_Z)
	# Far bigger than any screen: the shader works in screen pixels, so the
	# rect only has to cover it.
	RenderingServer.canvas_item_add_rect(_menu_item, Rect2(-20000, -20000, 40000, 40000), Color.WHITE)
	RenderingServer.canvas_item_set_visible(_menu_item, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		RenderingServer.free_rid(_menu_item)


func _process(_delta: float) -> void:
	var canvas := RID()
	if visible:
		for panel: Control in get_tree().get_nodes_in_group("menu_panels"):
			if panel.is_visible_in_tree():
				# The panel's own layer, or the main canvas if it has none.
				var menu_layer: CanvasLayer = panel.get_canvas_layer_node()
				canvas = menu_layer.get_canvas() if menu_layer else panel.get_world_2d().canvas
				break
	if canvas != _menu_canvas:
		_menu_canvas = canvas
		RenderingServer.canvas_item_set_parent(_menu_item, canvas)
	RenderingServer.canvas_item_set_visible(_menu_item, canvas.is_valid())


## `rows` is how many chunky pixels tall the screen is.
func set_rows(rows: float) -> void:
	_material.set_shader_parameter("target_rows", rows)
