extends Node
## Renders itch.io cover candidates (630x500), each a staged shot in the real
## bedroom: creatures are frozen and posed by hand, with their own lights,
## camera and grade per shot, the HUD hidden and the logo on top.
## Needs a real window (no --headless).
## Run: Godot --path . --resolution 1260x1000 res://tests/shoot_cover.tscn

const PressLogo = preload("res://tests/press_logo.gd")
const OUT: String = "user://shots"
const COVER_SIZE := Vector2i(630, 500)
const SEED: int = 3
## A creature's radius: posed on the floor, its centre sits this high.
const R: float = 0.054
const FAR := Vector3(0.0, -20.0, 0.0)

enum { PINK = 1, YELLOW = 2, BLUE = 3, PURPLE = 4, ORANGE = 5, GREEN = 0 }
const NORMAL := CreatureEyes.Mood.NORMAL
const WIDE := CreatureEyes.Mood.WIDE
const SQUINT := CreatureEyes.Mood.SQUINT
const HAPPY := CreatureEyes.Mood.HAPPY

var _main: Node
var _camera: Camera3D
var _env: Environment
var _pool: Array[Creature] = []
## Lights, logo and grade added for one shot, cleared before the next.
var _shot_nodes: Array[Node] = []
var _used: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Press images show the chosen faces.
	DoodleFace.only = DoodleFace.PRESS_FACES
	# The game opens fullscreen, which would render at the screen's shape and
	# squash every marble when scaled to the cover.
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = COVER_SIZE * 2
	DirAccess.make_dir_recursive_absolute(OUT)
	seed(SEED)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	# Every creature is frozen and parked out of sight until a shot poses it.
	for group in ["MainRoomCreatures", "SideRoomCreatures"]:
		for c in _main.get_node(group).get_children():
			if c is Creature:
				_pool.append(c as Creature)
	for c in _main.find_children("*", "Creature", true, false):
		if not c in _pool:
			_pool.append(c as Creature)
	for c in _pool:
		c.process_mode = Node.PROCESS_MODE_DISABLED
		(c.get_node("Glow") as Light3D).visible = false
	var player := _main.get_node("Player") as Node3D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	(_main.get_node("HUD") as CanvasLayer).visible = false
	for child in _main.get_node("Tutorial").get_children():
		if child is CanvasLayer or child is CanvasItem:
			child.set("visible", false)
	_env = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	_camera = Camera3D.new()
	_main.add_child(_camera)
	_camera.make_current()
	await _frames(20)

	# Name shots after `--` to render only those.
	var shots: Array[String] = ["crowd", "pile", "crate", "sill", "burst"]
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	if not wanted.is_empty():
		shots = shots.filter(func(s: String) -> bool: return s in wanted)
	var sheet := Image.create(COVER_SIZE.x, COVER_SIZE.y, false, Image.FORMAT_RGB8)
	for shot in shots:
		_reset()
		await call("_shot_" + shot)
		await _frames(45)  # TAA settles on a still frame
		var image: Image = get_viewport().get_texture().get_image()
		image.resize(COVER_SIZE.x, COVER_SIZE.y, Image.INTERPOLATE_LANCZOS)
		image.save_png("%s/cover_%s.png" % [OUT, shot])
		await _save_without_text(shot)
		# All of them at itch's browse size (315x250) on one sheet, to compare.
		image.convert(Image.FORMAT_RGB8)
		image.resize(COVER_SIZE.x / 2, COVER_SIZE.y / 2, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()),
				Vector2i(shots.find(shot) % 2, shots.find(shot) / 2) * image.get_size())
	if shots.size() > 1:
		sheet.save_png("%s/cover_sheet.png" % OUT)
	print("RESULT cover shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


# --- Shots -----------------------------------------------------------------

## A heap of marbles on the carpet, every one pulling a face at you, the
## room soft and dark behind.
func _shot_pile() -> void:
	_night(0.06, 0.3, 0.75)
	var base := Vector3(2.2, 0.0, -0.55)
	var spots: Array[Vector3] = _pyramid(base, 4)
	var away := Vector3(0.638, 0.0, 0.77)
	_place_camera(base + away * 1.0 + Vector3(0.0, 0.26, 0.0), base + Vector3(0.0, 0.25, 0.0), 32.0)
	_focus(1.05, 0.35, 0.12)
	var colours := [PINK, YELLOW, BLUE, PURPLE, ORANGE, GREEN]
	var moods := [NORMAL, NORMAL, WIDE, WIDE, WIDE, SQUINT]
	for i in spots.size():
		var top: bool = i == spots.size() - 1
		var c := _pose(spots[i], PINK if top else colours[(i * 5 + 2) % colours.size()],
				WIDE if top else moods.pick_random(), randf_range(0.0, 0.5))
		_turn(c, randf_range(-0.25, 0.25), randf_range(-0.35, 0.35))
		if not top and randf() < 0.15:
			_wink(c)
	# A few that rolled away, behind the heap and out of focus.
	for s: Array in [[Vector3(-0.35, 0.0, -0.45), YELLOW], [Vector3(0.42, 0.0, -0.6), BLUE],
			[Vector3(-0.05, 0.0, -0.9), ORANGE]]:
		_pose(base + s[0] + Vector3(0.0, R, 0.0), s[1], NORMAL, 0.4)
	_omni(_from_camera(Vector3(-0.5, 0.35, -0.1)), Color(1.0, 0.82, 0.62), 0.9, 2.0)  # key
	_omni(base - away * 0.45 + Vector3(0.1, 0.55, 0.0), Color(0.55, 0.62, 1.0), 1.4, 1.0)  # rim
	_grade(1.15, 1.3)
	_vignette(0.75)
	_logo(400, 30)


## The heap again, the moment the beam yanks one out of its bottom row: the
## grabbed one stretches toward your hand and the rest burst outward, every
## face still turned to you. No logo.
func _shot_burst() -> void:
	_night(0.06, 0.3, 0.75)
	var base := Vector3(2.2, 0.0, -0.55)
	var away := Vector3(0.638, 0.0, 0.77)
	var right: Vector3 = Vector3.UP.cross(away).normalized()
	_place_camera(base + away * 1.0 + Vector3(0.0, 0.26, 0.0), base + Vector3(0.0, 0.24, 0.0), 42.0)
	_focus(1.05, 0.35, 0.12)
	# A point near the heap: `x` to the right, `y` up, `z` toward the camera.
	var near := func(x: float, y: float, z: float) -> Vector3:
		return base + right * x + Vector3.UP * y + away * z
	var colours := [PINK, YELLOW, BLUE, PURPLE, ORANGE, GREEN]

	# What's left of the bottom row, the front one gone.
	var spots: Array[Vector3] = _pyramid(base, 4).slice(0, 10)
	var front: Vector3 = spots[0]
	for s in spots:
		if (s - base).dot(away) - absf((s - base).dot(right)) > (front - base).dot(away) - absf((front - base).dot(right)):
			front = s
	spots.erase(front)
	for i in spots.size():
		var c := _pose(spots[i], colours[(i * 5 + 2) % colours.size()], WIDE, 0.3)
		_turn(c, randf_range(-0.25, 0.25), randf_range(-0.35, 0.35))

	# The rest flung out from the hole, each with a streak behind it.
	var burst_from: Vector3 = near.call(0.0, 0.12, 0.05)
	var flyers := [[0.03, 0.47, 0.0, PINK], [-0.23, 0.38, 0.04, BLUE], [0.25, 0.4, -0.06, YELLOW],
		[-0.31, 0.19, 0.1, GREEN], [0.33, 0.22, 0.06, PURPLE], [0.1, 0.31, 0.16, ORANGE],
		[-0.11, 0.28, -0.16, YELLOW], [-0.37, 0.07, -0.08, PINK], [-0.2, 0.52, -0.1, BLUE],
		[-0.06, 0.18, 0.22, PURPLE]]
	for f: Array in flyers:
		var at: Vector3 = near.call(f[0], f[1], f[2])
		var c := _pose(at, f[3], WIDE, 0.6)
		_turn(c, randf_range(-0.35, 0.35), randf_range(-0.8, 0.8))
		_speed_lines(at, (at - burst_from).normalized(), randf_range(0.09, 0.16), Creature.BODY_COLORS[f[3]])

	# The grabbed one, pulled out toward your hand (off the bottom right of
	# the frame), stretched along the beam.
	var hand: Vector3 = _from_camera(Vector3(0.5, -0.45, -0.8))
	var grabbed_at: Vector3 = near.call(0.1, 0.13, 0.27)
	var grabbed := _pose(grabbed_at, PINK, WIDE, 0.0)
	_stretch(grabbed, (hand - grabbed_at).normalized(), 1.25)
	var beam := _main.get_node("Player/Head/Camera3D/Beam") as Node3D
	# Out from under the hidden player, so it can be seen.
	beam.process_mode = Node.PROCESS_MODE_DISABLED
	beam.reparent(_main)
	beam.set("_camera", _camera)
	var control: Vector3 = hand.lerp(grabbed_at, 0.5) + Vector3.UP * hand.distance_to(grabbed_at) * 0.12
	beam.call("_show_beam", hand, control, grabbed_at, Creature.BODY_COLORS[PINK], 0.4)
	_shot_nodes.append(beam)
	# Its lights are made for a whole room; here they'd flood the shot, and the
	# glow where it lands would hide the face.
	(beam.get("_end_light") as Light3D).light_energy *= 0.3
	(beam.get("_mid_light") as Light3D).light_energy *= 0.2
	(beam.get("_contact_glow") as Node3D).visible = false
	# Brighter than in play, to hold its own against the colours.
	(beam.get("_beam_material") as ShaderMaterial).set_shader_parameter("intensity", 3.5)

	_omni(_from_camera(Vector3(-0.5, 0.35, -0.1)), Color(1.0, 0.82, 0.62), 0.9, 2.0)  # key
	_omni(base - away * 0.45 + Vector3(0.1, 0.55, 0.0), Color(0.55, 0.62, 1.0), 1.4, 1.0)  # rim
	_grade(1.15, 1.3)
	_vignette(0.75)


## Close on one creature at floor level, the whole gang lined up behind it
## going soft into the dark, the playroom lamp glowing through the doorway.
func _shot_crowd() -> void:
	_night(0.25, 0.25, 0.75)
	var hero_at := Vector3(3.05, R, 0.02)
	_place_camera(Vector3(3.42, 0.075, 0.0), hero_at + Vector3(-0.6, 0.055, 0.0), 36.0)
	_focus(0.42, 0.25, 0.1)
	var hero := _pose(hero_at, PINK, WIDE)
	_turn(hero, -0.1, 0.12)
	var gang := [[Vector3(2.7, 0, -0.24), BLUE, NORMAL], [Vector3(2.66, 0, 0.27), YELLOW, WIDE],
		[Vector3(2.35, 0, -0.38), GREEN, WIDE], [Vector3(2.32, 0, 0.42), PURPLE, NORMAL],
		[Vector3(2.1, 0, 0.2), ORANGE, WIDE], [Vector3(2.0, 0, -0.2), YELLOW, SQUINT],
		[Vector3(1.75, 0, 0.5), BLUE, WIDE], [Vector3(1.7, 0, -0.55), PINK, NORMAL],
		[Vector3(1.6, 0, 0.02), PURPLE, WIDE], [Vector3(1.4, 0, -0.3), ORANGE, NORMAL],
		[Vector3(1.35, 0, 0.32), GREEN, WIDE]]
	for g: Array in gang:
		var c := _pose(g[0] + Vector3(0.0, R, 0.0), g[1], g[2], 0.3)
		_turn(c, randf_range(-0.2, 0.2), randf_range(-0.25, 0.25))
	_omni(_from_camera(Vector3(0.12, 0.08, -0.1)), Color(1.0, 0.8, 0.6), 0.45, 0.6)  # key
	_omni(hero_at + Vector3(-0.15, 0.15, 0.1), Color(0.55, 0.62, 1.0), 0.6, 0.35)  # rim
	_grade(1.15, 1.25)
	_vignette(0.8)
	_logo(400, 30)


## Hide and seek: three of them peeping over the rim of a toy crate, caught
## looking.
func _shot_crate() -> void:
	_night(0.25, 0.4, 0.75)
	var at := Vector3(2.6, 0.18, 0.05)
	var crate := _main.get_node("MainRoomProps/Bin02") as RigidBody3D
	crate.process_mode = Node.PROCESS_MODE_DISABLED
	crate.freeze = true
	# Upturned is how it hides things in the game; right way up, it's a crate.
	crate.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.1) * Basis(Vector3.RIGHT, PI), at)
	crate.reset_physics_interpolation()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.2, 0.5, 0.75)
	paint.roughness = 0.75
	for m in crate.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = paint
	# Looking back toward the playroom door, its lamp glowing soft behind.
	_place_camera(at + Vector3(1.12, 0.27, 0.04), at + Vector3(0.0, 0.22, 0.0), 34.0)
	_focus(1.2, 0.35, 0.1)
	var rim: float = at.y + 0.175
	var peeps := [[0.11, BLUE, WIDE, 0.0], [0.0, PINK, WIDE, 0.012], [-0.11, YELLOW, WIDE, -0.004]]
	for p: Array in peeps:
		var c := _pose(at + Vector3(0.0, rim - at.y + p[3] + 0.004, p[0]), p[1], p[2], 0.1)
		_turn(c, 0.0, randf_range(-0.2, 0.2))
	_omni(_from_camera(Vector3(-0.3, 0.3, -0.1)), Color(1.0, 0.8, 0.6), 0.8, 1.6)  # key
	_omni(at + Vector3(-0.2, 0.42, 0.0), Color(0.55, 0.62, 1.0), 0.8, 0.45)  # rim
	_grade(1.15, 1.25)
	_vignette(0.8)
	_logo(400, 30)


