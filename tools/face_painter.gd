extends Control
## Face painter: draw the creatures' felt-tip faces by hand.
## Open tools/face_painter.tscn and press F6.
##
## A face is four parts, each drawn on its own square: the eye (the game
## mirrors it for the right eye), the happy eye (^ ^ when caught), the mouth,
## and the startled mouth (when found). The game places them, squashes the
## eyes to blink and squint, grows them when startled and nudges them to
## look about. Save writes res://faces/<name>.png; when that folder has any
## faces, creatures wear those (picked at random) instead of the built-in
## doodles.
##
## Left mouse draws, right mouse rubs out, Ctrl+Z undoes. The pen is felt-tip:
## slightly see-through ink, so overlapping strokes come out darker, with soft
## edges. Anything you close off in the eye fills with white (it can be turned
## off), and there's a white pen for touching up. The marble on the right
## wears the face as you draw and runs through its moods.

const CreatureScene: PackedScene = preload("res://scenes/creature.tscn")
const SIZE: int = 512
const PART_NAMES: Array[String] = ["Eye", "Happy eye", "Mouth", "Startled mouth"]
const INK := DoodleFace.INK
const WHITE := Color(0.98, 0.97, 0.94)
## How much one pass of the pen covers: a second pass over it goes darker.
const PEN_OPACITY: float = 0.9
## The enclosed-area check runs on the eye shrunk to this size: plenty to
## find what's inside the lines, and quick.
const FILL_GRID: int = 128
const UNDO_STEPS: int = 30
## The dashed guide's radius, as a share of half the square: the size of
## the built-in doodles' eyes and mouths in the game.
const GUIDE: float = 0.65
## Moods the preview runs through, and for how long each (seconds).
const MOODS: Array = [
	["Looking about", CreatureEyes.Mood.NORMAL, 4.0],
	["Squint (cheeky)", CreatureEyes.Mood.SQUINT, 1.6],
	["Wide (startled)", CreatureEyes.Mood.WIDE, 1.6],
	["Happy (caught)", CreatureEyes.Mood.HAPPY, 1.6],
]

var _parts: Array[Image] = []
var _undo: Array[Array] = [[], [], [], []]
var _part: int = 0
var _brush: float = 18.0
var _drawing: bool = false
var _erasing: bool = false
var _last: Vector2 = Vector2.ZERO
var _dirty: bool = true
var _pen_white: bool = false
var _auto_white: bool = true
## While drawing: the part as it was before this stroke, and how much the
## stroke covers each pixel (a stroke doesn't build up on itself, only on
## earlier strokes, as felt-tip does).
var _stroke_base: Image
var _stroke_mask := PackedFloat32Array()
var _stroke_length: float = 0.0
## How soon the preview may rebuild while drawing (it isn't free).
var _preview_wait: float = 0.0

var _canvas: TextureRect
var _canvas_tex: ImageTexture
var _name_edit: LineEdit
var _faces: OptionButton
var _status: Label
var _mood_label: Label
var _part_buttons: Array[Button] = []

var _creature: Creature
var _eyes: CreatureEyes
var _material: ShaderMaterial
var _camera: Camera3D
var _mood_index: int = 0
var _mood_left: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	# Real screen pixels, not the game's scaled design space.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for i in DoodleFace.CELLS:
		_parts.append(_blank())
	_build_ui()
	_build_preview()
	_refresh_faces()
	_select_part(0)


# --- Drawing -----------------------------------------------------------------

func _blank() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if b.pressed:
				_begin_stroke(b.button_index == MOUSE_BUTTON_RIGHT)
				_drawing = true
				_last = _to_image(b.position)
				_stamp_line(_last, _last)
			else:
				_drawing = false
				_show_part()
				_dirty = true
	elif event is InputEventMouseMotion and _drawing:
		var at := _to_image((event as InputEventMouseMotion).position)
		_stamp_line(_last, at)
		_last = at


