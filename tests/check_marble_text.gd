extends Node
## Checks the marble text's swirls hold still: every letter must pick one swirl
## pattern for all its pixels, wherever the words land (centred text lands on
## odd fractions of a pixel), and keep it while the words grow and shrink.
## Uses the shader's `show_key` view, which paints each letter flat with the
## number its swirls come from. Needs a real window (no --headless).
## Run: Godot --path . --resolution 960x540 res://tests/check_marble_text.tscn

const VIEW_SIZE := Vector2i(1150, 200)
const WORDS: String = "Marbles"
## Wide gaps between letters, so each letter is its own blob of pixels.
const GAP: int = 40
## Colours are read back at 8 bits, so a smooth value right on a rounding step
## can read one apart. Real splits differ by far more.
const TOLERANCE: int = 2

var _failures: int = 0
var _view: SubViewport
var _text: Control
var _at: Vector2 = Vector2.ZERO
var _size: int = 112
var _font: FontVariation


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_view = SubViewport.new()
	_view.size = VIEW_SIZE
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_text = Control.new()
	_text.size = Vector2(VIEW_SIZE)
	UiStyle.marble(_text)
	UiStyle.set_marble_drift(_text)
	(_text.material as ShaderMaterial).set_shader_parameter("show_key", 1.0)
	_text.draw.connect(_draw_words)
	_view.add_child(_text)
	_font = FontVariation.new()
	_font.base_font = UiStyle.font(700)
	_font.spacing_glyph = GAP

	# --- Every letter one pattern, at many sub-pixel positions and sizes ---
	var split: Array[String] = []
	for fs: int in [UiStyle.TITLE_FONT_SIZE, 126, 112]:
		for step in 32:
			var x: float = 40.0 + step * (4.0 / 32.0) + 0.013 * step
			var letters: Array = await _letters(Vector2(x, 170.0), fs, 1.0)
			if letters.size() != WORDS.length():
				split.append("%d px at x=%.3f: %d blobs" % [fs, x, letters.size()])
				continue
			for i in letters.size():
				if _spread(letters[i].keys()) > TOLERANCE:
					split.append("%d px at x=%.3f: '%s' has %d patterns %s" % [fs, x, WORDS[i], letters[i].size(), letters[i]])
	_check("every letter has one swirl pattern wherever it lands", split.is_empty(),
		"%d bad renders, e.g. %s" % [split.size(), split.slice(0, 4)])

	# --- The same pattern while a pointed-at word grows (MenuPanel scales it) ---
	var base: Array = _keys(await _letters(Vector2(40.37, 170.0), 112, 1.0))
	_check("each letter gets its own pattern", _distinct(base), str(base))
	var changed: Array[String] = []
	for step in 13:
		var s: float = lerpf(1.0 / (1.0 + MenuPanel.BARE_GROW), 1.0, step / 12.0)
		var keys: Array = _keys(await _letters(Vector2(40.37, 170.0), 112, s))
		if not _same(keys, base):
			changed.append("scale %.3f" % s)
	_check("letters keep their pattern as the words grow", changed.is_empty(), str(changed))

	# --- Moving up and down (panels lift when pointed at) changes nothing ---
	var moved: Array[String] = []
	for step in 9:
		var keys: Array = _keys(await _letters(Vector2(40.37, 170.0 - step * 1.37), 112, 1.0))
		if not _same(keys, base):
			moved.append("%.2f px up" % (step * 1.37))
	_check("letters keep their pattern as the words lift", moved.is_empty(), str(moved))

	# --- Headings drift from a script, not TIME, which jumps back every hour ---
	var uses_time: bool = false
	for line: String in UiStyle.MARBLE_SHADER.code.split("\n"):
		if line.get_slice("//", 0).contains("TIME"):
			uses_time = true
	_check("the shader doesn't use TIME", not uses_time, "")
	var heading := UiStyle.label("Paused", UiStyle.TITLE_FONT_SIZE, UiStyle.CREAM)
	UiStyle.set_marble_drift(heading)
	add_child(heading)
	var m := heading.material as ShaderMaterial
	await get_tree().process_frame
	var d0: float = m.get_shader_parameter("drift")
	get_tree().paused = true
	for i in 10:
		await get_tree().process_frame
	get_tree().paused = false
	var d1: float = m.get_shader_parameter("drift")
	_check("a heading's swirls keep drifting, even while paused", d1 > d0 and d1 - d0 < 0.5,
		"%.3f -> %.3f" % [d0, d1])

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _draw_words() -> void:
	UiStyle.set_marble_line(_text, _at.y, _size)
	_text.draw_string(_font, _at, WORDS, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, UiStyle.CREAM)


## Draws the words and returns, for each letter from left to right, the set of
## swirl numbers its pixels show.
func _letters(at: Vector2, fs: int, scale: float) -> Array:
	_at = at
	_size = fs
	_text.pivot_offset = Vector2(VIEW_SIZE) * 0.5
	_text.scale = Vector2.ONE * scale
	_text.queue_redraw()
	# Draw now rather than waiting for the next frame: a window in the
	# background can be held back for seconds at a time.
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	return _blobs(_view.get_texture().get_image())


## Splits the painted pixels into letters at the empty columns between them,
## left to right, each the colours inside it and how many pixels have each.
func _blobs(image: Image) -> Array:
	image.convert(Image.FORMAT_RGBA8)
	var w: int = image.get_width()
	var h: int = image.get_height()
	var data: PackedByteArray = image.get_data()
	var found: Array = []
	var current: Dictionary = {}
	for x in w:
		var empty: bool = true
		for y in h:
			var i: int = (y * w + x) * 4
			if data[i + 3] >= 128:
				empty = false
				var c: int = data[i] << 16 | data[i + 1] << 8 | data[i + 2]
				current[c] = current.get(c, 0) + 1
		if empty and not current.is_empty():
			found.append(current)
			current = {}
	if not current.is_empty():
		found.append(current)
	return found


## Each letter's commonest colour, left to right, for comparing renders.
func _keys(letters: Array) -> Array:
	return letters.map(func(c: Dictionary) -> int:
		var best: int = -1
		for k: int in c:
			if best < 0 or c[k] > c[best]:
				best = k
		return best)


## The biggest difference in any one channel between these colours, out of 255.
func _spread(colours: Array) -> int:
	var most: int = 0
	for a: int in colours:
		for b: int in colours:
			for shift: int in [0, 8, 16]:
				most = maxi(most, absi((a >> shift & 255) - (b >> shift & 255)))
	return most


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if _spread([a[i], b[i]]) > TOLERANCE:
			return false
	return true


## No two letters share a pattern.
func _distinct(keys: Array) -> bool:
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			if _spread([keys[i], keys[j]]) <= 8:
				return false
	return true


func _check(what: String, ok: bool, detail: String) -> void:
	if ok:
		print("PASS: %s" % what)
	else:
		_failures += 1
		print("FAIL: %s  (%s)" % [what, detail])
