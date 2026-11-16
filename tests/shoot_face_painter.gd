extends Node
## Opens the face painter, draws a sample face with simulated strokes, saves
## it, checks it loads back as a drawn face, and screenshots the tool. The
## sample is deleted again afterwards (pass `-- keep` to keep it, to see it
## in the game). Needs a real window.
## Run: Godot --path . --resolution 1400x800 res://tests/shoot_face_painter.tscn
## Writes face_painter.png to user://shots.

const OUT: String = "user://shots"
const SAMPLE: String = "zz_painter_check"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var painter: Control = (load("res://tools/face_painter.tscn") as PackedScene).instantiate()
	add_child(painter)
	await _frames(5)
	var c := Vector2(256, 256)
	# Eye: a loop with a filled pupil.
	painter.call("_select_part", 0)
	_loop(painter, c, 150.0)
	painter.set("_brush", 40.0)
	_loop(painter, c + Vector2(10, 25), 25.0)
	painter.set("_brush", 18.0)
	# Happy eye: an arch.
	painter.call("_select_part", 1)
	_arc(painter, c + Vector2(0, 60), 120.0, PI * 1.1, PI * 1.9)
	# Mouth: a smile.
	painter.call("_select_part", 2)
	_arc(painter, c - Vector2(0, 80), 150.0, PI * 0.2, PI * 0.8)
	# Startled mouth: a small loop.
	painter.call("_select_part", 3)
	_loop(painter, c, 60.0)
	painter.call("_select_part", 0)
	(painter.get("_name_edit") as LineEdit).text = SAMPLE
	painter.call("_save")
	var path: String = "%s/%s.png" % [DoodleFace.FOLDER, SAMPLE]
	print("%s  saved" % ("PASS" if FileAccess.file_exists(path) else "FAIL"))
	var tex: Texture2D = DoodleFace.load_drawn(SAMPLE)
	print("%s  loads back, 4 cells wide" % ("PASS" if tex != null and tex.get_width() == tex.get_height() * 4 else "FAIL"))
	await _frames(150)  # let the preview run into its moods
	get_viewport().get_texture().get_image().save_png("%s/face_painter.png" % OUT)
	if not "keep" in OS.get_cmdline_user_args():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT face painter shot in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _loop(painter: Control, centre: Vector2, r: float) -> void:
	_arc(painter, centre, r, 0.0, TAU + 0.5)


## A stroke along an arc, as the mouse would draw it (y down on the canvas).
func _arc(painter: Control, centre: Vector2, r: float, from: float, to: float) -> void:
	painter.call("_begin_stroke", false)
	var last := centre + Vector2(cos(from), sin(from)) * r
	for i in 64:
		var a: float = lerpf(from, to, (i + 1) / 64.0)
		var at := centre + Vector2(cos(a), sin(a)) * r
		painter.call("_stamp_line", last, at)
		last = at
	painter.call("_show_part")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
