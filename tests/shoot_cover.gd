extends Node
## Renders the itch.io cover (630x500): the title on a plain white background
## with five marbles in a row below it, each pulling a different face, the
## middle one winking. Needs a real window (no --headless).
## Run: Godot --path . --resolution 1260x1000 res://tests/shoot_cover.tscn

const OUT: String = "user://shots"
const COVER_SIZE := Vector2i(630, 500)
const TITLE := "Losing My\nMarbles!"
const TITLE_SIZE: int = 300
## Lifts the title from dead centre; with the row below, the pair sits centred.
const TITLE_RAISE: float = 340.0
const BACKGROUND := Color(1.0, 1.0, 1.0)
const FOV: float = 30.0
## Camera distance from the row, and how far above it the camera sits
## (looking straight ahead, so the row lands low in the frame).
const DISTANCE: float = 1.12
const LIFT: float = 0.133
const SPACING: float = 0.141
## Left to right: [colour index into Creature.BODY_COLORS, mood, swirl seed].
## A null mood means the wink, which isn't a mood (see creature_eyes.gd).
const ROW: Array = [
	[0, CreatureEyes.Mood.NORMAL, 0.15],
	[3, CreatureEyes.Mood.WIDE, 0.35],
	[1, null, 0.6],
	[2, CreatureEyes.Mood.SQUINT, 0.8],
	[4, CreatureEyes.Mood.HAPPY, 0.9],
]

var _eyes: Array[CreatureEyes] = []
var _cam: Camera3D = null


func _ready() -> void:
	_run.call_deferred()


## Their own physics is off, so step the eyes here. The winker's wink is held
## at its shut-most point; the rest just look at the camera in their mood.
func _process(delta: float) -> void:
	for i in _eyes.size():
		var e: CreatureEyes = _eyes[i]
		if ROW[i][1] == null:
			e._wink_eye = 1
			e._wink_left = CreatureEyes.WINK_SECONDS * 0.5
		e._blink_left = 0.0
		e._next_blink = 99.0
		e.look_target = _cam.global_position
		e.step(delta)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world := Node3D.new()
	add_child(world)

	# A flat colour behind everything, with a little bloom for the highlights.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.7)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	# A warm key light from the upper left, like the bedside lamp.
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.85, 0.65)
	key.light_energy = 1.4
	key.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(-30.0), 0.0)
	world.add_child(key)

	_cam = Camera3D.new()
	_cam.fov = FOV
	world.add_child(_cam)
	_cam.global_position = Vector3(0.0, LIFT, DISTANCE)
	_cam.current = true

	var scene := load("res://scenes/creature.tscn") as PackedScene
	for i in ROW.size():
		var spec: Array = ROW[i]
		var marble := scene.instantiate() as Creature
		world.add_child(marble)
		marble.set_physics_process(false)  # no AI or gravity: it just sits there
		marble.global_position = Vector3((i - 2) * SPACING, 0.0, 0.0)
		# Face (-Z of its Visual) turned to the camera.
		var visual := marble.get_node("Visual") as Node3D
		visual.global_basis = Basis.looking_at(
			(_cam.global_position - marble.global_position).normalized(), Vector3.UP)
		var mat := marble.get_node("Visual/Body").material_override as ShaderMaterial
		mat.set_shader_parameter("tint", Creature.BODY_COLORS[spec[0]])
		mat.set_shader_parameter("seed", spec[2])
		var eyes := marble.get_node("Visual/Eyes") as CreatureEyes
		if spec[1] != null:
			eyes.show_mood(spec[1], 0.0)  # 0 seconds: the mood stays
		_eyes.append(eyes)

	add_child(_title())
	await _frames(30)
	_cover("cover_row")
	print("RESULT cover shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _title() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.offset = Vector2(0.0, -TITLE_RAISE)
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	# A dark, fat-outlined copy behind the marble text so it reads at
	# thumbnail size. A MarginContainer stacks its children.
	var shade := Label.new()
	shade.text = TITLE
	shade.add_theme_font_override("font", UiStyle.font(700))
	shade.add_theme_font_size_override("font_size", TITLE_SIZE)
	shade.add_theme_color_override("font_color", Color(0.04, 0.02, 0.08, 0.6))
	shade.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08, 0.6))
	shade.add_theme_constant_override("outline_size", 32)
	holder.add_child(shade)
	var label := UiStyle.label(TITLE, TITLE_SIZE, UiStyle.CREAM)
	UiStyle.set_marble_drift(label)
	holder.add_child(label)
	for l: Label in [shade, label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("line_spacing", -15)
	layer.add_child(holder)
	return layer


func _cover(shot_name: String) -> void:
	# macOS stops drawing a window that's covered up, which would save a stale
	# frame; force one.
	RenderingServer.force_draw(false)
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(COVER_SIZE.x, COVER_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png("%s/%s.png" % [OUT, shot_name])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
