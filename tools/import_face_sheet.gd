extends Node
## Turns a sheet of hand-drawn doodle faces (dark lines on a light page, in
## rows) into drawn faces in res://faces, one per face on the sheet.
##
## Each face's ink is split into its left eye, right eye and mouth: blobs of
## ink near the face's middle are the mouth, the rest belong to the eye on
## their side (brows, tears, blush marks and all). They're scaled so the two
## eyes sit as far apart as the game puts them, keeping the face's own
## proportions, and saved with a right eye of their own, so lopsided faces
## (winks, one raised brow) stay lopsided. The happy eye and startled mouth
## are left blank, for the game to make from the eye and mouth.
## Run: Godot --path . res://tools/import_face_sheet.tscn -- <sheet.png> <name prefix>
## (defaults: res://art/face_sheet.png, "doodle"). Existing faces are replaced.

const CELL: int = 256
## Where the game puts each part, in face units (see creature_marble.gdshader):
## eye centres, the eye box's half-size, the mouth's centre and half-size.
const EYE_X: float = 0.3
const EYE_Y: float = 0.08
const EYE_BOX: float = 0.28
const MOUTH_Y: float = -0.22
const MOUTH_BOX: float = 0.3
## Blobs whose middle is within this share of the face's width of its centre
## line are the mouth.
const MOUTH_BAND: float = 0.2
## Gaps (sheet pixels) that split rows of faces, and faces within a row.
const ROW_GAP: int = 8
const FACE_GAP: int = 26


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var sheet_path: String = args[0] if args.size() > 0 else "res://art/face_sheet.png"
	var prefix: String = args[1] if args.size() > 1 else "doodle"
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
	sheet.convert(Image.FORMAT_RGBA8)
	var w: int = sheet.get_width()
	var h: int = sheet.get_height()
	var ink := PackedFloat32Array()
	ink.resize(w * h)
	for y in h:
		for x in w:
			var c: Color = sheet.get_pixel(x, y)
			ink[y * w + x] = clampf((0.72 - (c.r + c.g + c.b) / 3.0) / 0.45, 0.0, 1.0)
	var blobs: Array[Dictionary] = _blobs(ink, w, h)
	DirAccess.make_dir_recursive_absolute(DoodleFace.FOLDER)
	var count: int = 0
	for row: Array in _split(blobs, 1, ROW_GAP):
		for face: Array in _split(row, 0, FACE_GAP):
			count += 1
			var face_name: String = "%s_%02d" % [prefix, count]
			var atlas: Image = _face(face, ink, w)
			if atlas == null:
				print("skipped %s: couldn't find two eyes" % face_name)
				continue
			atlas.save_png("%s/%s.png" % [DoodleFace.FOLDER, face_name])
			print("made %s" % face_name)
	print("RESULT %d faces from %s" % [count, sheet_path])
	get_tree().quit()


## Joined-up patches of ink (8-connected), each with its box and middle.
func _blobs(ink: PackedFloat32Array, w: int, h: int) -> Array[Dictionary]:
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var out: Array[Dictionary] = []
	for start in w * h:
		if ink[start] < 0.35 or label[start] != -1:
			continue
		var id: int = out.size()
		var pixels := PackedInt32Array([start])
		label[start] = id
		var head: int = 0
		while head < pixels.size():
			var k: int = pixels[head]
			head += 1
			var x: int = k % w
			var y: int = k / w
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var n: int = ny * w + nx
					if ink[n] >= 0.35 and label[n] == -1:
						label[n] = id
						pixels.append(n)
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		var sum := Vector2.ZERO
		for k in pixels:
			var p := Vector2i(k % w, k / w)
			lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
			hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
			sum += Vector2(p)
		out.append({"pixels": pixels, "lo": lo, "hi": hi, "mid": sum / pixels.size()})
	return out.filter(func(b: Dictionary) -> bool: return (b["pixels"] as PackedInt32Array).size() >= 6)


## Groups blobs whose spans along `axis` overlap or nearly touch (within
## `gap`) along `axis` (1: rows of faces, by y; 0: faces in a row, by x).
func _split(blobs: Array, axis: int, gap: int) -> Array:
	var sorted: Array = blobs.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["lo"] as Vector2i)[axis] < (b["lo"] as Vector2i)[axis])
	var groups: Array = []
	var reach: int = -1000000
	for b: Dictionary in sorted:
		var lo: int = (b["lo"] as Vector2i)[axis]
		var hi: int = (b["hi"] as Vector2i)[axis]
		if groups.is_empty() or lo > reach + gap:
			groups.append([])
		(groups[groups.size() - 1] as Array).append(b)
		reach = maxi(reach, hi)
	return groups


