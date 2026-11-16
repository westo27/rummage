extends Node
## Renders the itch.io cover (630x500): one creature peeking out from under the
## bed, close up, in a dimmed room with a little warm light on its face, HUD
## hidden, the title on top. A few framings are saved to pick from.
## Needs a real window (no --headless).
## Run: Godot --path . --resolution 1260x1000 res://tests/shoot_cover.tscn

const OUT: String = "user://shots"
const COVER_SIZE := Vector2i(630, 500)
const SPOT := Vector3(2.45, 0.1, -1.2)  # just under the bed's front edge
const TITLE_SIZE: int = 350
## Gap above the title, in render pixels: it sits over the bed's side, the
## empty band above the creature, rather than against the top edge.
const TITLE_TOP: int = 300
const TITLE_OUTLINE: int = 44
const SHADOW_DROP: int = 18
const TITLE_FILL := Color(1.0, 0.86, 0.72)
const TITLE_INK := Color(0.2, 0.06, 0.2)
## Beyond this (m) the room goes soft: the hero creature stays sharp.
const DOF_FAR: float = 0.75
const SEED: int = 2
## How much of each lamp's usual brightness is left: night, not daytime.
const LAMP_SCALE: float = 0.2
const EXPOSURE: float = 0.65
## Framings: camera distance in front of the creature (m), sideways offset (m),
## field of view, and how far above the creature the camera aims (m).
const FRAMINGS: Array[Vector4] = [
	Vector4(0.5, 0.0, 32.0, 0.06),
	Vector4(0.45, 0.06, 34.0, 0.06),
]
## Two more, deep in the dark under the bed: just their eyes showing.
const BACK_SPOTS: Array[Vector3] = [Vector3(2.22, 0.1, -2.0), Vector3(2.72, 0.1, -2.1)]
const MOON_SCALE: float = 0.25

var _creature: Creature = null
var _camera: Camera3D = null
## Each posed creature and the spot it's held at.
var _posed: Dictionary = {}


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	# Keep it peeking: a hidden creature looks at you only now and then.
	for c: Creature in _posed:
		# Held in place, peeking, facing the lens (the face looks down -Z),
		# level, so both eyes show.
		c.global_position = _posed[c]
		c.velocity = Vector3.ZERO
		c._peek_left = 1.0
		c._eyes._next_blink = 10.0  # eyes wide: no blinks mid-shot
		var at: Vector3 = _camera.global_position
		at.y = c.global_position.y
		(c.get_node("Visual") as Node3D).look_at(at, Vector3.UP)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Creature colours are random; a fixed seed keeps the cover the same each run.
	seed(SEED)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var player := main.get_node("Player") as Node3D
	player.set_process_unhandled_input(false)
	(main.get_node("HUD") as CanvasLayer).visible = false
	_hide_canvas(main.get_node("Tutorial"))
	_dim(main)

	# A pink one: warm against the dark, and it matches the title's swirl.
	var others: Array[Creature] = []
	for c in main.get_node("MainRoomCreatures").get_children():
		if not c is Creature:
			continue
		if _creature == null and (c as Creature).body_color == Creature.BODY_COLORS[1]:
			_creature = c as Creature
		else:
			others.append(c as Creature)
	_posed[_creature] = SPOT
	for i in BACK_SPOTS.size():
		_posed[others[i]] = BACK_SPOTS[i]
	for c: Creature in _posed:
		c.global_position = _posed[c]
		c.reset_physics_interpolation()

	Input.action_press("prone")  # right down at floor level
	var camera := player.get_node("Head/Camera3D") as Camera3D
	_camera = camera
	# A soft warm light just beside the lens, like a night light held low:
	# it puts a catchlight in the eyes and leaves the room behind dark.
	var face_light := OmniLight3D.new()
	face_light.light_color = Color(1.0, 0.82, 0.62)
	face_light.light_energy = 0.4
	face_light.omni_range = 0.7
	main.add_child(face_light)
	_polish(main, camera)
	await _frames(30)
	add_child(_vignette())
	add_child(_title())

	for i in FRAMINGS.size():
		var f: Vector4 = FRAMINGS[i]
		player.global_position = SPOT + Vector3(f.y, -0.05, f.x)
		player.reset_physics_interpolation()
		await _frames(40)
		camera.fov = f.z
		_look(player, player.get_node("Head") as Node3D, SPOT + Vector3(0.0, f.w, 0.0))
		# Low, between lens and creature, so it lights the face, not the bed.
		face_light.global_position = camera.global_position.lerp(SPOT, 0.4) + Vector3(0.08, -0.02, 0.0)
		await _frames(20)
		_cover("cover_%d" % i)
	print("RESULT cover shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


## Turns the room down to night: lamps low, exposure down. Moonlight stays.
func _dim(main: Node) -> void:
	for lamp_name in ["LampPlayroom", "LampMain", "LampSide", "LampLanding"]:
		var lamp := main.get_node("House/" + lamp_name)
		lamp.set("light_energy", float(lamp.get("light_energy")) * LAMP_SCALE)
	# The moon comes in behind the bed; turned down, the gap underneath goes dark.
	var moon := main.get_node("Moonlight") as Light3D
	moon.light_energy *= MOON_SCALE
	var env := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.tonemap_exposure = EXPOSURE


## The title as a logo: marble text over a solid cream fill, a heavy plum
## outline and a soft drop shadow, so it reads at thumbnail size.
func _title() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	# The shadow sits a little lower than the logo itself.
	layer.add_child(_title_row(TITLE_TOP + SHADOW_DROP, [
		_title_text(Color(0.04, 0.01, 0.08, 0.55), Color(0.04, 0.01, 0.08, 0.55), TITLE_OUTLINE + 14),
	]))
	# A MarginContainer stacks its children: fill and outline, then the marble.
	var marble := UiStyle.label("Lost Marbles", TITLE_SIZE, UiStyle.CREAM)
	marble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.set_marble_drift(marble)
	layer.add_child(_title_row(TITLE_TOP, [
		_title_text(TITLE_FILL, TITLE_INK, TITLE_OUTLINE),
		marble,
	]))
	return layer


func _title_row(top: int, labels: Array) -> MarginContainer:
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.add_theme_constant_override("margin_top", top)
	for l: Label in labels:
		holder.add_child(l)
	return holder


func _title_text(fill: Color, ink: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = "Lost Marbles"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiStyle.font(700))
	l.add_theme_font_size_override("font_size", TITLE_SIZE)
	l.add_theme_color_override("font_color", fill)
	l.add_theme_color_override("font_outline_color", ink)
	l.add_theme_constant_override("outline_size", outline)
	return l


## Darkens the corners, so the eye goes to the creature in the middle.
func _vignette() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 5
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float strength = 0.75;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.26, 1.0);
	COLOR = vec4(0.02, 0.01, 0.07, smoothstep(0.3, 0.85, length(p)) * strength);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.material = mat
	layer.add_child(rect)
	return layer


## Depth and grade: the room behind goes soft, colours a touch richer.
func _polish(main: Node, camera: Camera3D) -> void:
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = DOF_FAR
	attrs.dof_blur_far_transition = 0.5
	attrs.dof_blur_amount = 0.08
	camera.attributes = attrs
	var env := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 1.2
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.8


func _hide_canvas(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		elif child is CanvasLayer:
			(child as CanvasLayer).visible = false


func _cover(shot_name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(COVER_SIZE.x, COVER_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png("%s/%s.png" % [OUT, shot_name])


func _look(player: Node3D, head: Node3D, target: Vector3) -> void:
	var dir: Vector3 = (target - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