## A row of them sitting on the window sill against the night sky, as if
## they're waiting for you to look away.
func _shot_sill() -> void:
	_night(0.3, 0.5, 0.72)
	_place_camera(Vector3(2.6, 1.12, -1.45), Vector3(2.6, 1.46, -2.2), 42.0)
	_focus(0.85, 0.6, 0.05)
	var sill_y: float = 1.2 + R
	var line := [[YELLOW, NORMAL], [PURPLE, NORMAL], [GREEN, WIDE], [ORANGE, WIDE], [PINK, WIDE],
			[BLUE, NORMAL], [YELLOW, WIDE], [PURPLE, WIDE], [GREEN, NORMAL]]
	# Nearly touching, edge to edge across the frame: a line of them.
	for i in line.size():
		var x: float = 2.6 + (i - (line.size() - 1) * 0.5) * 0.118 + randf_range(-0.005, 0.005)
		var c := _pose(Vector3(x, sill_y, -2.16 + randf_range(-0.015, 0.015)), line[i][0], line[i][1], 0.1)
		_turn(c, randf_range(-0.2, 0.2), randf_range(-0.25, 0.25))
	# The moon behind still rims them, without a hot sparkle on every top.
	(_main.get_node("Moonlight") as Light3D).light_specular = 0.15
	_omni(Vector3(2.45, 1.2, -1.5), Color(1.0, 0.8, 0.6), 0.5, 1.2)
	_grade(1.15, 1.25)
	_vignette(0.75, 0.5, 0.22)
	_logo(400, 735)  # centred in the frame


