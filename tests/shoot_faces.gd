extends Node
## A sheet of felt-tip faces: every creature picks its own, so each row is a
## fresh random set; one column per expression. Needs a real window.
## Run: Godot --path . --resolution 1500x1260 res://tests/shoot_faces.tscn
## Writes faces.png to user://shots.

const CreatureScene: PackedScene = preload("res://scenes/creature.tscn")
const OUT: String = "user://shots"
## Rows: a name, and how far (degrees) the face points below the camera.
## In play you look down from about 35 degrees and the face tips most of the
## way up to you (Creature.FACE_TIP), leaving about 10.
const STYLES: Array = [["As in play", 10.0], ["As in play", 10.0], ["As in play", 10.0],
	["Head-on", 0.0]]
const GAP: float = 0.15
## Expression per column: mood, and where the pupils look (x, y).
const COLUMNS: Array = [
	[CreatureEyes.Mood.NORMAL, Vector2.ZERO],
	[CreatureEyes.Mood.NORMAL, Vector2(0.7, 0.2)],
	[CreatureEyes.Mood.WIDE, Vector2.ZERO],
	[CreatureEyes.Mood.SQUINT, Vector2(-0.4, 0.0)],
	[CreatureEyes.Mood.HAPPY, Vector2.ZERO],
]
const COLOURS: Array[int] = [1, 3, 2, 4, 0]


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

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = GAP * STYLES.size() + 0.03
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, -2.0), Vector3.ZERO)
	camera.make_current()

	var labels := CanvasLayer.new()
	add_child(labels)
	for row in STYLES.size():
		var y: float = (STYLES.size() - 1) * 0.5 * GAP - row * GAP
		for col in COLUMNS.size():
			# The camera looks down +Z from -Z, so screen right is world -X.
			var x: float = ((COLUMNS.size() - 1) * 0.5 - col) * GAP
			_creature(Vector3(x, y, 0.0), STYLES[row][1], row, col, camera)
		var label := UiStyle.label(STYLES[row][0], 26, UiStyle.CREAM)
		label.position = Vector2(20.0, (row + 0.5) / STYLES.size() * get_viewport().get_visible_rect().size.y - 24.0)
		labels.add_child(label)
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/faces.png" % OUT)
	print("RESULT faces in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _creature(at: Vector3, tilt: float, row: int, column: int, camera: Camera3D) -> void:
	var c := CreatureScene.instantiate() as Creature
	add_child(c)
	c.process_mode = Node.PROCESS_MODE_DISABLED
	(c.get_node("Glow") as Light3D).visible = false
	c.global_position = at
	var mat := (c.get_node("Visual/Body") as MeshInstance3D).material_override as ShaderMaterial
	mat.set_shader_parameter("tint", Creature.BODY_COLORS[COLOURS[column]])
	mat.set_shader_parameter("seed", 0.13 * column + 0.31 * row)
	var visual := c.get_node("Visual") as Node3D
	visual.look_at(camera.global_position, Vector3.UP)
	visual.basis = visual.basis * Basis(Vector3.RIGHT, deg_to_rad(-tilt))
	var eyes := c.get_node("Visual/Eyes") as CreatureEyes
	var setup: Array = COLUMNS[column]
	eyes.mood = setup[0]
	var look: Vector2 = setup[1]
	# Screen right is world -X here.
	eyes.look_target = camera.global_position + Vector3(-look.x, look.y, 0.0) * 1.5
	eyes.set("_mood_left", 0.0)
	eyes.set("_next_blink", 1000.0)
	for i in 4:
		eyes.step(1.0)
