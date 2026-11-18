class_name SceneFade
extends CanvasLayer
## Fades to black, swaps the scene, then fades back in. The first frame of a
## freshly loaded scene is slow (instancing, shader compiles), and this keeps
## that stall hidden behind black, with "Loading…" on it, instead of showing
## as a freeze.
##
## Lives under the Game autoload so it survives the scene change it covers.

const OUT_TIME: float = 0.2
const IN_TIME: float = 0.35
## Frames to hold black after the swap, so the slow first frames land unseen.
const HOLD_FRAMES: int = 3
## Frames drawn with the black screen up before the swap starts, so "Loading…"
## is actually on screen during the stall (the swap blocks drawing).
const SHOW_FRAMES: int = 2
const MARGIN := Vector2(60.0, 50.0)

var _cover: ColorRect


## Fades out, changes to the scene at `path`, and fades in again. Ignored if a
## fade is already running, so a double click can't start two.
static func change_scene(path: String) -> void:
	for child in Game.get_children():
		if child is SceneFade:
			return
	var fade := SceneFade.new()
	Game.add_child(fade)
	fade._run(path)


func _init() -> void:
	layer = 128  # above every menu and the HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = ColorRect.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.color = Color.BLACK
	# Fading modulate (not color) fades the label with it.
	_cover.modulate.a = 0.0
	# Swallows clicks while it's up, so nothing behind gets pressed mid-fade.
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)

	var loading := UiStyle.label("Loading…", UiStyle.ROW_FONT_SIZE, UiStyle.CREAM_SOFT)
	loading.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	loading.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	loading.grow_vertical = Control.GROW_DIRECTION_BEGIN
	loading.offset_right = -MARGIN.x
	loading.offset_bottom = -MARGIN.y
	_cover.add_child(loading)


func _run(path: String) -> void:
	var tree := get_tree()
	# In a browser the game has one thread, and the first visit compiles its
	# shaders while the page draws nothing, so a tween can stall halfway. Go
	# straight to black there instead.
	if OS.has_feature("web"):
		_cover.modulate.a = 1.0
	else:
		await create_tween().tween_property(_cover, "modulate:a", 1.0, OUT_TIME).finished
	for i in SHOW_FRAMES:
		await tree.process_frame
	tree.change_scene_to_file(path)
	await tree.scene_changed
	for i in HOLD_FRAMES:
		await tree.process_frame
	await create_tween().tween_property(_cover, "modulate:a", 0.0, IN_TIME).finished
	queue_free()
