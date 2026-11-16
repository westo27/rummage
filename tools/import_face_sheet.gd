extends Node
## Turns a sheet of hand-drawn doodle faces (dark lines on a light page, in
## rows) into drawn faces in res://faces, one per face on the sheet.
##
## Each face's ink is split into its left eye, right eye and mouth: blobs of
## ink near the face's middle are the mouth; on each side the biggest blob is
## the eye, and the rest (brows, tears, hearts, blush marks, a "!") go on a
## still layer that doesn't blink or change with the mood. A blob off to one
## side but below the eyes is part of the mouth (a crooked smile); one in the
## middle but above the eyes is a brow, on the still layer. The whole face is scaled to
## fit the front of the ball, and each part gets a snug box at the spot it
## was drawn: the boxes are saved beside the face as <name>.json, so it looks
## as drawn. It has a right eye of its own, so lopsided faces (winks, one
## raised brow) stay lopsided. The happy eye and startled mouth are left
## blank, for the game to make from the eye and mouth.
## Run: Godot --path . res://tools/import_face_sheet.tscn -- <sheet.png> <name prefix>
## (defaults: res://art/face_sheet.png, "doodle"). Existing faces are replaced.

const CELL: int = 256
## How big the face is on the ball, in face units (see creature_marble.gdshader):
## at most this wide and tall, its middle this high.
const FACE_WIDTH: float = 0.82
const FACE_HEIGHT: float = 0.62
const FACE_Y: float = -0.03
## Room round each part inside its box, in face units.
const PAD: float = 0.025
## Blobs whose middle is within this share of the face's width of its centre
## line are the mouth.
const MOUTH_BAND: float = 0.2
## Faces (numbered from 1, along the rows) whose eyes aren't their biggest
## blobs, where the eye is the highest one instead (hearts or tears below).
const EYES_HIGHEST: Array[int] = [7, 32]
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
			var made: Array = _face(face, ink, w, count in EYES_HIGHEST)
			if made.is_empty():
				print("skipped %s: couldn't find two eyes" % face_name)
				continue
			(made[0] as Image).save_png("%s/%s.png" % [DoodleFace.FOLDER, face_name])
			DoodleFace.save_layout(face_name, made[1])
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


## One face: its atlas (eye, blank happy eye, mouth, blank startled mouth,
## right eye) and its layout, as [atlas, layout]. Empty if it hasn't got ink
## on both sides of its mouth.
func _face(blobs: Array, ink: PackedFloat32Array, w: int, eyes_highest: bool) -> Array:
	var box: Rect2 = _box(blobs)
	var cx: float = box.get_center().x
	var left: Array = []
	var right: Array = []
	var mouth: Array = []
	for b: Dictionary in blobs:
		var dx: float = (b["mid"] as Vector2).x - cx
		if absf(dx) < box.size.x * MOUTH_BAND:
			mouth.append(b)
		elif dx < 0.0:
			left.append(b)
		else:
			right.append(b)
	if left.is_empty() or right.is_empty():
		return []
	# Each side's eye; the rest of that side is still extras, or mouth.
	var eye_l: Dictionary = _eye(left, eyes_highest)
	var eye_r: Dictionary = _eye(right, eyes_highest)
	var eyes_bottom: float = maxf((eye_l["hi"] as Vector2i).y, (eye_r["hi"] as Vector2i).y)
	var extras: Array = []
	for b: Dictionary in left + right:
		if b == eye_l or b == eye_r:
			continue
		var off: float = absf((b["mid"] as Vector2).x - cx) / box.size.x
		if (b["lo"] as Vector2i).y > eyes_bottom and off < 0.33:
			mouth.append(b)
		else:
			extras.append(b)
	left = [eye_l]
	right = [eye_r]
	# Ink in the middle but above the eyes is a brow, not the mouth.
	var eyes_mid: float = ((eye_l["mid"] as Vector2).y + (eye_r["mid"] as Vector2).y) * 0.5
	for b: Dictionary in mouth.duplicate():
		if (b["mid"] as Vector2).y < eyes_mid:
			mouth.erase(b)
			extras.append(b)
	# Sheet pixels to face units: the whole face fits the front of the ball.
	var unit: float = minf(FACE_WIDTH / maxf(box.size.x, 1.0), FACE_HEIGHT / maxf(box.size.y, 1.0))
	var origin: Vector2 = box.get_center()
	var place := func(p: Vector2) -> Vector2:
		return Vector2((p.x - origin.x) * unit, -(p.y - origin.y) * unit + FACE_Y)
	var cells: int = 6 if not extras.is_empty() else 5
	var atlas := Image.create(CELL * cells, CELL, false, Image.FORMAT_RGBA8)
	var face_layout: Dictionary = DoodleFace.LAYOUT.duplicate()
	for part: Array in [["eye", DoodleFace.Cell.EYE, left], ["eye2", DoodleFace.Cell.RIGHT_EYE, right],
			["mouth", DoodleFace.Cell.MOUTH, mouth], ["extra", DoodleFace.Cell.EXTRAS, extras]]:
		var group: Array = part[2]
		if group.is_empty() and part[0] == "extra":
			continue
		if group.is_empty():
			# No mouth drawn: a box below the eyes, for the startled "o".
			var eyes_y: float = minf((face_layout["eye"] as Vector3).y, (face_layout["eye2"] as Vector3).y)
			face_layout["mouth"] = Vector3(0.0, eyes_y - 0.25, 0.18)
			continue
		var g: Rect2 = _box(group)
		var middle: Vector2 = place.call(g.get_center())
		var half: float = maxf(g.size.x, g.size.y) * unit * 0.5 + PAD
		face_layout[part[0]] = Vector3(middle.x, middle.y, half)
		_paste(atlas, part[1], group, ink, w, g, unit, half)
	return [atlas, face_layout]


