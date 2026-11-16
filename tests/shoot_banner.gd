extends Node
## Renders the itch page theme images:
## - banner.png: the logo alone on a transparent background, at most 900 wide
##   (itch shows the banner at its own size, up to the 960 px page column).
## - background.png: a seamless tile of jumbled marble creatures pulling all
##   their faces, on the night plum, for itch to repeat behind the page.
## Needs a real window (no --headless).
## Run: Godot --path . --resolution 1920x1080 res://tests/shoot_banner.tscn

const PressLogo = preload("res://tests/press_logo.gd")
const CreatureScene: PackedScene = preload("res://scenes/creature.tscn")
const OUT: String = "user://shots"
const BANNER_WIDTH: int = 900
## The logo's size as the cover draws it at 1260x1000; at 1920x1080 it comes
## out bigger than the banner, then is scaled down, for clean edges.
const LOGO_SIZE: int = 420

const TILE: int = 640
const COUNT: int = 32
const SEED: int = 7
## Each marble is rendered alone at this size, then scaled to its spot in the
## tile; drawn big and shrunk, its edge comes out smooth.
const SPRITE: int = 256
## Smallest and largest marble across, in tile pixels.
const SIZE_MIN: float = 70.0
const SIZE_MAX: float = 125.0
## How close two marbles may sit, as a share of their combined radii: a
## little under 1, so they jostle without hiding each other's faces.
const SPACING: float = 0.86
const NIGHT := Color(0.06, 0.03, 0.11)
## How far the finished tile is pulled toward NIGHT, so the page text over it
## stays the thing you read.
const DIM: float = 0.2
const SHADOW_DROP := Vector2i(5, 8)

## Faces: mood, a wink, and how far the pupils wander off straight ahead.
const FACES: Array = [
	[CreatureEyes.Mood.NORMAL, false, 0.0],
	[CreatureEyes.Mood.NORMAL, false, 1.0],
	[CreatureEyes.Mood.WIDE, false, 0.3],
	[CreatureEyes.Mood.SQUINT, false, 0.8],
	[CreatureEyes.Mood.HAPPY, false, 0.0],
	[CreatureEyes.Mood.NORMAL, true, 0.4],
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await _banner()
	await _background()
	print("RESULT banner and background in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


## Drawn on the window itself with its background cleared to transparent, so
## the logo matches the cover exactly and the PNG keeps its alpha.
func _banner() -> void:
	get_viewport().transparent_bg = true
	var layer := CanvasLayer.new()
	add_child(layer)
	PressLogo.build(layer, LOGO_SIZE, 40)
	await _frames(10)
	var image: Image = get_viewport().get_texture().get_image()
	# Trim the empty margin, then scale to the banner width.
	image = image.get_region(image.get_used_rect().grow(8))
	var h: int = roundi(image.get_height() * float(BANNER_WIDTH) / image.get_width())
	image.resize(BANNER_WIDTH, h, Image.INTERPOLATE_LANCZOS)
	image.save_png("%s/banner.png" % OUT)
	layer.queue_free()
	get_viewport().transparent_bg = false


## Each marble is rendered on its own as a cut-out, then pasted into the tile.
## Pasting is what makes it repeat cleanly: one hanging over an edge is pasted
## again a tile away, so its other half shows on the opposite side.
func _background() -> void:
	seed(SEED)
	var spots: Array = _scatter()
	var stage := _stage()
	var view: SubViewport = stage[0]
	var creature: Creature = stage[1]
	var tile := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	tile.fill(NIGHT)
	for spot: Vector3 in spots:
		await _pose(creature)
		var sprite: Image = view.get_texture().get_image()
		sprite.convert(Image.FORMAT_RGBA8)
		var size: int = roundi(spot.z)
		sprite.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var at := Vector2i(roundi(spot.x - size * 0.5), roundi(spot.y - size * 0.5))
		_paste_wrapped(tile, _shadow(sprite), at + SHADOW_DROP)
		_paste_wrapped(tile, sprite, at)
	view.queue_free()
	tile.convert(Image.FORMAT_RGB8)
	for y in TILE:
		for x in TILE:
			tile.set_pixel(x, y, tile.get_pixel(x, y).lerp(NIGHT, DIM))
	tile.save_png("%s/background.png" % OUT)


## Random spots (x, y, diameter), kept apart, with distances measured round
## the tile's edges so neighbours across a seam don't pile up either.
func _scatter() -> Array:
	var spots: Array = []
	var tries: int = 0
	while spots.size() < COUNT and tries < 5000:
		tries += 1
		var s := Vector3(randf() * TILE, randf() * TILE, randf_range(SIZE_MIN, SIZE_MAX))
		var clear := true
		for o: Vector3 in spots:
			var d := Vector2(absf(s.x - o.x), absf(s.y - o.y))
			d = Vector2(minf(d.x, TILE - d.x), minf(d.y, TILE - d.y))
			if d.length() < (s.z + o.z) * 0.5 * SPACING:
				clear = false
				break
		if clear:
			spots.append(s)
	# Smaller ones first, so the big ones sit on top where they overlap.
	spots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)
	return spots


## A little world of its own: one creature, a key light from the upper left,
## and a camera square on, all on a transparent background.
func _stage() -> Array:
	var view := SubViewport.new()
	view.size = Vector2i(SPRITE, SPRITE)
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.75)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	view.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.75)
	key.light_energy = 1.5
	view.add_child(key)
	key.look_at_from_position(Vector3(-1.0, 1.2, -1.5), Vector3.ZERO)

	var creature := CreatureScene.instantiate() as Creature
	view.add_child(creature)
	# Only its looks are wanted: no hiding, fleeing or squeaking.
	creature.process_mode = Node.PROCESS_MODE_DISABLED
	(creature.get_node("Glow") as Light3D).visible = false
	# The face looks down -Z, so the camera sits on that side looking back.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.112  # the ball's 0.108 m, plus a hair for its soft edge
	view.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, -1.0), Vector3.ZERO)
	camera.make_current()
	return [view, creature]


