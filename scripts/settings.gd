class_name Settings
extends RefCounted
## The player's own preferences, saved between runs.
##
## Separate from Tunables: tunables are design numbers you tweak while making
## the game, these are choices the player makes and expects to stick. They live
## in `user://settings.cfg`, which on Windows is under %APPDATA%/Godot/app_userdata.
##
## Held by the Game autoload as `Game.settings`, so it survives scene reloads.

## Fired by apply_pixel_filter, for parts of the UI drawn in the same style
## (the marble bag).
signal pixel_filter_changed

const PATH: String = "user://settings.cfg"

## Look sensitivity as a whole number of steps, which is what the menu shows.
## Multiplied by SENSITIVITY_PER_STEP to get radians of turn per mouse pixel.
const SENSITIVITY_PER_STEP: float = 0.00005
const SENSITIVITY_MIN: int = 1
const SENSITIVITY_MAX: int = 24
## Volume as a percentage, in steps of 5.
const VOLUME_STEP: int = 5

## Graphics > Lighting: how much GPU time the lamps' shadows get. They're
## most of the game's GPU cost (see tests/bench_gpu.tscn), so this is the
## one quality setting.
##   HIGH    soft shadows that blur more the further they fall (the lamp has
##           a size), filtered at Ultra, with TAA to smooth their grain;
##           High-quality full-resolution SSAO
##   MEDIUM  the same with a smaller lamp and Medium filtering: about a third
##           cheaper, still soft
##   LOW     shadows given a plain, even blur instead, no corner shading
##           (SSAO), FXAA instead of TAA: about a quarter of High's cost
enum Lighting { LOW, MEDIUM, HIGH }
const LIGHTING_NAMES: Array[String] = ["Low", "Medium", "High"]
## Pixel filter strength. Step n makes the screen 1080 / (n + 1) chunky pixels
## tall: 1 is 540 rows (subtle), 3 is 270, 8 is 120 (very chunky).
const PIXEL_STRENGTH_MIN: int = 1
const PIXEL_STRENGTH_MAX: int = 8
## Graphics > Screen filter, as the menu steps through it.
enum ScreenFilter { OFF, PIXEL, SOFT }
const SCREEN_FILTER_NAMES: Array[String] = ["Off", "Pixel", "Soft"]

var sensitivity_step: int = 8
var volume_percent: int = 80
## When on, moving the mouse down looks up, as in a flight sim.
var invert_look: bool = false
## Medium by default, so the game runs well on most machines out of the box
## (Low in a browser or on integrated graphics: see _init).
var lighting: Lighting = Lighting.MEDIUM
## Graphics > Pixel filter: the chunky low-resolution look (see pixel_filter.gd).
## On by default at the finest size; strength is how big the pixels are.
var pixel_filter: bool = true
var pixel_strength: int = 1
## Draws the filter soft (smoothly upscaled, like an old TV) instead of in
## square pixels. Pixel size sets the resolution of both.
var soft_filter: bool = false

var _loaded_from_disk: bool = false


func _init() -> void:
	# Seed the default from the tunable, so there's one place to change what a
	# brand-new player gets.
	sensitivity_step = clampi(
		int(round(Game.tune.mouse_sensitivity / SENSITIVITY_PER_STEP)),
		SENSITIVITY_MIN, SENSITIVITY_MAX)
	# Weak setups start on Low: a browser (the basic renderer on one thread,
	# fewer shaders to compile on a first visit) and integrated graphics (which
	# shares the PC's RAM). A saved choice still wins.
	if OS.has_feature("web") or \
			RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		lighting = Lighting.LOW


## Radians of turn per pixel of mouse movement, what player.gd actually uses.
func mouse_sensitivity() -> float:
	return sensitivity_step * SENSITIVITY_PER_STEP


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # no file yet: first run, keep the defaults
	sensitivity_step = clampi(int(cfg.get_value("look", "sensitivity_step", sensitivity_step)),
		SENSITIVITY_MIN, SENSITIVITY_MAX)
	invert_look = bool(cfg.get_value("look", "invert", invert_look))
	volume_percent = clampi(int(cfg.get_value("audio", "volume_percent", volume_percent)), 0, 100)
	lighting = clampi(int(cfg.get_value("graphics", "lighting", lighting)), 0, 2) as Lighting
	pixel_filter = bool(cfg.get_value("graphics", "pixel_filter", pixel_filter))
	pixel_strength = clampi(int(cfg.get_value("graphics", "pixel_strength", pixel_strength)),
		PIXEL_STRENGTH_MIN, PIXEL_STRENGTH_MAX)
	soft_filter = bool(cfg.get_value("graphics", "soft_filter", soft_filter))
	_loaded_from_disk = true


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "sensitivity_step", sensitivity_step)
	cfg.set_value("look", "invert", invert_look)
	cfg.set_value("audio", "volume_percent", volume_percent)
	cfg.set_value("graphics", "lighting", lighting)
	cfg.set_value("graphics", "pixel_filter", pixel_filter)
	cfg.set_value("graphics", "pixel_strength", pixel_strength)
	cfg.set_value("graphics", "soft_filter", soft_filter)
	cfg.save(PATH)


## Pushes the audio setting into the mixer. The look settings are read live by
## player.gd, so they need no applying.
func apply_audio() -> void:
	# Bus 0 is "Master". Volume is in decibels, a logarithmic scale, so a
	# percentage has to be converted rather than used directly.
	var bus: int = AudioServer.get_bus_index("Master")
	if volume_percent <= 0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(volume_percent / 100.0))


