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

## Text is drawn at this z_index so it lands above the menus' pixel filter
## (PixelFilter.FILTER_Z) and stays crisp.
const TEXT_Z: int = 2000

const BG_TOP := Color(0.10, 0.20, 0.22)
const BG_BOTTOM := Color(0.04, 0.07, 0.10)
## A panel's face is a vertical gradient, not one colour: bright along the top
## where the imaginary light is, falling to a shaded bottom. That gradient plus
## the gloss and the rim below is what makes the button look like an object
## rather than a rectangle.
const PANEL_TOP := Color(0.98, 0.98, 0.97)
const PANEL_BOTTOM := Color(0.63, 0.70, 0.74)
const PANEL_TOP_HOVER := Color(1.0, 1.0, 1.0)
const PANEL_BOTTOM_HOVER := Color(0.78, 0.85, 0.88)
## Kept for anything that just wants one flat cream, like the old win box.
const PANEL := Color(0.96, 0.93, 0.85)
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
## A wide pill: anything more than twice as wide as it is tall is drawn as one.
const PILL_SIZE := Vector2(880.0, 150.0)
const PILL_FONT_SIZE: int = 62
## Corner radius as a fraction of a panel's shorter side. Big: these are
## gumdrops, not cards.
const PANEL_ROUNDNESS: float = 0.30
## For the few places that still want a fixed radius in pixels.
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
static var _vignette: GradientTexture2D = null


## Coiny (fonts/, SIL Open Font License). It has a single heavy weight, so
## `weight` is kept for callers but no longer changes anything.
static func font(_weight: int = 700) -> Font:
	if _fonts.has("coiny"):
		return _fonts["coiny"]
	var f: Font = load("res://fonts/Coiny-Regular.ttf")
	_fonts["coiny"] = f
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


