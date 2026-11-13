class_name UiStyle
## The shared look of every menu: palette, fonts, panel shapes, icons.
##
## Everything here is `static`, like Tones: call UiStyle.font() without making
## an object. It owns look only — no layout, no behaviour.
##
## The style is "console dashboard": big rounded panels you aim at rather than
## small widgets, chunky text, one bright accent per panel, a soft chime on
## every action. Icons are drawn from circles, rectangles and triangles in
## code, to match the primitive meshes the game itself is built from.

# --- Palette -----------------------------------------------------------------
# Warm cream panels on deep teal, with amber and mint accents. Deliberately
# the same family as the game's rooms (cream walls, brown floor, green side
# room) so the menus and the game look like one thing.

const BG_TOP := Color(0.10, 0.20, 0.22)
const BG_BOTTOM := Color(0.04, 0.07, 0.10)
## Panel face, and the brighter version used when hovered.
const PANEL := Color(0.96, 0.93, 0.85)
const PANEL_HOVER := Color(1.0, 0.99, 0.94)
## Text on a cream panel.
const INK := Color(0.12, 0.14, 0.15)
const INK_SOFT := Color(0.42, 0.44, 0.44)
## Text on the dark background.
const CREAM := Color(0.95, 0.92, 0.84)
const CREAM_SOFT := Color(0.95, 0.92, 0.84, 0.6)
## Accents, one per panel, cycled in order.
const AMBER := Color(0.98, 0.62, 0.17)
const MINT := Color(0.33, 0.80, 0.62)
const CORAL := Color(0.96, 0.45, 0.42)
const SKY := Color(0.40, 0.70, 0.93)
const ACCENTS: Array[Color] = [AMBER, MINT, SKY, CORAL]

# --- Sizes -------------------------------------------------------------------
# The viewport is 2560x1440 with canvas_items stretch, so these are in that
# space and scale with the window.

const PANEL_SIZE := Vector2(420.0, 400.0)
const PANEL_SIZE_SMALL := Vector2(300.0, 290.0)
const PANEL_RADIUS: int = 30
## How far a panel rises when you point at it.
const LIFT: float = 14.0
const TITLE_FONT_SIZE: int = 150
const SUBTITLE_FONT_SIZE: int = 44
const LABEL_FONT_SIZE: int = 46
const ROW_FONT_SIZE: int = 48
const HINT_FONT_SIZE: int = 30

static var _fonts: Dictionary = {}
static var _gradient: GradientTexture2D = null


## A system font at the given weight (700 = bold). SystemFont asks the OS for a
## font by family name instead of shipping a font file, so the project still
## has no imported assets. If none of the names exist, Godot falls back to its
## own built-in font.
static func font(weight: int = 700) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Segoe UI Variable Display", "Segoe UI", "Inter", "Helvetica Neue",
		"DejaVu Sans", "Arial",
	])
	f.font_weight = weight
	_fonts[weight] = f
	return f


## The background wash, dark teal at the top fading to near-black at the bottom.
static func gradient() -> GradientTexture2D:
	if _gradient != null:
		return _gradient
	var ramp := Gradient.new()
	ramp.set_color(0, BG_TOP)
	ramp.set_color(1, BG_BOTTOM)
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.width = 8
	tex.height = 256
	# Straight down, rather than the default left-to-right.
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	_gradient = tex
	return tex


## A rounded panel face. `shadow` adds the soft drop shadow that makes a
## hovered panel look lifted off the background.
static func panel_box(bg: Color, radius: int = PANEL_RADIUS, shadow: float = 0.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.corner_detail = 12
	if shadow > 0.0:
		box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		box.shadow_size = int(shadow)
		box.shadow_offset = Vector2(0.0, shadow * 0.45)
	return box


## The darker inset plate a setting's current value sits on.
static func plate_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.25)
	box.set_corner_radius_all(18)
	box.corner_detail = 8
	box.content_margin_left = 28.0
	box.content_margin_right = 28.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	return box


