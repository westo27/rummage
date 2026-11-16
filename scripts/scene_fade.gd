class_name SceneFade
extends CanvasLayer
## Fades to black, swaps the scene, then fades back in. The first frame of a
## freshly loaded scene is slow (instancing, shader compiles), and this keeps
## that stall hidden behind black instead of showing as a freeze.
##
## Lives under the Game autoload so it survives the scene change it covers.

const OUT_TIME: float = 0.2
const IN_TIME: float = 0.35
## Frames to hold black after the swap, so the slow first frames land unseen.
const HOLD_FRAMES: int = 3

var _rect: ColorRect


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
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	# Swallows clicks while it's up, so nothing behind gets pressed mid-fade.
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rect)


func _run(path: String) -> void:
	var tree := get_tree()
	await create_tween().tween_property(_rect, "color:a", 1.0, OUT_TIME).finished
	tree.change_scene_to_file(path)
	await tree.scene_changed
	for i in HOLD_FRAMES:
		await tree.process_frame
	await create_tween().tween_property(_rect, "color:a", 0.0, IN_TIME).finished
	queue_free()