## One face's atlas: eye, (blank) happy eye, mouth, (blank) startled mouth,
## right eye. Null if it hasn't got ink on both sides.
func _face(blobs: Array, ink: PackedFloat32Array, w: int) -> Image:
	var lo := Vector2i(1000000, 1000000)
	var hi := Vector2i(-1, -1)
	for b: Dictionary in blobs:
		lo = Vector2i(mini(lo.x, (b["lo"] as Vector2i).x), mini(lo.y, (b["lo"] as Vector2i).y))
		hi = Vector2i(maxi(hi.x, (b["hi"] as Vector2i).x), maxi(hi.y, (b["hi"] as Vector2i).y))
	var cx: float = (lo.x + hi.x) * 0.5
	var width: float = hi.x - lo.x
	var left: Array = []
	var right: Array = []
	var mouth: Array = []
	for b: Dictionary in blobs:
		var dx: float = (b["mid"] as Vector2).x - cx
		if absf(dx) < width * MOUTH_BAND:
			mouth.append(b)
		elif dx < 0.0:
			left.append(b)
		else:
			right.append(b)
	if left.is_empty() or right.is_empty():
		return null
	var lc: Vector2 = _centre(left)
	var rc: Vector2 = _centre(right)
	# Sheet pixels to face units: the eyes land 2 * EYE_X apart.
	var unit: float = EYE_X * 2.0 / maxf(rc.x - lc.x, 1.0)
	var origin := Vector2((lc.x + rc.x) * 0.5, (lc.y + rc.y) * 0.5)
	var atlas := Image.create(CELL * 5, CELL, false, Image.FORMAT_RGBA8)
	_paste(atlas, DoodleFace.Cell.EYE, left, ink, w, origin, unit, Vector2(-EYE_X, EYE_Y), EYE_BOX)
	_paste(atlas, DoodleFace.Cell.MOUTH, mouth, ink, w, origin, unit, Vector2(0.0, MOUTH_Y), MOUTH_BOX)
	_paste(atlas, DoodleFace.Cell.RIGHT_EYE, right, ink, w, origin, unit, Vector2(EYE_X, EYE_Y), EYE_BOX)
	return atlas


## The middle of a group of blobs' combined box.
func _centre(blobs: Array) -> Vector2:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for b: Dictionary in blobs:
		lo = lo.min(Vector2(b["lo"]))
		hi = hi.max(Vector2(b["hi"]))
	return (lo + hi) * 0.5


## Draws a group of blobs into one cell of the atlas, scaled up from the
## sheet and placed where the game will put it.
func _paste(atlas: Image, cell: int, blobs: Array, ink: PackedFloat32Array, w: int,
		origin: Vector2, unit: float, centre: Vector2, box: float) -> void:
	if blobs.is_empty():
		return
	var lo := Vector2i(1000000, 1000000)
	var hi := Vector2i(-1, -1)
	for b: Dictionary in blobs:
		lo = Vector2i(mini(lo.x, (b["lo"] as Vector2i).x), mini(lo.y, (b["lo"] as Vector2i).y))
		hi = Vector2i(maxi(hi.x, (b["hi"] as Vector2i).x), maxi(hi.y, (b["hi"] as Vector2i).y))
	lo -= Vector2i(2, 2)
	hi += Vector2i(2, 2)
	# Only this group's ink: the soft edge pixels next to its blobs too.
	var mine := {}
	for b: Dictionary in blobs:
		for k: int in b["pixels"]:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					mine[k + dy * w + dx] = true
	var size := hi - lo + Vector2i.ONE
	var crop := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var k: int = (lo.y + y) * w + lo.x + x
			if mine.has(k):
				var ink_color: Color = DoodleFace.INK
				crop.set_pixel(x, y, Color(ink_color.r, ink_color.g, ink_color.b, ink[k]))
	# Sheet pixels to cell pixels.
	var scale: float = unit / (box * 2.0) * CELL
	var scaled := Vector2i(maxi(roundi(size.x * scale), 1), maxi(roundi(size.y * scale), 1))
	crop.resize(scaled.x, scaled.y, Image.INTERPOLATE_CUBIC)
	# Where the crop's corner lands: face units, then the cell's 0..1.
	var f := Vector2((lo.x - origin.x) * unit, -(lo.y - origin.y) * unit)
	var uv := Vector2((f.x - centre.x) / (box * 2.0) + 0.5, 0.5 - (f.y - centre.y) / (box * 2.0))
	var at := Vector2i(roundi(uv.x * CELL), roundi(uv.y * CELL))
	# Kept inside its own cell.
	var src := Rect2i(Vector2i.ZERO, scaled)
	var dst := at
	if dst.x < 0:
		src.position.x -= dst.x
		src.size.x += dst.x
		dst.x = 0
	if dst.y < 0:
		src.position.y -= dst.y
		src.size.y += dst.y
		dst.y = 0
	src.size.x = mini(src.size.x, CELL - dst.x)
	src.size.y = mini(src.size.y, CELL - dst.y)
	if src.size.x > 0 and src.size.y > 0:
		atlas.blend_rect(crop, src, dst + Vector2i(cell * CELL, 0))