## Starts a pen stroke (or a rubbing-out one) on the current part.
func _begin_stroke(erasing: bool) -> void:
	_push_undo()
	_erasing = erasing
	_stroke_base = _parts[_part].duplicate() as Image
	_stroke_mask.resize(SIZE * SIZE)
	_stroke_mask.fill(0.0)
	_stroke_length = 0.0


func _to_image(at: Vector2) -> Vector2:
	return at * float(SIZE) / _canvas.size.x


## Felt-tip dabs along a line: a soft, slightly fibrous edge, a touch wider
## where the pen first lands (the ink pools), and laid over what was there
## before the stroke at PEN_OPACITY.
func _stamp_line(from: Vector2, to: Vector2) -> void:
	var image := _parts[_part]
	var steps: int = maxi(ceili(from.distance_to(to) / (_brush * 0.25)), 1)
	var lo := Vector2i(SIZE, SIZE)
	var hi := Vector2i(-1, -1)
	for i in steps + 1:
		var c: Vector2 = from.lerp(to, float(i) / steps)
		var travelled: float = _stroke_length + from.distance_to(c)
		var pool: float = 1.0 + 0.18 * exp(-travelled / (_brush * 1.5))
		var r: float = _brush * (2.2 if _erasing else pool)
		lo = Vector2i(mini(lo.x, floori(c.x - r - 2.0)), mini(lo.y, floori(c.y - r - 2.0)))
		hi = Vector2i(maxi(hi.x, ceili(c.x + r + 2.0)), maxi(hi.y, ceili(c.y + r + 2.0)))
		for y in range(maxi(floori(c.y - r - 2.0), 0), mini(ceili(c.y + r + 2.0), SIZE)):
			for x in range(maxi(floori(c.x - r - 2.0), 0), mini(ceili(c.x + r + 2.0), SIZE)):
				var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
				# Soft over the last 1.5 px, with a little fibre in the edge.
				var cover: float = clampf((r + 0.75 - d) / 1.5, 0.0, 1.0)
				if cover <= 0.0:
					continue
				if d > r - 2.0:
					cover *= 0.75 + 0.25 * _grain(x, y)
				var k: int = y * SIZE + x
				_stroke_mask[k] = maxf(_stroke_mask[k], cover)
	_stroke_length += from.distance_to(to)
	# Lay the stroke over the part as it was, in the touched area only.
	var pen: Color = WHITE if _pen_white else INK
	for y in range(maxi(lo.y, 0), mini(hi.y, SIZE)):
		for x in range(maxi(lo.x, 0), mini(hi.x, SIZE)):
			var m: float = _stroke_mask[y * SIZE + x]
			if m <= 0.0:
				continue
			var base: Color = _stroke_base.get_pixel(x, y)
			if _erasing:
				image.set_pixel(x, y, Color(base.r, base.g, base.b, base.a * (1.0 - m)))
			else:
				var cover: float = m * PEN_OPACITY
				var a: float = cover + base.a * (1.0 - cover)
				var rgb: Color = (pen * cover + base * base.a * (1.0 - cover)) / maxf(a, 0.0001)
				image.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, a))
	_canvas_tex.update(image)
	if _preview_wait <= 0.0:
		_dirty = true
		_preview_wait = 0.15


## A fixed speckle per pixel, 0..1: the felt's fibres.
func _grain(x: int, y: int) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