## A dark ring around the edge of the screen, clear in the middle. Drawn over
## the background so the menu sits in a pool of light instead of on a flat
## field, and so the panels have something to stand out against at the edges.
static func vignette() -> GradientTexture2D:
	if _vignette != null:
		return _vignette
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	ramp.set_color(1, Color(0.0, 0.01, 0.02, 0.55))
	# Most of the darkening happens in the outer third.
	ramp.add_point(0.55, Color(0.0, 0.0, 0.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_vignette = tex
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


# --- Glossy panels -----------------------------------------------------------
# A button is drawn in five passes, outermost first, the way a mid-2000s
# interface would have built it up in Photoshop:
#
#   1. a soft drop shadow, so it sits above the background
#   2. the body, a vertical gradient: lit along the top, shaded at the bottom
#   3. the rim, a bright stroke in the panel's accent colour
#   4. an inner light line just inside the rim, which reads as a bevel
#   5. the gloss, a white highlight over the top half, fading out downward
#
# Godot's StyleBoxFlat can't do gradients, so the body and the gloss are drawn
# as polygons with a colour per vertex (draw_polygon), which is cheap and
# gives a smooth ramp.

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


## Draws the whole button: shadow, body, rim, bevel and gloss.
## `hover` and `press` are 0..1, so a panel can be drawn part-way through
## rising or being pushed in.
static func draw_glossy_panel(ci: CanvasItem, rect: Rect2, radius: float, accent: Color,
		hover: float, press: float) -> void:
	var points: PackedVector2Array = rounded_points(rect, radius)
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])

	# 1. Shadow. A StyleBoxFlat is used only for its soft shadow; its own fill
	# is the panel's darkest tone and is covered by the body in the next step.
	var shade := StyleBoxFlat.new()
	shade.bg_color = PANEL_BOTTOM.darkened(0.1)
	shade.set_corner_radius_all(int(radius))
	shade.corner_detail = 12
	shade.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	shade.shadow_size = int(14.0 + hover * 16.0 - press * 8.0)
	shade.shadow_offset = Vector2(0.0, 8.0 + hover * 8.0 - press * 6.0)
	shade.draw(ci.get_canvas_item(), rect)

	# A glow in the accent colour while raised, drawn outside the rim.
	if hover > 0.01:
		ci.draw_polyline(closed, Color(accent, 0.28 * hover), 18.0, true)

	# 2. Body. Pressing it darkens the whole face a little, as if the light
	# no longer reaches it square-on.
	var top: Color = PANEL_TOP.lerp(PANEL_TOP_HOVER, hover).darkened(0.10 * press)
	var bottom: Color = PANEL_BOTTOM.lerp(PANEL_BOTTOM_HOVER, hover).darkened(0.10 * press)
	ci.draw_polygon(points, vertical_ramp(points, rect, top, bottom))

	# 3. Reflected light: a faint band along the bottom inside, as if the
	# surface picks up light bouncing off whatever it's sitting on. Kept weak
	# and low, so the shaded part of the face stays shaded.
	# Capped in height, so on a big card it stays a thin band along the bottom
	# instead of becoming a second box inside the first.
	var bounce_height: float = minf(rect.size.y * 0.24, 40.0)
	var bounce_rect := Rect2(
		rect.position + Vector2(rect.size.x * 0.08, rect.size.y - bounce_height - 7.0),
		Vector2(rect.size.x * 0.84, bounce_height))
	var bounce: PackedVector2Array = rounded_points(bounce_rect, minf(bounce_rect.size.y * 0.6, radius))
	ci.draw_polygon(bounce, vertical_ramp(bounce, bounce_rect,
		Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.22)))

	# 4. Gloss: a bright pill over the top of the face, white at its top edge
	# and gone by its bottom. A single polygon leaves a visible outline where
	# it ends, so it's drawn as several nested copies at low opacity. They
	# pile up toward the middle, which is a blurred highlight for free. It
	# shrinks when pressed, and that is most of why a press reads as the
	# surface tilting away from the light.
	# Every pass starts at the same top edge, so their alphas stack there and
	# the highlight is near-white where the light hits; they differ only in
	# width and in how far down they reach, which softens the fade-out.
	# Wider shapes get more passes, so the steps between them stay too small
	# to see as stripes. Each pass's opacity is chosen so that all of them
	# stacked add up to the same brightness whatever the count.
	var passes: int = clampi(int(rect.size.x / 50.0), 6, 18)
	var pass_alpha: float = 1.0 - pow(0.15, 1.0 / passes)
	var gloss_top: float = rect.position.y + 9.0
	var gloss_height: float = rect.size.y * (0.58 - 0.18 * press)
	for i in passes:
		# 1.0 for the widest and shortest, down to 0.62 for the narrowest.
		var spread: float = lerpf(1.0, 0.62, float(i) / (passes - 1))
		var inset: float = rect.size.x * (0.5 - 0.45 * spread)
		var gloss_rect := Rect2(
			Vector2(rect.position.x + inset, gloss_top),
			Vector2(rect.size.x - inset * 2.0, gloss_height * lerpf(0.72, 1.0, spread)))
		var gloss: PackedVector2Array = rounded_points(gloss_rect,
			minf(gloss_rect.size.y * 0.5, radius))
		ci.draw_polygon(gloss, vertical_ramp(gloss, gloss_rect,
			Color(1.0, 1.0, 1.0, pass_alpha * (1.0 - 0.35 * press)), Color(1.0, 1.0, 1.0, 0.0)))

	# 5. Rim, last so nothing paints over it, and a bevel line just inside it
	# so the edge looks rounded over rather than cut off.
	var inner_rect: Rect2 = rect.grow(-8.0)
	var inner: PackedVector2Array = rounded_points(inner_rect, maxf(radius - 8.0, 1.0))
	var inner_closed: PackedVector2Array = inner.duplicate()
	inner_closed.append(inner[0])
	ci.draw_polyline(inner_closed, Color(1.0, 1.0, 1.0, 0.4), 3.0, true)
	ci.draw_polyline(closed, accent, 7.0, true)


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


## Tells the marble shader where a line of text sits in the item's own pixels.
static func set_marble_line(item: CanvasItem, baseline: float, font_size: int) -> void:
	var m := item.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("baseline", baseline)
	m.set_shader_parameter("cap_top", baseline - font_size * CAP_HEIGHT)


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
