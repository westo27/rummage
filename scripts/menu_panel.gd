class_name MenuPanel
extends BaseButton
## A clickable glass word: the only kind of button the menus use. No panel,
## just the words in marble text, which grow and start their swirls drifting
## when pointed at, and chime.
##
## BaseButton is a button with no look of its own (unlike Button), so the
## words are drawn here, on a child at UiStyle.TEXT_Z.
##
## Mouse only: words never take keyboard focus, so nothing is pre-selected
## when a menu opens and the arrow keys don't move a selection around.
##
## Pointing and pressing are animated by easing `_lift` and `_sink` toward
## their targets every frame rather than with tweens, so interrupting one
## mid-animation can't leave it half-finished.

@export var label_text: String = ""
## A single character drawn instead of words, for the settings' − and +.
@export var glyph: String = ""

## Font size of the words at rest; they grow by BARE_GROW when pointed at.
const BARE_FONT_SIZE: int = 112
const BARE_GROW: float = 0.12
## How fast pointed-at words' swirls drift, in radians per second.
## Slow on purpose: a lazy flow rather than a spin.
const DRIFT_SPEED: float = 0.7

## How far the swirls have drifted. Added up a frame at a time (rather than
## TIME * speed in the shader) so easing the speed in and out never makes
## them jump.
var _drift: float = 0.0
## The words' font size at rest (they're drawn this much bigger, grown).
var bare_font_size: int = BARE_FONT_SIZE

var _lift: float = 0.0
var _sink: float = 0.0
var _voice: AudioStreamPlayer
## The words are drawn on this child, at UiStyle.TEXT_Z, so they sit above
## the menus' pixel filter and stay crisp.
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
	_text.queue_redraw()
	# Grow by scaling the whole text node, not by changing the font size:
	# the shader picks each letter's swirls from where the letter sits in
	# the node's own pixels, and a new font size moves every letter, which
	# made the swirls jump about. Drawn at the largest size and scaled
	# down, so it's never blurry.
	_text.size = size
	_text.pivot_offset = size * 0.5
	var grow: float = 1.0 + BARE_GROW * _lift - 0.05 * _sink
	_text.scale = Vector2.ONE * grow / (1.0 + BARE_GROW)
	_drift += delta * DRIFT_SPEED * _lift
	(_text.material as ShaderMaterial).set_shader_parameter("drift", _drift)


func _draw_text() -> void:
	var font: Font = UiStyle.font(700)
	var fs: int = roundi(bare_font_size * (1.0 + BARE_GROW))
	var words: String = label_text if label_text != "" else glyph
	var w: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# Words are centred on their capitals; − and + sit lower in the font,
	# around the middle of the lowercase letters, so they're centred there.
	var lift: float = UiStyle.CAP_HEIGHT * 0.5 if label_text != "" else 0.27
	var at := Vector2((size.x - w) * 0.5, size.y * 0.5 + fs * lift)
	UiStyle.set_marble_line(_text, at.y, fs)
	_text.draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.CREAM)


## Glass words. Sized to fit the words at their hovered size, so growing
## never spills past the click area.
static func make_text(text: String, font_size: int = BARE_FONT_SIZE) -> MenuPanel:
	var panel := MenuPanel.new()
	panel.label_text = text
	panel.bare_font_size = font_size
	var fs: int = roundi(font_size * (1.0 + BARE_GROW))
	var w: float = UiStyle.font(700).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	panel.custom_minimum_size = Vector2(w + 40.0, fs * 1.05)
	return panel


## A − or + for the settings rows: a fixed square, so both line up.
static func make_text_stepper(character: String) -> MenuPanel:
	var panel := MenuPanel.new()
	panel.glyph = character
	panel.bare_font_size = 104
	panel.custom_minimum_size = Vector2(110.0, 110.0)
	return panel
