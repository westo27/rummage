class_name MenuPanel
extends BaseButton
## One big glossy panel you point at and click: the only kind of button the
## menus use.
##
## BaseButton is a button with no look of its own (unlike Button), so the whole
## thing is drawn here in _draw, via UiStyle.draw_glossy_panel, which does the
## shadow, the lit body, the rim, the bevel and the gloss.
##
## Mouse only: pointing at it raises it, clicking pushes it in. Panels never
## take keyboard focus, so nothing is pre-selected when a menu opens and the
## arrow keys don't move a selection around.
##
## Both are animated by easing `_lift` and `_sink` toward their targets every
## frame rather than with tweens, so interrupting one mid-animation
## can't leave it half-finished. Those same values drive how strong the gloss
## and the shadow are, so the panel looks like it's tilting into the light
## rather than just sliding up and down.

## Shown above the label, drawn in the accent colour.
@export var icon_name: String = ""
## A character drawn instead of an icon, for the small +/- steppers.
@export var glyph: String = ""
@export var label_text: String = ""
## The rim and the icon.
@export var accent: Color = UiStyle.AMBER
## Compact panels (the steppers) are drawn as circles or near-circles.
@export var compact: bool = false

var _lift: float = 0.0
var _sink: float = 0.0
var _voice: AudioStreamPlayer
## The label and glyph are drawn on this child, at UiStyle.TEXT_Z, so they sit
## above the menus' pixel filter and stay crisp. The panel itself is drawn
## below it.
var _text: Control


## The sounds are wired up in _init rather than _ready so that the chime is the
## first thing connected to `pressed`, and so plays before whatever the panel
## does. That matters for Restart and Title, which tear down the scene this
## panel lives in: by the time the next handler returns, there's nothing left
## to play the sound from.
func _init() -> void:
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	mouse_entered.connect(_play_hover)
	pressed.connect(_play_select)
	_text = Control.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.z_index = UiStyle.TEXT_Z
	UiStyle.marble(_text)
	_text.draw.connect(_draw_text)
	add_child(_text)


func _ready() -> void:
	# FOCUS_NONE: the panel can't hold keyboard focus, so Godot's built-in
	# arrow-key and Tab navigation between buttons never applies to it.
	focus_mode = Control.FOCUS_NONE
	# Lets the pixel filter tell when a menu is on screen (PixelFilter).
	add_to_group("menu_panels")
	if custom_minimum_size == Vector2.ZERO:  # not already set by the caller
		custom_minimum_size = UiStyle.PANEL_SIZE_SMALL if compact else UiStyle.PANEL_SIZE


func _play_hover() -> void:
	_play(Tones.ui_hover())


func _play_select() -> void:
	_play(Tones.ui_select())


func _play(stream: AudioStream) -> void:
	# A panel that replaces the scene takes its own speaker with it.
	if not is_inside_tree():
		return
	_voice.stream = stream
	_voice.play()


func _process(delta: float) -> void:
	# Ease each value a fixed fraction of the way to its target per second.
	_lift = lerpf(_lift, 1.0 if is_hovered() else 0.0, clampf(delta * 14.0, 0.0, 1.0))
	_sink = lerpf(_sink, 1.0 if button_pressed else 0.0, clampf(delta * 22.0, 0.0, 1.0))
	queue_redraw()
	_text.queue_redraw()


func _draw() -> void:
	# Anything much wider than it is tall is drawn as a pill, with the icon
	# tucked in at the left and the label across the middle. Steppers are
	# circles. Anything else is a gumdrop: a square rounded by a good fraction
	# of its own height, rather than by a fixed number of pixels.
	var pill: bool = size.x > size.y * 2.0
	var radius: float = size.y * 0.5 if (compact or pill) \
		else minf(size.x, size.y) * UiStyle.PANEL_ROUNDNESS
	# The panel is drawn above its layout rect when raised, and pushed back
	# down into the page while held.
	var rect := Rect2(Vector2(0.0, -UiStyle.LIFT * _lift + 6.0 * _sink), size)
	UiStyle.draw_glossy_panel(self, rect, radius, accent, _lift, _sink)
	if icon_name != "":
		var icon_rect := _icon_rect()
		UiStyle.draw_icon(self, icon_name, Rect2(rect.position + icon_rect.position, icon_rect.size), accent)


## Where the icon goes, before the panel's lift and sink are added.
func _icon_rect() -> Rect2:
	var pill: bool = size.x > size.y * 2.0
	var box: float = size.y * (0.56 if pill else 0.34)
	var at := Vector2(size.y * 0.34, (size.y - box) * 0.5) if pill \
		else Vector2((size.x - box) * 0.5, size.y * 0.22)
	return Rect2(at, Vector2(box, box))


func _draw_text() -> void:
	var pill: bool = size.x > size.y * 2.0
	var offset := Vector2(0.0, -UiStyle.LIFT * _lift + 6.0 * _sink)
	var font: Font = UiStyle.font(700)

	if glyph != "":
		var glyph_size: int = int(size.y * 0.46)
		var measured: Vector2 = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size)
		_draw_engraved(font, offset + Vector2((size.x - measured.x) * 0.5, size.y * 0.66),
			glyph, glyph_size)
		return

	if label_text != "":
		# Where the icon ends, so a pill's label can keep clear of it.
		var icon_right: float = _icon_rect().end.x if icon_name != "" else 0.0
		var label_size: int = UiStyle.PILL_FONT_SIZE if pill else UiStyle.LABEL_FONT_SIZE
		var width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		var baseline: float = size.y * (0.64 if pill else 0.82)
		# Centred, unless that would run into the icon on a short pill.
		var x: float = (size.x - width) * 0.5
		if pill and icon_right > 0.0:
			x = maxf(x, icon_right + size.y * 0.22)
		_draw_engraved(font, offset + Vector2(x, baseline), label_text, label_size)


## Text with a pale copy a little below it. Light comes from above, so a
## highlight along the lower edge reads as the letters being cut into the
## surface. It's a small thing that stops the type looking stuck on top.
func _draw_engraved(font: Font, at: Vector2, text: String, font_size: int) -> void:
	UiStyle.set_marble_line(_text, at.y, font_size)
	UiStyle.set_marble_tint(_text, accent)
	_text.draw_string(font, at + Vector2(0.0, 2.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(1.0, 1.0, 1.0, 0.6))
	_text.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiStyle.INK)


## Builds a panel in one call, instead of five lines of property setting.
static func make(icon: String, text: String, tint: Color) -> MenuPanel:
	var panel := MenuPanel.new()
	panel.icon_name = icon
	panel.label_text = text
	panel.accent = tint
	return panel


## A wide pill: icon at the left, label across the middle.
static func make_pill(icon: String, text: String, tint: Color) -> MenuPanel:
	var panel := make(icon, text, tint)
	panel.custom_minimum_size = UiStyle.PILL_SIZE
	return panel


## A small round stepper button showing a single character.
static func make_stepper(character: String) -> MenuPanel:
	var panel := MenuPanel.new()
	panel.glyph = character
	panel.compact = true
	panel.accent = UiStyle.SKY
	panel.custom_minimum_size = Vector2(118.0, 118.0)
	return panel
