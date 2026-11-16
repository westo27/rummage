extends Node
## Every hand-drawn face in res://faces on a marble, each as normal, startled
## and happy, on one labelled sheet. Needs a real window.
## Run: Godot --path . --resolution 1800x1100 res://tests/shoot_drawn_faces.tscn
## Pass `-- <prefix>` to show only faces whose names start with it.
## Writes drawn_faces.png to user://shots.

const CreatureScene: PackedScene = preload("res://scenes/creature.tscn")
const OUT: String = "user://shots"
## Faces across the sheet; each face is a trio of marbles.
const COLUMNS: int = 4
const MOODS: Array = [CreatureEyes.Mood.NORMAL, CreatureEyes.Mood.WIDE, CreatureEyes.Mood.HAPPY]
const BALL_GAP: float = 0.125
const TRIO_GAP: float = 0.43
const ROW_GAP: float = 0.17


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.03, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.75)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.75)
	key.light_energy = 1.4
	add_child(key)
	key.look_at_from_position(Vector3(-1.0, 1.2, -1.5), Vector3.ZERO)

	var names: Array[String] = DoodleFace.face_names()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		names = names.filter(func(n: String) -> bool: return n.begins_with(args[0]))
	var rows: int = ceili(float(names.size()) / COLUMNS)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Tall enough for the rows and, at the window's shape, wide enough for the
	# columns.
	var aspect: float = get_viewport().get_visible_rect().size.aspect()
	camera.size = maxf(ROW_GAP * rows + 0.03, (TRIO_GAP * COLUMNS + 0.02) / aspect)
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, -2.0), Vector3.ZERO)
	camera.make_current()

	var labels := CanvasLayer.new()
	add_child(labels)
	var label_at: Array[Vector3] = []
	for i in names.size():
		var tex: Texture2D = DoodleFace.load_drawn(names[i])
		var row: int = i / COLUMNS
		var col: int = i % COLUMNS
		# The camera looks down +Z from -Z, so screen right is world -X.
		var centre := Vector3(((COLUMNS - 1) * 0.5 - col) * TRIO_GAP,
			((rows - 1) * 0.5 - row) * ROW_GAP + 0.012, 0.0)
		for m in MOODS.size():
			_creature(centre + Vector3((1 - m) * BALL_GAP, 0.0, 0.0), tex, i, MOODS[m], camera)
		label_at.append(centre)
	await get_tree().process_frame
	for i in names.size():
		var under: Vector2 = camera.unproject_position(label_at[i] + Vector3(0.0, -0.062, 0.0))
		var label := UiStyle.label("%d  %s" % [i + 1, names[i]], 22, UiStyle.CREAM)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(300.0, 34.0)
		label.position = under - Vector2(150.0, 0.0)
		labels.add_child(label)
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/drawn_faces.png" % OUT)
	print("RESULT drawn faces in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _creature(at: Vector3, tex: Texture2D, index: int, mood: CreatureEyes.Mood, camera: Camera3D) -> void:
	var c := CreatureScene.instantiate() as Creature
	add_child(c)
	c.process_mode = Node.PROCESS_MODE_DISABLED
	(c.get_node("Glow") as Light3D).visible = false
	c.global_position = at
	var mat := (c.get_node("Visual/Body") as MeshInstance3D).material_override as ShaderMaterial
	mat.set_shader_parameter("tint", Creature.BODY_COLORS[index % Creature.BODY_COLORS.size()])
	mat.set_shader_parameter("seed", 0.17 * index)
	var face := DoodleFace.new()
	face.drawn = tex
	face.eye_span = DoodleFace.measure_eye(tex.get_image())
	face.right_span = DoodleFace.measure_eye(tex.get_image(), DoodleFace.Cell.RIGHT_EYE)
	face.apply(mat)
	var visual := c.get_node("Visual") as Node3D
	visual.look_at(camera.global_position, Vector3.UP)
	# Tipped a little below the camera, as they're seen in play.
	visual.basis = visual.basis * Basis(Vector3.RIGHT, deg_to_rad(-10.0))
	var eyes := c.get_node("Visual/Eyes") as CreatureEyes
	eyes.mood = mood
	eyes.look_target = camera.global_position
	eyes.set("_mood_left", 0.0)
	eyes.set("_next_blink", 1000.0)
	for i in 4:
		eyes.step(1.0)
