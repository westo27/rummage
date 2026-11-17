extends Node
## Every named felt-tip face (DoodleFace.VARIANTS) on one numbered sheet, for
## choosing which ones creatures use. Needs a real window.
## Run: Godot --path . --resolution 1500x1360 res://tests/shoot_face_variants.tscn
## Writes face_variants.png to user://shots.

const CreatureScene: PackedScene = preload("res://scenes/creature.tscn")
const OUT: String = "user://shots"
const COLUMNS: int = 5
const GAP: float = 0.15
## Room under each ball for its label, in metres.
const LABEL_ROOM: float = 0.035


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

	var count: int = DoodleFace.VARIANTS.size()
	var rows: int = ceili(float(count) / COLUMNS)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = (GAP + LABEL_ROOM) * rows + 0.02
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, -2.0), Vector3.ZERO)
	camera.make_current()

	var labels := CanvasLayer.new()
	add_child(labels)
	var spots: Array[Vector3] = []
	for i in count:
		var row: int = i / COLUMNS
		var col: int = i % COLUMNS
		# The camera looks down +Z from -Z, so screen right is world -X.
		var at := Vector3(((COLUMNS - 1) * 0.5 - col) * GAP,
			((rows - 1) * 0.5 - row) * (GAP + LABEL_ROOM) + LABEL_ROOM * 0.5, 0.0)
		_creature(at, i, camera)
		spots.append(at)
	await get_tree().process_frame
	for i in count:
		var under: Vector2 = camera.unproject_position(spots[i] + Vector3(0.0, -0.066, 0.0))
		var label := UiStyle.label("%d  %s" % [i + 1, DoodleFace.VARIANTS[i][0]], 26, UiStyle.CREAM)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(260.0, 40.0)
		label.position = under - Vector2(130.0, 0.0)
		labels.add_child(label)
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/face_variants.png" % OUT)
	print("RESULT face variants in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _creature(at: Vector3, index: int, camera: Camera3D) -> void:
	var c := CreatureScene.instantiate() as Creature
	add_child(c)
	c.process_mode = Node.PROCESS_MODE_DISABLED
	(c.get_node("Glow") as Light3D).visible = false
	c.global_position = at
	var mat := (c.get_node("Visual/Body") as MeshInstance3D).material_override as ShaderMaterial
	mat.set_shader_parameter("tint", Creature.BODY_COLORS[index % Creature.BODY_COLORS.size()])
	mat.set_shader_parameter("seed", 0.17 * index)
	var face := DoodleFace.variant(index)
	# Lopsided by a fixed amount each, so the sheet is the same every run.
	face.lop = sin(index * 2.3) * 0.7
	face.apply(mat)
	var visual := c.get_node("Visual") as Node3D
	visual.look_at(camera.global_position, Vector3.UP)
	# Tipped a little below the camera, as they're seen in play.
	visual.basis = visual.basis * Basis(Vector3.RIGHT, deg_to_rad(-10.0))
	var eyes := c.get_node("Visual/Eyes") as CreatureEyes
	eyes.look_target = camera.global_position
	eyes.set("_mood_left", 0.0)
	eyes.set("_next_blink", 1000.0)
	for i in 4:
		eyes.step(1.0)
