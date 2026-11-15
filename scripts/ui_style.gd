class_name UiStyle
## The shared look of every menu and the HUD: palette, font, glass text.
##
## Everything here is `static`, like Tones: call UiStyle.font() without making
## an object. It owns look only — no layout, no behaviour.
##
## The style is glass words: chunky Coiny letters drawn as marbles
## (shaders/marble_text.gdshader) floating over the scene, with no panels or
## boxes behind them, and a soft chime on every action.

# --- Palette -----------------------------------------------------------------
# Cream glass on deep teal, with amber and mint accents. Deliberately the
# same family as the game's rooms (cream walls, brown floor, green side room)
# so the menus and the game look like one thing.

## Text is drawn at this z_index, above everything else in a menu.
const TEXT_Z: int = 2000

## The night shade behind the title menu, over the 3D room.
const SHADE := Color(0.02, 0.03, 0.06)
## Dark text (the creatures' eyes use it too).
const INK := Color(0.12, 0.14, 0.15)
const INK_SOFT := Color(0.42, 0.44, 0.44)
## Text on the dark background.
const CREAM := Color(0.95, 0.92, 0.84)
const CREAM_SOFT := Color(0.95, 0.92, 0.84, 0.6)
## Accents: the crosshair's states and the title's blobs.
const AMBER := Color(0.98, 0.62, 0.17)
const MINT := Color(0.33, 0.80, 0.62)
const CORAL := Color(0.96, 0.45, 0.42)
const SKY := Color(0.40, 0.70, 0.93)
const ACCENTS: Array[Color] = [AMBER, MINT, SKY, CORAL]

# --- Sizes -------------------------------------------------------------------
# The viewport is 2560x1440 with canvas_items stretch, so these are in that
# space and scale with the window.

const TITLE_FONT_SIZE: int = 150
const ROW_FONT_SIZE: int = 48
const HINT_FONT_SIZE: int = 30

static var _fonts: Dictionary = {}
static var _title_shade: GradientTexture2D = null


## Coiny (fonts/, SIL Open Font License). It has a single heavy weight, so
## `weight` is kept for callers but no longer changes anything.
static func font(_weight: int = 700) -> Font:
	if _fonts.has("coiny"):
		return _fonts["coiny"]
	var f: Font = load("res://fonts/Coiny-Regular.ttf")
	_fonts["coiny"] = f
	return f


## Darkens the left of the title screen, where the menu sits, and clears
## toward the right so the room shows through.
static func title_shade() -> GradientTexture2D:
	if _title_shade != null:
		return _title_shade
	var ramp := Gradient.new()
	ramp.set_color(0, Color(SHADE, 0.78))
	ramp.set_color(1, Color(SHADE, 0.0))
	ramp.add_point(0.38, Color(SHADE, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.width = 256
	tex.height = 8
	tex.fill_to = Vector2(0.75, 0.0)
	_title_shade = tex
	return tex


## The outline of a rounded rectangle, as points going clockwise from the top
## right. `per_corner` segments per corner: 8 is smooth at any size we use.
static func rounded_points(rect: Rect2, radius: float, per_corner: int = 8) -> PackedVector2Array:
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var right: float = rect.position.x + rect.size.x
	var bottom: float = rect.position.y + rect.size.y
	# Each corner: its centre of curvature, and the angles to sweep between.
	var corners: Array = [
		[Vector2(right - radius, rect.position.y + radius), -PI * 0.5, 0.0],
		[Vector2(right - radius, bottom - radius), 0.0, PI * 0.5],
		[Vector2(rect.position.x + radius, bottom - radius), PI * 0.5, PI],
		[Vector2(rect.position.x + radius, rect.position.y + radius), PI, PI * 1.5],
	]
	var points := PackedVector2Array()
	for corner: Array in corners:
		for i in per_corner + 1:
			var angle: float = lerpf(corner[1], corner[2], float(i) / per_corner)
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * radius)
	return points


## One colour per point, interpolated by how far down `span` each point sits.
## This is what turns a flat polygon into a lit surface.
static func vertical_ramp(points: PackedVector2Array, span: Rect2, top: Color, bottom: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	for p in points:
		colors.append(top.lerp(bottom, clampf((p.y - span.position.y) / maxf(span.size.y, 1.0), 0.0, 1.0)))
	return colors


## A label, pre-styled. Used instead of setting the same four overrides by hand
## everywhere.
static func label(text: String, size: int, color: Color, weight: int = 700) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = TEXT_Z
	marble_label(l)
	return l


# --- Marble text ---------------------------------------------------------------

## How tall Coiny's capitals are, as a share of the font size.
const CAP_HEIGHT: float = 0.70
const MARBLE_SHADER: Shader = preload("res://shaders/marble_text.gdshader")


## Gives a canvas item the glassy marble text shader. Each item gets its own
## material because the shader needs to know where that item's line of text is.
static func marble(item: CanvasItem) -> void:
	var m := ShaderMaterial.new()
	m.shader = MARBLE_SHADER
	item.material = m


## How fast headings' swirls drift, in radians per second: slower than a
## pointed-at menu word, so the words you can click still stand out.
const HEADING_DRIFT: float = 0.25


## Makes a marble label a title: swirls inside, drifting slowly and forever.
## Other marble text has no swirls.
static func set_marble_drift(item: CanvasItem, speed: float = HEADING_DRIFT) -> void:
	var m := item.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("swirls", 1.0)
	m.set_shader_parameter("drift", 0.0)
	var flow := MarbleFlow.new()
	flow.material = m
	flow.speed = speed
	item.add_child(flow)


## Adds to a heading's swirl drift every frame. Kept here rather than as TIME
## in the shader, because TIME jumps back to 0 every hour. PROCESS_MODE_ALWAYS
## so the pause menu's heading keeps flowing while the game is paused.
class MarbleFlow extends Node:
	var material: ShaderMaterial
	var speed: float = 0.0
	var drift: float = 0.0

	func _init() -> void:
		name = "MarbleFlow"
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		drift += delta * speed
		material.set_shader_parameter("drift", drift)


## Tells the marble shader where a line of text sits in the item's own pixels.
static func set_marble_line(item: CanvasItem, baseline: float, font_size: int) -> void:
	var m := item.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("baseline", baseline)
	m.set_shader_parameter("cap_top", baseline - font_size * CAP_HEIGHT)
	# Small text gets less swirl and no sparkle: full detail from about 66 px.
	m.set_shader_parameter("detail", clampf((font_size - 36.0) / 30.0, 0.0, 1.0))


## Makes `tint` a marble's main swirl colour; the blue and teal swirls stay.
## Without this the main swirl is pink.
static func set_marble_tint(item: CanvasItem, tint: Color) -> void:
	var m := item.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("swirl_color", tint)


## Marble text for a one-line Label, kept lined up whenever it resizes.
static func marble_label(l: Label) -> void:
	marble(l)
	var place := func() -> void:
		var fs: int = l.get_theme_font_size("font_size")
		var f: Font = l.get_theme_font("font")
		var h: float = f.get_height(fs)
		var top: float = 0.0
		match l.vertical_alignment:
			VERTICAL_ALIGNMENT_CENTER:
				top = (l.size.y - h) * 0.5
			VERTICAL_ALIGNMENT_BOTTOM:
				top = l.size.y - h
		set_marble_line(l, top + f.get_ascent(fs), fs)
	l.resized.connect(place)
	place.call()
