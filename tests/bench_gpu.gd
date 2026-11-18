extends Node
## Tool, not a test: times the GPU in the bedroom with the lamps swinging,
## under different graphics settings, and prints a table. Needs a real window:
## Godot --path . --resolution 1920x1080 res://tests/bench_gpu.tscn
##
## GPU time per frame is what limits frame rate on a slower graphics card,
## so that's what's measured (not frames per second, which V-Sync caps).

const WARMUP_FRAMES: int = 60
const MEASURE_FRAMES: int = 180

var _main: Node
var _env: Environment
var _lamps: Array[PendantLamp] = []
var _moon: SpotLight3D
var _rid: RID


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_main.get_node("Player").set_process_unhandled_input(false)
	var player := _main.get_node("Player") as Node3D
	var head := player.get_node("Head") as Node3D
	player.global_position = Vector3(2.6, 0.05, 1.55)
	var dir: Vector3 = (Vector3(2.6, 1.6, -2.15) - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)
	_env = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for lamp: PendantLamp in get_tree().get_nodes_in_group("lamps"):
		_lamps.append(lamp)
	_moon = _main.get_node("Moonlight") as SpotLight3D
	_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)
	await get_tree().create_timer(1.0).timeout

	var saved: Settings.Lighting = Game.settings.lighting
	var saved_filter: Array = [Game.settings.pixel_filter, Game.settings.soft_filter,
		Game.settings.pixel_strength]
	var rows: Array = []
	# The three Graphics > Lighting levels, as players get them.
	for level in [Settings.Lighting.HIGH, Settings.Lighting.MEDIUM, Settings.Lighting.LOW]:
		rows.append(["Graphics > Lighting: %s" % Settings.LIGHTING_NAMES[level], await _measure(level, {})])
	# High with one thing changed at a time.
	var high := Settings.Lighting.HIGH
	rows.append(["High, lamp softness 0.3 (Medium's)", await _measure(high, {"lamp_size": 0.3})])
	rows.append(["High, lamp softness 0.15", await _measure(high, {"lamp_size": 0.15})])
	rows.append(["High, shadow filter High not Ultra", await _measure(high, {"filter": RenderingServer.SHADOW_QUALITY_SOFT_HIGH})])
	rows.append(["High, shadow atlas 4096", await _measure(high, {"atlas": 4096})])
	rows.append(["High, moonlight hard-edged (size 0)", await _measure(high, {"moon_size": 0.0})])
	rows.append(["High, moonlight no shadow", await _measure(high, {"moon_shadow": false})])
	rows.append(["High, only the nearest lamp casts shadows", await _measure(high, {"nearest_only": true})])
	rows.append(["High, lamps cast no shadows", await _measure(high, {"lamp_shadows": false})])
	rows.append(["High, no SSAO", await _measure(high, {"ssao": false})])
	rows.append(["High, no TAA", await _measure(high, {"taa": false})])
	rows.append(["High, no bloom", await _measure(high, {"glow": false})])
	# Screen filters draw the 3D at their own resolution.
	var medium := Settings.Lighting.MEDIUM
	rows.append(["Medium, Soft filter, size 1", await _measure(medium, {"screen": [true, 1]})])
	rows.append(["Medium, Soft filter, size 2", await _measure(medium, {"screen": [true, 2]})])
	rows.append(["Medium, Pixel filter, size 1", await _measure(medium, {"screen": [false, 1]})])
	rows.append(["Medium, Pixel filter, size 3", await _measure(medium, {"screen": [false, 3]})])
	rows.append(["Low, Soft filter, size 1", await _measure(Settings.Lighting.LOW, {"screen": [true, 1]})])
	Game.settings.lighting = saved
	Game.settings.pixel_filter = saved_filter[0]
	Game.settings.soft_filter = saved_filter[1]
	Game.settings.pixel_strength = saved_filter[2]
	Game.settings.apply_pixel_filter()
	Game.settings.apply_lighting(_main)

	print("
GPU time per frame, %dx%d, lamps swinging:" % [get_viewport().size.x, get_viewport().size.y])
	var base: float = rows[0][1]
	for row: Array in rows:
		print("  %6.3f ms  %+5.0f%%   %s" % [row[1], (row[1] / base - 1.0) * 100.0, row[0]])
	get_tree().quit()


## Applies a Graphics > Lighting level the way the game does, then the given
## changes on top, and returns the average GPU time per frame (ms).
func _measure(level: Settings.Lighting, changes: Dictionary) -> float:
	Game.settings.lighting = level
	Game.settings.pixel_filter = changes.has("screen")
	if changes.has("screen"):
		Game.settings.soft_filter = changes.screen[0]
		Game.settings.pixel_strength = changes.screen[1]
	Game.settings.apply_pixel_filter()
	_env.glow_enabled = true
	_moon.shadow_enabled = true
	_moon.light_size = 0.4
	for lamp in _lamps:
		lamp.shadows_allowed = true
	Game.settings.apply_lighting(_main)
	if changes.has("filter"):
		RenderingServer.positional_soft_shadow_filter_set_quality(changes.filter)
	if changes.has("atlas"):
		get_viewport().positional_shadow_atlas_size = changes.atlas
	if changes.has("taa"):
		get_viewport().use_taa = changes.taa
	if changes.has("ssao"):
		_env.ssao_enabled = changes.ssao
	if changes.has("glow"):
		_env.glow_enabled = changes.glow
	if changes.has("moon_size"):
		_moon.light_size = changes.moon_size
	if changes.has("moon_shadow"):
		_moon.shadow_enabled = changes.moon_shadow
	var player_at: Vector3 = (_main.get_node("Player") as Node3D).global_position
	var nearest: PendantLamp = _lamps[0]
	for lamp in _lamps:
		if lamp.global_position.distance_to(player_at) < nearest.global_position.distance_to(player_at):
			nearest = lamp
	for lamp in _lamps:
		if changes.has("lamp_size"):
			lamp.light().light_size = changes.lamp_size
		if changes.get("lamp_shadows", true) == false or (changes.get("nearest_only", false) and lamp != nearest):
			lamp.shadows_allowed = false
	return await _sample()


## Keeps the lamps swinging and returns the average GPU time per frame (ms).
func _sample() -> float:
	var total: float = 0.0
	for i in WARMUP_FRAMES + MEASURE_FRAMES:
		# A nudge every half second keeps the lamps swinging, so their shadows
		# have to be redrawn every frame, as in play.
		if i % 30 == 0:
			for lamp in _lamps:
				(lamp.get_node("Lamp") as RigidBody3D).apply_central_impulse(
					Vector3(1.2 if (i / 30) % 2 == 0 else -1.2, 0.0, 0.6))
		await RenderingServer.frame_post_draw
		if i >= WARMUP_FRAMES:
			total += RenderingServer.viewport_get_measured_render_time_gpu(_rid)
	return total / MEASURE_FRAMES