# --- Staging -----------------------------------------------------------------

## Parks every creature again and clears the last shot's extras.
func _reset() -> void:
	for n in _shot_nodes:
		n.queue_free()
	_shot_nodes.clear()
	_used = 0
	for c in _pool:
		c.global_position = FAR
	(_main.get_node("Moonlight") as Light3D).light_specular = 0.5


## Lamps and moon turned down to night, and the exposure.
func _night(lamps: float, moon: float, exposure: float) -> void:
	# Every light the house has (ceiling lamps, the glow through their shades,
	# the bedside lamp), but not the ones a shot adds.
	for node in _main.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light in _shot_nodes or light.get_parent() is Creature:
			continue
		if not light.has_meta("energy"):
			light.set_meta("energy", light.light_energy)
		var scale: float = moon if light.name == "Moonlight" else lamps
		light.light_energy = float(light.get_meta("energy")) * scale
	_env.tonemap_exposure = exposure


## Takes the next creature from the pool and poses it: colour, mood, and its
## face and eyes turned to the camera (`stray` sends the pupils off a bit).
func _pose(at: Vector3, colour: int, mood: CreatureEyes.Mood, stray: float = 0.0) -> Creature:
	var c: Creature = _pool[_used]
	_used += 1
	c.global_position = at
	c.reset_physics_interpolation()
	var mat := (c.get_node("Visual/Body") as MeshInstance3D).material_override as ShaderMaterial
	mat.set_shader_parameter("tint", Creature.BODY_COLORS[colour])
	mat.set_shader_parameter("seed", randf())
	var visual := c.get_node("Visual") as Node3D
	visual.basis = Basis()
	visual.look_at(_camera.global_position, Vector3.UP)
	var eyes := _eyes(c)
	# Drawn faces show as drawn: their own mouths, not the startled "o".
	eyes.mood = CreatureEyes.Mood.NORMAL if c.face.drawn != null else mood
	eyes.set("_white_glow", CreatureEyes.WHITE_GLOW)
	var side := Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), 0.0) * stray * 0.5
	eyes.look_target = _camera.global_position + _camera.global_basis * side
	_refresh_eyes(c)
	return c


