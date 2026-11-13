class_name MenuPanel
extends BaseButton
## One big panel you point at and click: the only kind of button the menus use.
##
## BaseButton is a button with no look of its own (unlike Button), so the whole
## panel is drawn here in _draw: shadow, cream face, a coloured bar along the
## top, the icon and the label. Pointing at it (or giving it keyboard focus)
## raises it; clicking presses it back down. Both are animated by easing
## `_lift` and `_sink` toward their targets every frame rather than with
## tweens, so interrupting one mid-animation can't leave it half-finished.

## Shown in the coloured bar's colour, above the label.
@export var icon_name: String = ""
## A character drawn instead of an icon, for the small +/- steppers.
@export var glyph: String = ""
@export var label_text: String = ""
## The bar along the top and the icon colour.
@export var accent: Color = UiStyle.AMBER
## Compact panels (the steppers) have no top bar and a tighter radius.
@export var compact: bool = false

var _lift: float = 0.0
var _sink: float = 0.0
var _voice: AudioStreamPlayer


## The sounds are wired up in _init rather than _ready so that the chime is the
## first thing connected to `pressed`, and so plays before whatever the panel
## does. That matters for Restart and Title, which tear down the scene this
## panel lives in: by the time the next handler returns, there's nothing left
## to play the sound from.
func _init() -> void:
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	mouse_entered.connect(_play_hover)
	focus_entered.connect(_play_hover)
	pressed.connect(_play_select)


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
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
	var raised: bool = is_hovered() or has_focus()
	var target_lift: float = UiStyle.LIFT if raised else 0.0
	var target_sink: float = 1.0 if button_pressed else 0.0
	_lift = lerpf(_lift, target_lift, clampf(delta * 16.0, 0.0, 1.0))
	_sink = lerpf(_sink, target_sink, clampf(delta * 22.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var radius: int = 22 if compact else UiStyle.PANEL_RADIUS
	var raised: bool = is_hovered() or has_focus()
	var face: Color = UiStyle.PANEL_HOVER if raised else UiStyle.PANEL
	# The panel is drawn higher than its layout rect when raised, and squashed
	# down by a couple of pixels while held.
	var offset := Vector2(0.0, -_lift + _sink * 5.0)
	var rect := Rect2(offset, size)

	UiStyle.panel_box(face, radius, 10.0 + _lift * 1.6).draw(get_canvas_item(), rect)

	if has_focus():
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color.TRANSPARENT
		ring.set_corner_radius_all(radius + 8)
		ring.set_border_width_all(6)
		ring.border_color = accent
		ring.draw(get_canvas_item(), rect.grow(10.0))

	if not compact:
		# The accent bar: a full rounded rect clipped to the panel's top edge by
		# drawing it taller than the visible strip and letting the panel's own
		# corners define the shape.
		var bar := UiStyle.panel_box(accent, radius, 0.0)
		bar.draw(get_canvas_item(), Rect2(rect.position, Vector2(size.x, 14.0 + radius)))
		UiStyle.panel_box(face, radius, 0.0).draw(get_canvas_item(),
			Rect2(rect.position + Vector2(0.0, 14.0), size - Vector2(0.0, 14.0)))

	var font: Font = UiStyle.font(700)

	if glyph != "":
		var glyph_size: int = int(size.y * 0.5)
		var glyph_width: float = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
		draw_string(font, rect.position + Vector2((size.x - glyph_width) * 0.5, size.y * 0.68),
			glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, UiStyle.INK)
		return

	if icon_name != "":
		var box: float = size.y * 0.34
		UiStyle.draw_icon(self, icon_name,
			Rect2(rect.position + Vector2((size.x - box) * 0.5, size.y * 0.24),
				Vector2(box, box)), accent)

	if label_text != "":
		var label_size: int = UiStyle.LABEL_FONT_SIZE
		var text_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		draw_string(font, rect.position + Vector2((size.x - text_width) * 0.5, size.y * 0.82),
			label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, UiStyle.INK)


## Builds a panel in one call, instead of five lines of property setting.
static func make(icon: String, text: String, tint: Color) -> MenuPanel:
	var panel := MenuPanel.new()
	panel.icon_name = icon
	panel.label_text = text
	panel.accent = tint
	return panel


## A small square stepper button showing a single character.
static func make_stepper(character: String) -> MenuPanel:
	var panel := MenuPanel.new()
	panel.glyph = character
	panel.compact = true
	panel.custom_minimum_size = Vector2(110.0, 110.0)
	return panel
