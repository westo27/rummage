extends RefCounted
## The game's logo for press images: marble text over a solid cream fill, a
## heavy plum outline and a soft drop shadow, so it reads at thumbnail size.
## Two lines: a smaller "Losing My" over a big "Marbles!".
## Sizes are for "Marbles!" at `size`; everything else scales with it.

const FILL := Color(1.0, 0.86, 0.72)
const INK := Color(0.2, 0.06, 0.2)
const SHADE := Color(0.04, 0.01, 0.08, 0.55)
## As shares of the big line's font size.
const SMALL: float = 245.0 / 420.0
const LINE_GAP: float = 235.0 / 420.0
const OUTLINE: float = 44.0 / 420.0
const SHADOW_DROP: float = 18.0 / 420.0


## Adds the logo's labels to `parent`, centred across it, `top` pixels down.
static func build(parent: Node, size: int, top: int) -> void:
	_line(parent, "Losing My", roundi(size * SMALL), top, size)
	_line(parent, "Marbles!", size, top + roundi(size * LINE_GAP), size)


static func _line(parent: Node, text: String, size: int, top: int, big: int) -> void:
	var outline: int = roundi(size * OUTLINE)
	# The shadow sits a little lower than the logo itself.
	var drop: int = roundi(big * SHADOW_DROP)
	parent.add_child(_row(top + drop, [_text(text, size, SHADE, SHADE, outline + roundi(big / 30.0))]))
	# A MarginContainer stacks its children: fill and outline, then the marble.
	var marble := UiStyle.label(text, size, UiStyle.CREAM)
	marble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.set_marble_drift(marble)
	parent.add_child(_row(top, [_text(text, size, FILL, INK, outline), marble]))


static func _row(top: int, labels: Array) -> MarginContainer:
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.add_theme_constant_override("margin_top", top)
	for l: Label in labels:
		holder.add_child(l)
	return holder


static func _text(text: String, size: int, fill: Color, ink: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiStyle.font(700))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", fill)
	l.add_theme_color_override("font_outline_color", ink)
	l.add_theme_constant_override("outline_size", outline)
	return l
