class_name PointerCursor
extends Node
## Replaces the mouse arrow with a chunky pointing hand, in the same style as
## the menus: cream with a dark outline, a glossy shine and an amber cuff.
##
## It's drawn once, at startup, the same way as everything else (shapes in
## code, no image files), into an off-screen SubViewport. That render is read
## back as an Image and handed to the OS as the hardware cursor, so it moves
## exactly as smoothly as the normal arrow. During play the cursor is
## captured and hidden anyway, so in practice it's only seen in menus.
##
## The Game autoload adds one of these when the game starts.

## Size of the cursor on screen, in pixels. The hand is drawn at twice this and
## scaled down, which smooths its edges.
const CURSOR_SIZE: int = 64
const DRAW_SCALE: int = 2
## The tip of the pointing finger, which is where clicks land, in the
## CURSOR_SIZE frame.
const HOTSPOT := Vector2(25.0, 3.0)

const OUTLINE := Color(0.10, 0.11, 0.12)
const SKIN_TOP := Color(1.0, 0.99, 0.96)
const SKIN_BOTTOM := Color(0.86, 0.85, 0.82)

## The finished cursor, kept so tests/shoot.gd can save a picture of it.
static var image: Image = null

var _viewport: SubViewport


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(CURSOR_SIZE * DRAW_SCALE, CURSOR_SIZE * DRAW_SCALE)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Node2D.new()
	canvas.scale = Vector2(DRAW_SCALE, DRAW_SCALE)
	canvas.draw.connect(_draw_hand.bind(canvas))
	_viewport.add_child(canvas)
	add_child(_viewport)
	_install.call_deferred()


func _install() -> void:
	# Wait until the viewport has actually been drawn once.
	await RenderingServer.frame_post_draw
	var drawn: Image = _viewport.get_texture().get_image()
	_viewport.queue_free()
	# A headless run has no real renderer, so there's nothing to read back.
	if drawn == null or drawn.is_empty():
		return
	drawn.resize(CURSOR_SIZE, CURSOR_SIZE, Image.INTERPOLATE_LANCZOS)
	image = drawn
	var texture := ImageTexture.create_from_image(drawn)
	# The plain arrow and the "you can click this" cursor are both the hand.
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, HOTSPOT)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_POINTING_HAND, HOTSPOT)


## Hand the normal arrow back on quit, so the cursor texture isn't still held
## when the renderer shuts down (Godot reports that as a leak).
func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)


## The hand, in a 64x64 frame, pointing up. Every part is drawn twice: once
## slightly fattened in the outline colour, then normally in the skin colour
## on top. Overlapping parts merge, so the outline runs round the whole hand
## rather than round each finger.
func _draw_hand(c: Node2D) -> void:
	var parts: Array[Rect2] = [
		Rect2(19.0, 1.5, 12.0, 34.0),   # pointing finger
		Rect2(30.0, 21.0, 9.0, 18.0),   # middle finger, curled
		Rect2(38.0, 23.0, 8.5, 17.0),   # ring finger, curled
		Rect2(45.5, 26.0, 7.5, 15.0),   # little finger, curled
		Rect2(15.0, 28.0, 37.0, 24.0),  # palm
	]
	var radii: Array[float] = [6.0, 4.5, 4.25, 3.75, 10.0]
	var thumb := [Vector2(14.0, 38.0), Vector2(8.5, 5.5), -0.75]  # centre, radii, angle
	var cuff := Rect2(16.0, 50.0, 35.0, 11.0)
	const OUTLINE_WIDTH: float = 2.6

	# 1. Outline: every part fattened, in dark.
	for i in parts.size():
		c.draw_colored_polygon(
			UiStyle.rounded_points(parts[i].grow(OUTLINE_WIDTH), radii[i] + OUTLINE_WIDTH), OUTLINE)
	c.draw_colored_polygon(_ellipse(thumb[0], thumb[1] + Vector2.ONE * OUTLINE_WIDTH, thumb[2]), OUTLINE)
	c.draw_colored_polygon(UiStyle.rounded_points(cuff.grow(OUTLINE_WIDTH), 4.0 + OUTLINE_WIDTH), OUTLINE)

	# 2. Skin: lit from the top, like the panels.
	var span := Rect2(0.0, 0.0, 64.0, 54.0)
	for i in parts.size():
		var shape: PackedVector2Array = UiStyle.rounded_points(parts[i], radii[i])
		c.draw_polygon(shape, UiStyle.vertical_ramp(shape, span, SKIN_TOP, SKIN_BOTTOM))
	var thumb_shape: PackedVector2Array = _ellipse(thumb[0], thumb[1], thumb[2])
	c.draw_polygon(thumb_shape, UiStyle.vertical_ramp(thumb_shape, span, SKIN_TOP, SKIN_BOTTOM))

	# 3. Creases between the curled fingers, and where they meet the palm.
	for x: float in [30.0, 38.0, 45.5]:
		c.draw_line(Vector2(x, 25.0), Vector2(x, 34.0), Color(OUTLINE, 0.55), 1.6, true)
	c.draw_line(Vector2(31.0, 34.5), Vector2(50.0, 36.0), Color(OUTLINE, 0.3), 1.4, true)

	# 4. Cuff, in the menus' amber, with its own little shine.
	var cuff_shape: PackedVector2Array = UiStyle.rounded_points(cuff, 4.0)
	c.draw_polygon(cuff_shape, UiStyle.vertical_ramp(cuff_shape, cuff,
		UiStyle.AMBER.lightened(0.25), UiStyle.AMBER.darkened(0.1)))
	c.draw_line(cuff.position + Vector2(4.0, 3.0), cuff.position + Vector2(cuff.size.x - 4.0, 3.0),
		Color(1.0, 1.0, 1.0, 0.55), 2.0, true)

	# 5. Gloss down the pointing finger and across the top of the palm.
	c.draw_colored_polygon(UiStyle.rounded_points(Rect2(21.5, 4.5, 3.5, 22.0), 1.75),
		Color(1.0, 1.0, 1.0, 0.85))
	c.draw_colored_polygon(UiStyle.rounded_points(Rect2(33.0, 23.5, 3.0, 7.0), 1.5),
		Color(1.0, 1.0, 1.0, 0.6))


## An ellipse as points, turned by `angle` radians about its centre.
func _ellipse(centre: Vector2, radii: Vector2, angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 24:
		var a: float = TAU * i / 24.0
		points.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(angle))
	return points
