extends Node
## Close-up of five creatures in a row (normal, looking aside, wide, squint,
## happy), for checking the marble look and the eyes. Needs a real window.
## Run: Godot --path . --resolution 960x540 res://tests/shoot_creature.tscn -- [tag]
## Writes creatures_<tag>_<off|360p>.png to user://shots.

const OUT: String = "user://shots"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var tag: String = args[0] if args.size() > 0 else "now"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	var head := player.get_node("Head") as Node3D
	player.set_process_unhandled_input(false)
	await _frames(30)
	head.rotation.x = deg_to_rad(-20.0)
	await _frames(5)
	var cam := head.get_node("Camera3D") as Camera3D
	var creatures := main.get_node("MainRoomCreatures").get_children()
	var moods := [CreatureEyes.Mood.NORMAL, CreatureEyes.Mood.NORMAL, CreatureEyes.Mood.WIDE,
		CreatureEyes.Mood.SQUINT, CreatureEyes.Mood.HAPPY]
	var shown: Array[Creature] = []
	for i in moods.size():
		var c := creatures[i] as Creature
		c.set_physics_process(false)
		c.process_mode = Node.PROCESS_MODE_DISABLED
		var at: Vector3 = cam.global_transform * Vector3((i - 2) * 0.13, -0.05, -0.45)
		c.global_position = at
		c.reset_physics_interpolation()
		var visual := c.get_node("Visual") as Node3D
		visual.look_at(cam.global_position, Vector3.UP)
		var eyes := c.get_node("Visual/Eyes") as CreatureEyes
		eyes.show_mood(moods[i], 0.0)
		if i == 1:
			eyes.look_target = cam.global_transform * Vector3(-2.0, 0.6, -0.5)
		elif i != 4:
			eyes.look_target = cam.global_position
		for k in 60:
			eyes.step(1.0 / 60.0)
		shown.append(c)
	for v: Array in [["off", false, 3], ["360p", true, 2]]:
		Game.looks.set_look("", v[1], v[2])
		await _frames(20)
		get_viewport().get_texture().get_image().save_png("%s/creatures_%s_%s.png" % [OUT, tag, v[0]])
	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