func adjust_sensitivity(by: int) -> void:
	sensitivity_step = clampi(sensitivity_step + by, SENSITIVITY_MIN, SENSITIVITY_MAX)


func adjust_volume(by: int) -> void:
	volume_percent = clampi(volume_percent + by * VOLUME_STEP, 0, 100)
	apply_audio()


func adjust_lighting(by: int) -> void:
	lighting = clampi(lighting + by, 0, 2) as Lighting


func adjust_pixel_strength(by: int) -> void:
	pixel_strength = clampi(pixel_strength + by, PIXEL_STRENGTH_MIN, PIXEL_STRENGTH_MAX)


func screen_filter() -> ScreenFilter:
	if not pixel_filter:
		return ScreenFilter.OFF
	return ScreenFilter.SOFT if soft_filter else ScreenFilter.PIXEL


## Steps Off -> Pixel -> Soft, wrapping round at either end.
func step_screen_filter(by: int) -> void:
	var mode: int = posmod(screen_filter() + by, ScreenFilter.size())
	pixel_filter = mode != ScreenFilter.OFF
	if pixel_filter:
		soft_filter = mode == ScreenFilter.SOFT


## How many low-res pixels tall the screen is at the current strength.
## Soft steps from a finer start: 720, 480 (a Wii's), 360, ...
func pixel_rows() -> float:
	return (1440.0 if soft_filter else 1080.0) / (pixel_strength + 1)


## Texels per metre on the room's surfaces (wallpaper, floor, rug, pictures)
## while the filter is on, so their patterns read as pixel art too.
const PIXEL_TEXELS_PER_METRE: float = 32.0


func apply_pixel_filter() -> void:
	Game.pixel_filter.visible = pixel_filter
	Game.pixel_filter.set_soft(soft_filter)
	Game.pixel_filter.set_rows(pixel_rows())
	# Texel-snapped patterns only suit square pixels; Soft keeps them smooth.
	RenderingServer.global_shader_parameter_set("pixel_texels",
		PIXEL_TEXELS_PER_METRE if pixel_filter and not soft_filter else 0.0)
	apply_render_scale()
	pixel_filter_changed.emit()


## With a filter on, the 3D is drawn at the filter's resolution and stretched
## to the window (the HUD and menus are 2D, so they stay sharp). That's where
## the filter saves GPU time: shadows, SSAO and TAA all cost per pixel drawn.
## Called again when the window changes size.
func apply_render_scale() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.scaling_3d_scale = render_scale(tree.root.size.y)
	if tree.current_scene != null:
		var world := tree.current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if world != null:
			match_glow(world.environment)


## Glow levels are blurs a set number of *rendered* pixels wide, so at a lower
## 3D resolution the bloom would spread wider across the screen. Each halving
## of the resolution moves the weights down one level to keep it the same
## size. The scene's own levels are remembered on the environment as metadata
## the first time.
func match_glow(env: Environment) -> void:
	if not env.has_meta("base_glow_levels"):
		var levels: Array[float] = []
		for i in 7:
			levels.append(env.get_glow_level(i))
		env.set_meta("base_glow_levels", levels)
	var base: Array = env.get_meta("base_glow_levels")
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var shift: int = maxi(0, roundi(log(1.0 / root.scaling_3d_scale) / log(2.0)))
	for i in 7:
		env.set_glow_level(i, base[i + shift] if i + shift < 7 else 0.0)


## The 3D resolution as a fraction of the window's, for a window `height`
## pixels tall. Pixel mode draws two pixels across each chunky block: with
## only one, Godot's rounding of the render size lets the block's sample land
## between two drawn pixels and the picture smears.
func render_scale(height: float) -> float:
	if not pixel_filter or height <= 0.0:
		return 1.0
	if soft_filter:
		return clampf(pixel_rows() / height, 0.1, 1.0)
	return minf(1.0, 2.0 / maxf(1.0, round(height / pixel_rows())))


## Puts the lighting setting into effect. The renderer-wide parts (shadow
## filtering, anti-aliasing, shadow resolution) apply straight away; the
## parts that live in a level (its lamps and its WorldEnvironment) apply to
## `scene` if one is given. main.gd calls this when a level loads, and the
## settings page calls it when the setting changes.
func apply_lighting(scene: Node = null) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var low: bool = lighting == Lighting.LOW
	var high: bool = lighting == Lighting.HIGH
	RenderingServer.positional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_ULTRA if high
		else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	var viewport: Viewport = tree.root
	viewport.use_taa = not low
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if low else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.positional_shadow_atlas_size = 4096
	# SSAO quality is global (all environments). High samples more, at full
	# resolution; Medium is Godot's default (half resolution). Low turns it off below.
	RenderingServer.environment_set_ssao_quality(
		RenderingServer.ENV_SSAO_QUALITY_HIGH if high else RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
		not high, 0.5, 2, 50.0, 300.0)
	if scene == null:
		return
	for lamp: PendantLamp in tree.get_nodes_in_group("lamps"):
		# Light size makes shadows soften with distance; plain blur is the
		# cheap stand-in on Low.
		lamp.set_shadow_softness(0.45 if high else 0.3 if not low else 0.0, 6.0 if low else 3.0)
	# Searched for, because on the title screen the room sits a few levels down.
	var world := scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world != null:
		world.environment.ssao_enabled = not low
		match_glow(world.environment)