## A label, pre-styled. Used instead of setting the same four overrides by hand
## everywhere.
static func label(text: String, size: int, color: Color, weight: int = 700) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- Icons -------------------------------------------------------------------

## Draws a named icon inside `rect` on any canvas item. Shapes only: the same
## vocabulary as the game's meshes.
static func draw_icon(ci: CanvasItem, icon: String, rect: Rect2, color: Color) -> void:
	var w: float = rect.size.x
	match icon:
		"creature":
			# A blob with two eyes and a beam curving in from the top left.
			var body: Vector2 = _at(rect, 0.52, 0.62)
			var r: float = w * 0.26
			ci.draw_circle(body, r, color)
			ci.draw_circle(body + Vector2(-r * 0.38, -r * 0.3), r * 0.26, PANEL)
			ci.draw_circle(body + Vector2(r * 0.38, -r * 0.3), r * 0.26, PANEL)
			for i in 3:
				var t: float = 0.18 + i * 0.1
				ci.draw_line(_at(rect, t, t * 0.9), _at(rect, t + 0.07, t * 0.9 + 0.06),
					Color(color, 0.35 + i * 0.2), w * 0.055, true)
		"sliders":
			for i in 3:
				var y: float = 0.28 + i * 0.22
				ci.draw_line(_at(rect, 0.12, y), _at(rect, 0.88, y),
					Color(color, 0.35), w * 0.07, true)
				ci.draw_circle(_at(rect, [0.70, 0.34, 0.56][i], y), w * 0.1, color)
		"exit":
			# A doorway open on the right, with an arrow leaving through it.
			var frame := Rect2(_at(rect, 0.1, 0.12), Vector2(w * 0.46, rect.size.y * 0.76))
			ci.draw_rect(frame, color, false, w * 0.08)
			ci.draw_line(_at(rect, 0.44, 0.5), _at(rect, 0.84, 0.5), color, w * 0.08, true)
			ci.draw_colored_polygon(PackedVector2Array([
				_at(rect, 0.72, 0.32), _at(rect, 0.95, 0.5), _at(rect, 0.72, 0.68)]), color)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([
				_at(rect, 0.26, 0.14), _at(rect, 0.88, 0.5), _at(rect, 0.26, 0.86)]), color)
		"loop":
			# An almost-closed circle with an arrowhead on the open end.
			var centre: Vector2 = _at(rect, 0.5, 0.52)
			var radius: float = w * 0.33
			ci.draw_arc(centre, radius, deg_to_rad(-55.0), deg_to_rad(245.0), 48, color, w * 0.1, true)
			var tip: Vector2 = centre + Vector2(radius, 0.0).rotated(deg_to_rad(-55.0))
			ci.draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-w * 0.14, -w * 0.02), tip + Vector2(w * 0.08, -w * 0.12),
				tip + Vector2(w * 0.1, w * 0.1)]), color)
		"house":
			ci.draw_colored_polygon(PackedVector2Array([
				_at(rect, 0.5, 0.12), _at(rect, 0.94, 0.5), _at(rect, 0.06, 0.5)]), color)
			ci.draw_rect(Rect2(_at(rect, 0.2, 0.5), Vector2(w * 0.6, rect.size.y * 0.38)), color)
		"back":
			ci.draw_line(_at(rect, 0.9, 0.5), _at(rect, 0.26, 0.5), color, w * 0.09, true)
			ci.draw_colored_polygon(PackedVector2Array([
				_at(rect, 0.34, 0.26), _at(rect, 0.34, 0.74), _at(rect, 0.08, 0.5)]), color)


## A point inside `rect` given as fractions of its width and height.
static func _at(rect: Rect2, x: float, y: float) -> Vector2:
	return rect.position + Vector2(rect.size.x * x, rect.size.y * y)