## Turns the face off square (yaw) and rolls it, radians.
func _turn(c: Creature, yaw: float, roll: float) -> void:
	var visual := c.get_node("Visual") as Node3D
	visual.basis = visual.basis * Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, roll)
	_refresh_eyes(c)


## Stretches it `k` times longer along `dir` (world space), thinner across,
## keeping its volume, like a creature being sucked into the beam.
func _stretch(c: Creature, dir: Vector3, k: float) -> void:
	var visual := c.get_node("Visual") as Node3D
	var thin: float = 1.0 / sqrt(k)
	var axes: Array[Vector3] = []
	for e: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		axes.append(e * thin + dir * dir.dot(e) * (k - thin))
	visual.basis = Basis(axes[0], axes[1], axes[2]) * visual.basis


## Cartoon speed lines: three thin streaks in the creature's colour behind
## it, against its flight `dir`, fading out `length` metres back. Each is a
## ribbon turned to face the camera, like the beam.
func _speed_lines(at: Vector3, dir: Vector3, length: float, colour: Color) -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 colour : source_color;
void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	// Faint at both ends, so the end by the creature doesn't bloom into it.
	float fade = smoothstep(0.0, 0.7, UV.y) * smoothstep(1.0, 0.75, UV.y);
	ALBEDO = mix(colour.rgb, vec3(1.0), 0.4) * (1.0 - across * across) * fade * 0.9;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("colour", colour)
	var eye: Vector3 = _camera.global_position
	var across: Vector3 = dir.cross(eye - at).normalized()
	var mesh := ImmediateMesh.new()
	for line: Vector2 in [Vector2(-0.6, 0.8), Vector2(0.0, 1.0), Vector2(0.6, 0.7)]:
		# Starting just behind its edge; the middle line longest.
		var head: Vector3 = at + across * R * line.x - dir * R * 1.3
		var tail: Vector3 = head - dir * length * line.y
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for t: float in [0.0, 1.0]:
			var side: Vector3 = across * lerpf(0.001, 0.0045, t)
			var point: Vector3 = tail.lerp(head, t)
			mesh.surface_set_uv(Vector2(0.0, t))
			mesh.surface_add_vertex(point - side)
			mesh.surface_set_uv(Vector2(1.0, t))
			mesh.surface_add_vertex(point + side)
		mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(node)