## The part as the game sees it: for the eye, white filling whatever the ink
## closes off, under the ink.
func _composed(index: int) -> Image:
	var part := _parts[index]
	if index != DoodleFace.Cell.EYE or not _auto_white:
		return part
	var small := part.duplicate() as Image
	small.resize(FILL_GRID, FILL_GRID, Image.INTERPOLATE_BILINEAR)
	var n: int = FILL_GRID
	var wall := PackedByteArray()
	wall.resize(n * n)
	for y in n:
		for x in n:
			wall[y * n + x] = 1 if small.get_pixel(x, y).a > 0.3 else 0
	# Flood in from the edges: whatever the flood can't reach is enclosed.
	var outside := PackedByteArray()
	outside.resize(n * n)
	var queue: Array[int] = []
	for i in n:
		for k: int in [i, (n - 1) * n + i, i * n, i * n + n - 1]:
			if wall[k] == 0 and outside[k] == 0:
				outside[k] = 1
				queue.append(k)
	var head: int = 0
	while head < queue.size():
		var k: int = queue[head]
		head += 1
		var x: int = k % n
		var y: int = k / n
		for nb: int in [k - 1 if x > 0 else -1, k + 1 if x < n - 1 else -1, k - n if y > 0 else -1, k + n if y < n - 1 else -1]:
			if nb >= 0 and wall[nb] == 0 and outside[nb] == 0:
				outside[nb] = 1
				queue.append(nb)
	# White over everything enclosed, spread a cell under the ink so no gap
	# shows at the line's soft edge.
	var white := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var any_white := false
	for y in n:
		for x in n:
			if outside[y * n + x] == 1:
				continue
			var inside := wall[y * n + x] == 0
			if not inside:
				for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var xx: int = clampi(x + o.x, 0, n - 1)
					var yy: int = clampi(y + o.y, 0, n - 1)
					if outside[yy * n + xx] == 0 and wall[yy * n + xx] == 0:
						inside = true
			if inside:
				white.set_pixel(x, y, WHITE)
				any_white = true
	if not any_white:
		return part
	white.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	white.blend_rect(part, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)
	return white


## Shows the current part on the canvas as the game will draw it.
func _show_part() -> void:
	_canvas_tex.update(_composed(_part))


func _set_auto_white(on: bool) -> void:
	_auto_white = on
	_show_part()
	_dirty = true


func _push_undo() -> void:
	var stack: Array = _undo[_part]
	stack.append(_parts[_part].duplicate())
	if stack.size() > UNDO_STEPS:
		stack.pop_front()


func _undo_last() -> void:
	var stack: Array = _undo[_part]
	if stack.is_empty():
		return
	_parts[_part] = stack.pop_back()
	_show_part()
	_dirty = true


func _clear_part() -> void:
	_push_undo()
	_parts[_part] = _blank()
	_show_part()
	_dirty = true


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k.pressed and k.keycode == KEY_Z and k.ctrl_pressed:
		_undo_last()


func _select_part(index: int) -> void:
	_part = index
	_show_part()
	for i in _part_buttons.size():
		_part_buttons[i].button_pressed = i == index
	_canvas.queue_redraw()


## The four parts side by side, as the game reads them.
func _atlas() -> Image:
	var atlas := Image.create(SIZE * DoodleFace.CELLS, SIZE, false, Image.FORMAT_RGBA8)
	for i in DoodleFace.CELLS:
		atlas.blit_rect(_composed(i), Rect2i(0, 0, SIZE, SIZE), Vector2i(i * SIZE, 0))
	return atlas


# --- Saving and loading --------------------------------------------------------

func _save() -> void:
	var face_name: String = _name_edit.text.strip_edges().to_snake_case().validate_filename()
	if face_name.is_empty():
		_status.text = "Give the face a name first."
		return
	DirAccess.make_dir_recursive_absolute(DoodleFace.FOLDER)
	var path: String = "%s/%s.png" % [DoodleFace.FOLDER, face_name]
	var err: Error = _atlas().save_png(path)
	_status.text = ("Saved %s" % path) if err == OK else ("Couldn't save (%s)" % error_string(err))
	_refresh_faces(face_name)


func _load(face_name: String) -> void:
	var path: String = "%s/%s.png" % [DoodleFace.FOLDER, face_name]
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(path))
	if atlas == null:
		_status.text = "Couldn't load %s" % path
		return
	atlas.convert(Image.FORMAT_RGBA8)
	var cell: int = atlas.get_height()
	for i in DoodleFace.CELLS:
		var part := atlas.get_region(Rect2i(i * cell, 0, cell, cell))
		if cell != SIZE:
			part.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		_parts[i] = part
		_undo[i] = []
	_name_edit.text = face_name
	_show_part()
	_dirty = true
	_status.text = "Loaded %s" % face_name


