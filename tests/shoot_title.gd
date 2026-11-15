extends Node
## Renders the title screen at a few points along the backdrop's camera drift,
## to judge the framing. Needs a real window (no --headless).
## Run: Godot --path . --resolution 960x540 res://tests/shoot_title.tscn

const OUT: String = "user://shots"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var title: Control = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	var backdrop: TitleBackdrop = null
	for child in title.get_children():
		if child is TitleBackdrop:
			backdrop = child
	await _frames(30)
	# Quarter steps through one full sway of the drift.
	var sway: float = TAU / TitleBackdrop.DRIFT_RATE
	for i in 4:
		backdrop._time = sway * i / 4.0
		await _frames(6)
		get_viewport().get_texture().get_image().save_png("%s/title_drift%d.png" % [OUT, i])
	print("RESULT shot title_drift0-3")
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