func _wink(c: Creature) -> void:
	var eyes := _eyes(c)
	eyes.set("_wink_eye", randi() % 2)
	eyes.set("_wink_left", CreatureEyes.WINK_SECONDS * 0.5)
	eyes.call("_update_shape", 0.0)
	eyes.call("_send_to_shader")


func _eyes(c: Creature) -> CreatureEyes:
	return c.get_node("Visual/Eyes") as CreatureEyes


## Lets every blend land at once: mood shape, look, no blink in progress.
func _refresh_eyes(c: Creature) -> void:
	var eyes := _eyes(c)
	eyes.set("_mood_left", 0.0)
	eyes.set("_next_blink", 1000.0)
	eyes.set("_blink_left", 0.0)
	eyes.set("_wink_left", 0.0)
	for i in 4:
		eyes.step(1.0)


## Close-packed heap, `n` to a side at the bottom, centred on `base`.
func _pyramid(base: Vector3, n: int) -> Array[Vector3]:
	var d: float = R * 2.0
	var out: Array[Vector3] = []
	for layer in n:
		var side: int = n - layer
		var lift := Vector3(d * 0.5, d * sqrt(2.0 / 3.0), d * sqrt(3.0) / 6.0) * layer
		for j in side:
			for i in side - j:
				var p := Vector3((i + j * 0.5) * d, R, -j * d * sqrt(3.0) / 2.0)
				p += Vector3(lift.x, lift.y, -lift.z)
				# Centre the bottom triangle on the base point.
				p += Vector3(-(n - 1) * d * 0.5, 0.0, (n - 1) * d * sqrt(3.0) / 6.0)
				out.append(base + p)
	return out