func _new_face() -> void:
	for i in DoodleFace.CELLS:
		_parts[i] = _blank()
		_undo[i] = []
	_name_edit.text = ""
	_faces.select(-1)
	_show_part()
	_dirty = true
	_status.text = "New face"


func _refresh_faces(select: String = "") -> void:
	_faces.clear()
	for face_name: String in DoodleFace.face_names():
		_faces.add_item(face_name)
		if face_name == select:
			_faces.select(_faces.item_count - 1)
	if select.is_empty():
		_faces.select(-1)


# --- Preview -----------------------------------------------------------------

func _process(delta: float) -> void:
	_preview_wait -= delta
	if _dirty:
		_dirty = false
		_material.set_shader_parameter("face_tex", DoodleFace.texture_from(_atlas()))
	_time += delta
	_mood_left -= delta
	if _mood_left <= 0.0:
		_mood_index = (_mood_index + 1) % MOODS.size()
		_mood_left = MOODS[_mood_index][2]
		_eyes.mood = MOODS[_mood_index][1]
		_mood_label.text = MOODS[_mood_index][0]
	# Glance about while looking about; otherwise straight at you.
	var look := Vector3.ZERO
	if _mood_index == 0:
		look = Vector3(sin(_time * 1.3) * 0.6, cos(_time * 0.9) * 0.25, 0.0)
	_eyes.look_target = _camera.global_position + look
	_eyes.step(delta)
	# A gentle sway, so you see it off-square too.
	var visual := _creature.get_node("Visual") as Node3D
	visual.basis = Basis(Vector3.UP, PI + sin(_time * 0.7) * 0.35) * Basis(Vector3.RIGHT, -0.15)


func _build_preview() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(460, 460)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	_preview_holder.add_child(view)
	_preview_rect.texture = view.get_texture()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.03, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.75)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	view.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.75)
	key.light_energy = 1.4
	view.add_child(key)
	key.look_at_from_position(Vector3(-1.0, 1.2, 1.5), Vector3.ZERO)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	view.add_child(_camera)
	_camera.look_at_from_position(Vector3(0.0, 0.03, 0.26), Vector3.ZERO)
	_creature = CreatureScene.instantiate() as Creature
	view.add_child(_creature)
	# Only its looks: no hiding or fleeing. Its eyes are stepped from here.
	_creature.process_mode = Node.PROCESS_MODE_DISABLED
	(_creature.get_node("Glow") as Light3D).visible = false
	_eyes = _creature.get_node("Visual/Eyes") as CreatureEyes
	_material = (_creature.get_node("Visual/Body") as MeshInstance3D).material_override as ShaderMaterial
	_set_colour(1)
	_material.set_shader_parameter("face_drawn", true)
	_material.set_shader_parameter("face_lop", 0.0)


func _set_colour(index: int) -> void:
	_material.set_shader_parameter("tint", Creature.BODY_COLORS[index])


# --- Layout --------------------------------------------------------------------

