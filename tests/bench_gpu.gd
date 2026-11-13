extends Node
## Tool, not a test: times the GPU on the main room with the lamp swinging,
## under different graphics settings, and prints a table. Needs a real window:
## Godot --path . --resolution 1920x1080 res://tests/bench_gpu.tscn
##
## GPU time per frame is what limits frame rate on a slower graphics card,
## so that's what's measured (not frames per second, which V-Sync caps).

const WARMUP_FRAMES: int = 60
const MEASURE_FRAMES: int = 180

var _main: Node
var _env: Environment
var _lamp_body: RigidBody3D
var _lamp_lights: Array[OmniLight3D] = []
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
	player.global_position = Vector3(0.0, 0.05, 3.2)
	var dir: Vector3 = (Vector3(0.0, 1.6, -2.0) - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)
	_env = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	_lamp_body = _main.get_node("House/LampMain/Lamp")
	for lamp in ["House/LampMain/Lamp/Light", "House/LampSide/Lamp/Light"]:
		_lamp_lights.append(_main.get_node(lamp) as OmniLight3D)
	_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)
	await get_tree().create_timer(1.0).timeout

	var rows: Array = []
	rows.append(["As it is now (Ultra soft shadows, big lamp light, TAA, SSAO)", await _measure({})])
	rows.append(["Soft shadow filter: High instead of Ultra", await _measure({"filter": 4})])
	rows.append(["Soft shadow filter: Medium", await _measure({"filter": 3})])
	rows.append(["Soft shadow filter: Low", await _measure({"filter": 2})])
	rows.append(["Lamp light size 0 (no distance-softened shadows)", await _measure({"light_size": 0.0})])
	rows.append(["No TAA", await _measure({"taa": false})])
	rows.append(["No SSAO", await _measure({"ssao": false})])
	rows.append(["Shadow atlas 4096 instead of 8192", await _measure({"atlas": 4096})])
	rows.append(["No bloom", await _measure({"glow": false})])
	rows.append(["Lamps cast no shadows at all", await _measure({"lamp_shadows": false})])
	rows.append(["'Low' bundle: filter Low, size 0, no TAA, no SSAO, atlas 4096",
		await _measure({"filter": 2, "light_size": 0.0, "taa": false, "ssao": false, "atlas": 4096})])

	# The three Graphics > Lighting levels, as players get them.
	var saved: Settings.Lighting = Game.settings.lighting
	for level in [Settings.Lighting.HIGH, Settings.Lighting.MEDIUM, Settings.Lighting.LOW]:
		Game.settings.lighting = level
		rows.append(["Graphics > Lighting: %s" % Settings.LIGHTING_NAMES[level], await _measure_level()])
	Game.settings.lighting = saved
	Game.settings.apply_lighting(_main)

	print("\nGPU time per frame, %dx%d, lamp swinging:" % [get_viewport().size.x, get_viewport().size.y])
	var base: float = rows[0][1]
	for row: Array in rows:
		print("  %6.3f ms  %+5.0f%%   %s" % [row[1], (row[1] / base - 1.0) * 100.0, row[0]])
	get_tree().quit()


## Measures the current Graphics > Lighting level, applied the way the game
## applies it.
func _measure_level() -> float:
	_env.glow_enabled = true
	for light in _lamp_lights:
		light.shadow_enabled = true
	Game.settings.apply_lighting(_main)
	return await _sample()


## Applies the given changes on top of the game's own settings, keeps the lamp
## swinging, and returns the average GPU time per frame in milliseconds.
func _measure(changes: Dictionary) -> float:
	RenderingServer.positional_soft_shadow_filter_set_quality(changes.get("filter", 5))
	for light in _lamp_lights:
		light.light_size = changes.get("light_size", 0.25)
		light.shadow_enabled = changes.get("lamp_shadows", true)
	get_viewport().use_taa = changes.get("taa", true)
	_env.ssao_enabled = changes.get("ssao", true)
	_env.glow_enabled = changes.get("glow", true)
	get_viewport().positional_shadow_atlas_size = changes.get("atlas", 8192)
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	return await _sample()


## Keeps the lamp swinging and returns the average GPU time per frame (ms).
func _sample() -> float:
	var total: float = 0.0
	for i in WARMUP_FRAMES + MEASURE_FRAMES:
		# A nudge every half second keeps the lamp swinging, so its shadows
		# have to be redrawn every frame, as in play.
		if i % 30 == 0:
			_lamp_body.apply_central_impulse(Vector3(1.2 if (i / 30) % 2 == 0 else -1.2, 0.0, 0.6))
		await RenderingServer.frame_post_draw
		if i >= WARMUP_FRAMES:
			total += RenderingServer.viewport_get_measured_render_time_gpu(_rid)
	return total / MEASURE_FRAMES