## A point given in the camera's own space (x right, y up, -z ahead).
func _from_camera(local: Vector3) -> Vector3:
	return _camera.global_transform * local


func _place_camera(from: Vector3, at: Vector3, fov: float) -> void:
	_camera.fov = fov
	_camera.look_at_from_position(from, at, Vector3.UP)
	_camera.reset_physics_interpolation()


## Sharp out to `far` metres, softening over `transition`; things nearer than
## a third of that blur too.
func _focus(far: float, transition: float, amount: float) -> void:
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = far
	attrs.dof_blur_far_transition = transition
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = far * 0.55
	attrs.dof_blur_near_transition = far * 0.3
	attrs.dof_blur_amount = amount
	_camera.attributes = attrs


func _omni(at: Vector3, colour: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	_add(light)
	light.global_position = at


func _grade(contrast: float, saturation: float) -> void:
	_env.adjustment_enabled = true
	_env.adjustment_contrast = contrast
	_env.adjustment_saturation = saturation
	_env.glow_enabled = true
	_env.glow_hdr_threshold = 2.2


func _add(node: Node) -> void:
	_main.add_child(node)
	_shot_nodes.append(node)


## The logo, centred, `top` pixels down.
func _logo(size: int, top: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	PressLogo.build(layer, size, top)
	_add(layer)


## The same shot again with no logo (and no shade behind it), as
## cover_<shot>_notext.png; the logo comes back after.
func _save_without_text(shot: String) -> void:
	var shown: Array[CanvasLayer] = []
	for n in _shot_nodes:
		if n is CanvasLayer and (n as CanvasLayer).layer == 10:
			(n as CanvasLayer).visible = false
			shown.append(n)
		elif n is CanvasLayer and (n as CanvasLayer).layer == 5:
			var rect := (n as CanvasLayer).get_child(0) as ColorRect
			(rect.material as ShaderMaterial).set_shader_parameter("title_at", -10.0)
	await _frames(4)
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(COVER_SIZE.x, COVER_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png("%s/cover_%s_notext.png" % [OUT, shot])
	for layer in shown:
		layer.visible = true


## Darkens the corners, so the eye goes to the middle, plus a soft band of
## shade behind the logo (centred `title_at` down the frame, `title_reach`
## either side) so it stands clear of the room.
func _vignette(strength: float, title_at: float = 0.0, title_reach: float = 0.42) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float strength = 0.75;
uniform float title_at = 0.0;
uniform float title_reach = 0.42;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.26, 1.0);
	float corners = smoothstep(0.3, 0.85, length(p)) * strength;
	float title = (1.0 - smoothstep(0.0, title_reach, abs(UV.y - title_at))) * 0.45;
	COLOR = vec4(0.02, 0.01, 0.07, max(corners, title));
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("title_at", title_at)
	mat.set_shader_parameter("title_reach", title_reach)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.material = mat
	layer.add_child(rect)
	_add(layer)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
