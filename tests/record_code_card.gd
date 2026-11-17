extends Control
## The opening card for the "changed one variable" post: a mock of Godot's
## script editor on creature.gd. The caret selects `false` on
## split_on_bump, types `true`, and saves. Drawn by hand in _draw, in the
## editor's default dark colours, so it records the same anywhere.
## Run in movie mode (tools/make_mitosis_post.sh does this, wide and tall):
##   Godot --path . --write-movie <out.avi> --fixed-fps 60
##     res://tests/record_code_card.tscn
## Prints "CLIP <first> <last>" like record_clip.gd.

const LENGTH: float = 2.6
const BG := Color("1d2229")
const BAR := Color("262c3b")
const GUTTER := Color("cdcfd2", 0.35)
const CURRENT_LINE := Color(1, 1, 1, 0.05)
const SELECTION := Color("5791ff", 0.45)
const KEYWORD := Color("ff7085")
const ANNOTATION := Color("ffb373")
const BASE_TYPE := Color("42ffc2")
const USER_TYPE := Color("c7ffed")
const TEXT := Color("cdcfd2")
const NUMBER := Color("a1ffe0")
const SYMBOL := Color("abc9ff")
const DOC := Color("99b3cc", 0.8)

## The script, as (text, colour) runs per line. Line 7 is the one that
## changes: its last run is the value.
var _lines: Array = [
	[["extends ", KEYWORD], ["CharacterBody3D", BASE_TYPE]],
	[["class_name ", KEYWORD], ["Creature", USER_TYPE]],
	[],
	[["## How fast it runs once you've spotted it, m/s.", DOC]],
	[["@export ", ANNOTATION], ["var ", KEYWORD], ["flee_speed", TEXT], [": ", SYMBOL],
		["float", BASE_TYPE], [" = ", SYMBOL], ["2.2", NUMBER]],
	[["## For the boss fight. Do NOT turn on for normal marbles.", DOC]],
	[["@export ", ANNOTATION], ["var ", KEYWORD], ["split_on_bump", TEXT], [": ", SYMBOL],
		["bool", BASE_TYPE], [" = ", SYMBOL], ["false", KEYWORD]],
]
const EDIT_LINE: int = 6

var _font := SystemFont.new()
var _ui_font := SystemFont.new()
var _size: int = 34
var _frame: int = 0
var _first: int = 0


func _ready() -> void:
	_font.font_names = PackedStringArray(["JetBrains Mono", "Cascadia Mono", "Consolas", "monospace"])
	_ui_font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "sans-serif"])
	# In plain window pixels: the game's stretch setting would lay a tall
	# window out wider than it is.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	set_anchors_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	_start()


func _start() -> void:
	size = get_viewport_rect().size
	# Fit the longest line across the window, so tall and wide both work.
	var longest: int = 0
	for line: Array in _lines:
		var n: int = 0
		for run: Array in line:
			n += (run[0] as String).length()
		longest = maxi(longest, n)
	var room: float = size.x - _gutter_width_for(40) - 80.0
	_size = clampi(int(room / (longest * 0.6)), 18, 40)
	_first = Engine.get_frames_drawn()


func _process(_delta: float) -> void:
	_frame += 1
	queue_redraw()
	if _frame / 60.0 >= LENGTH:
		print("CLIP %d %d" % [_first, Engine.get_frames_drawn()])
		get_tree().quit()


func _gutter_width_for(font_size: int) -> float:
	return font_size * 2.6


func _draw() -> void:
	var t: float = _frame / 60.0
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var char_w: float = _font.get_char_size("M".unicode_at(0), _size).x
	var line_h: float = _size * 1.55
	var gutter: float = _gutter_width_for(_size)
	var block_h: float = line_h * _lines.size()
	# The code sits a little above the middle.
	var top: float = (size.y - block_h) * 0.47
	var left: float = 40.0

	# The script tab, with a * while there are unsaved changes.
	var bar_h: float = _size * 1.6
	draw_rect(Rect2(0.0, top - bar_h * 2.2, size.x, bar_h), BAR)
	var saved: bool = t < 0.9 or t > 1.75
	var tab: String = "creature.gd" + ("" if saved else "(*)")
	draw_rect(Rect2(left, top - bar_h * 2.2, _ui_font.get_string_size(tab, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_size * 0.8)).x + _size * 1.4, bar_h), BG)
	draw_string(_ui_font, Vector2(left + _size * 0.7, top - bar_h * 2.2 + bar_h * 0.68), tab,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(_size * 0.8), TEXT)

	# What line 7's value reads at this moment, and where the caret is.
	var value: String = "false"
	var selected: bool = false
	if t >= 0.55 and t < 0.9:
		selected = true
	elif t >= 0.9:
		value = "true".substr(0, clampi(int((t - 0.9) / 0.075) + 1, 0, 4))
	var caret_col: int = 0

	for i in _lines.size():
		var y: float = top + line_h * i
		var baseline: float = y + line_h * 0.72
		if i == EDIT_LINE:
			draw_rect(Rect2(0.0, y, size.x, line_h), CURRENT_LINE)
		var num := str(i + 1)
		draw_string(_font, Vector2(left + gutter - _size * 0.9 - char_w * num.length(), baseline), num,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _size, GUTTER)
		var x: float = left + gutter
		var runs: Array = _lines[i]
		for r in runs.size():
			var text: String = runs[r][0]
			if i == EDIT_LINE and r == runs.size() - 1:
				if selected:
					draw_rect(Rect2(x, y + line_h * 0.12, char_w * text.length(), line_h * 0.76), SELECTION)
				else:
					text = value
				caret_col = int((x - left - gutter) / char_w) + text.length()
			draw_string(_font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, runs[r][1])
			x += char_w * text.length()

	# The caret, blinking only while nothing's being typed.
	var typing: bool = t >= 0.5 and t < 1.3
	if typing or fmod(t, 1.0) < 0.55:
		var cx: float = left + gutter + char_w * caret_col
		var cy: float = top + line_h * EDIT_LINE
		draw_rect(Rect2(cx, cy + line_h * 0.15, maxf(2.0, _size * 0.07), line_h * 0.7), Color.WHITE)