## A side's eye: its biggest blob, or its highest.
func _eye(side: Array, highest: bool) -> Dictionary:
	var best: Dictionary = side[0]
	for b: Dictionary in side:
		if highest:
			if (b["mid"] as Vector2).y < (best["mid"] as Vector2).y and (b["pixels"] as PackedInt32Array).size() > 30:
				best = b
		elif (b["pixels"] as PackedInt32Array).size() > (best["pixels"] as PackedInt32Array).size():
			best = b
	return best


## The box round a group of blobs, in sheet pixels.
func _box(blobs: Array) -> Rect2:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for b: Dictionary in blobs:
		lo = lo.min(Vector2(b["lo"]))
		hi = hi.max(Vector2(b["hi"]) + Vector2.ONE)
	return Rect2(lo, hi - lo)


## Draws a group of blobs into its cell, scaled to fill it, centred as its
## box is (the layout puts the box where it was on the sheet).
func _paste(atlas: Image, cell: int, blobs: Array, ink: PackedFloat32Array, w: int,
		g: Rect2, unit: float, half: float) -> void:
	var lo := Vector2i(g.position) - Vector2i(2, 2)
	var size := Vector2i(g.size) + Vector2i(4, 4)
	# Only this group's ink, with the soft edge pixels next to its blobs.
	var mine := {}
	for b: Dictionary in blobs:
		for k: int in b["pixels"]:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					mine[k + dy * w + dx] = true
	var crop := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var ink_color: Color = DoodleFace.INK
	for y in size.y:
		for x in size.x:
			var k: int = (lo.y + y) * w + lo.x + x
			if mine.has(k):
				crop.set_pixel(x, y, Color(ink_color.r, ink_color.g, ink_color.b, ink[k]))
	# Sheet pixels to cell pixels; the box's middle lands on the cell's.
	var scale: float = unit / (half * 2.0) * CELL
	var scaled := Vector2i(maxi(roundi(size.x * scale), 1), maxi(roundi(size.y * scale), 1))
	crop.resize(scaled.x, scaled.y, Image.INTERPOLATE_BILINEAR)
	var at := Vector2i(CELL, CELL) / 2 - scaled / 2
	atlas.blend_rect(crop, Rect2i(Vector2i.ZERO, scaled), at + Vector2i(cell * CELL, 0))