var _preview_holder: Control
var _preview_rect: TextureRect


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.11, 0.17)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 24)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	margin.add_child(row)

	# Left: the face's name, saving and loading, the parts, the brush.
	var side_panel := VBoxContainer.new()
	side_panel.custom_minimum_size = Vector2(240, 0)
	side_panel.add_theme_constant_override("separation", 8)
	row.add_child(side_panel)
	side_panel.add_child(_heading("Face"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "name"
	side_panel.add_child(_name_edit)
	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(_save)
	side_panel.add_child(save)
	var new_face := Button.new()
	new_face.text = "New"
	new_face.pressed.connect(_new_face)
	side_panel.add_child(new_face)
	side_panel.add_child(_heading("Open"))
	_faces = OptionButton.new()
	_faces.item_selected.connect(func(i: int) -> void: _load(_faces.get_item_text(i)))
	side_panel.add_child(_faces)
	side_panel.add_child(_heading("Part"))
	for i in PART_NAMES.size():
		var b := Button.new()
		b.text = PART_NAMES[i]
		b.toggle_mode = true
		b.pressed.connect(_select_part.bind(i))
		side_panel.add_child(b)
		_part_buttons.append(b)
	side_panel.add_child(_heading("Pen size"))
	var pen := HSlider.new()
	pen.min_value = 5.0
	pen.max_value = 40.0
	pen.value = _brush
	pen.value_changed.connect(func(v: float) -> void: _brush = v)
	side_panel.add_child(pen)
	side_panel.add_child(_heading("Pen"))
	var pens := HBoxContainer.new()
	var group := ButtonGroup.new()
	for pen_name: String in ["Ink", "White"]:
		var pb := Button.new()
		pb.text = pen_name
		pb.toggle_mode = true
		pb.button_group = group
		pb.button_pressed = pen_name == "Ink"
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(func() -> void: _pen_white = pen_name == "White")
		pens.add_child(pb)
	side_panel.add_child(pens)
	var auto := CheckBox.new()
	auto.text = "White inside eyes"
	auto.button_pressed = _auto_white
	auto.toggled.connect(_set_auto_white)
	side_panel.add_child(auto)
	var undo := Button.new()
	undo.text = "Undo (Ctrl+Z)"
	undo.pressed.connect(_undo_last)
	side_panel.add_child(undo)
	var clear := Button.new()
	clear.text = "Clear this part"
	clear.pressed.connect(_clear_part)
	side_panel.add_child(clear)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	side_panel.add_child(_status)
	var help := Label.new()
	help.text = "Left mouse draws, right mouse rubs out.\nGo over a line again to darken it.\nClose a loop in the eye and it fills white.\nThe dashed circle is a good eye or mouth size; keep inside the square.\nThe right eye is this one mirrored."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.modulate = Color(1, 1, 1, 0.6)
	side_panel.add_child(help)

	# Middle: the canvas, on the marble's colour with a guide.
	var canvas_box := Control.new()
	canvas_box.custom_minimum_size = Vector2(SIZE, SIZE)
	canvas_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(canvas_box)
	var paper := ColorRect.new()
	paper.color = Creature.BODY_COLORS[1].lerp(Color.WHITE, 0.55)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_box.add_child(paper)
	_canvas_tex = ImageTexture.create_from_image(_parts[0])
	_canvas = TextureRect.new()
	_canvas.texture = _canvas_tex
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.draw.connect(_draw_guide)
	canvas_box.add_child(_canvas)

	# Right: the live preview.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	right.add_child(_heading("Preview"))
	_preview_holder = Control.new()
	right.add_child(_preview_holder)
	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(460, 460)
	right.add_child(_preview_rect)
	_mood_label = Label.new()
	right.add_child(_mood_label)
	var colours := OptionButton.new()
	for i in Creature.BODY_COLORS.size():
		colours.add_item("Colour %d" % (i + 1))
	colours.select(1)
	colours.item_selected.connect(_set_colour)
	right.add_child(colours)


## The dashed size guide and the square's centre, drawn over the canvas.
func _draw_guide() -> void:
	var c := Vector2(SIZE, SIZE) * 0.5
	var guide := Color(0.0, 0.0, 0.0, 0.25)
	var r: float = SIZE * 0.5 * GUIDE
	for i in 48:
		if i % 2 == 0:
			var a0: float = TAU * i / 48.0
			_canvas.draw_arc(c, r, a0, a0 + TAU / 48.0, 4, guide, 2.0)
	_canvas.draw_line(c - Vector2(10, 0), c + Vector2(10, 0), guide, 2.0)
	_canvas.draw_line(c - Vector2(0, 10), c + Vector2(0, 10), guide, 2.0)


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.modulate = Color(1, 1, 1, 0.75)
	return l