## A random colour, a random face and a random tilt, then let it render.
func _pose(creature: Creature) -> void:
	var body := creature.get_node("Visual/Body") as MeshInstance3D
	var mat := body.material_override as ShaderMaterial
	mat.set_shader_parameter("tint", Creature.BODY_COLORS.pick_random())
	mat.set_shader_parameter("seed", randf())
	var visual := creature.get_node("Visual") as Node3D
	# Turned a little off square, and rolled, so the faces sit at all angles.
	visual.basis = Basis(Vector3.BACK, randf_range(-0.6, 0.6)) \
		* Basis(Vector3.UP, randf_range(-0.35, 0.35)) * Basis(Vector3.RIGHT, randf_range(-0.3, 0.3))
	var face: Array = FACES.pick_random()
	var eyes := creature.get_node("Visual/Eyes") as CreatureEyes
	eyes.mood = face[0]
	eyes._mood_left = 0.0
	eyes._next_blink = 1000.0
	eyes._blink_left = 0.0
	eyes._wink_left = 0.0
	var wander: float = face[2]
	var ahead: Vector3 = -visual.global_basis.z
	var side := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * wander
	eyes.look_target = creature.global_position + ahead + visual.global_basis * side
	for i in 4:
		eyes.step(1.0)  # a full second each: every blend lands
	if face[1]:
		eyes._wink_eye = randi() % 2
		eyes._wink_left = CreatureEyes.WINK_SECONDS * 0.5  # the wink at its tightest
		eyes._update_shape(0.0)
		eyes._send_to_shader()
	await _frames(3)


## The marble's outline, soft and dark, to lay underneath it.
func _shadow(sprite: Image) -> Image:
	var size: int = sprite.get_width()
	var shade := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			shade.set_pixel(x, y, Color(0.0, 0.0, 0.02, sprite.get_pixel(x, y).a * 0.5))
	shade.resize(maxi(size / 6, 1), maxi(size / 6, 1), Image.INTERPOLATE_BILINEAR)
	shade.resize(size, size, Image.INTERPOLATE_CUBIC)
	return shade


func _paste_wrapped(tile: Image, sprite: Image, at: Vector2i) -> void:
	var rect := Rect2i(Vector2i.ZERO, sprite.get_size())
	for dy in [-TILE, 0, TILE]:
		for dx in [-TILE, 0, TILE]:
			tile.blend_rect(sprite, rect, at + Vector2i(dx, dy))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
