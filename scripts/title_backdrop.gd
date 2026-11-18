class_name TitleBackdrop
extends Node3D
## Behind the title menu: the real house at night, seen from low down across
## the bedroom floor toward the bed, with a slow drifting camera. The marbles
## hidden under the bed peek out and glint at the camera now and then.
##
## It loads main.tscn and removes everything that's about playing (the player,
## HUD, menus, lesson, ping) before adding it, so main.gd's game flow never runs.

const MainScript: GDScript = preload("res://scripts/main.gd")

## Nodes of main.tscn the title doesn't want.
const STRIP: Array[String] = ["Player", "HUD", "PauseMenu", "Tutorial", "Ping"]

## Where the camera floats (a child sitting on the bedroom rug) and what it
## looks at (the shadow under the bed, where four marbles hide).
const CAMERA_HOME := Vector3(2.3, 0.28, 0.1)
const LOOK_HOME := Vector3(2.4, 0.3, -1.75)
## How far the drift wanders (m), and how slowly: a full sway takes about a
## minute and a half, so it reads as breathing rather than moving.
const DRIFT := Vector3(0.22, 0.04, 0.12)
const LOOK_DRIFT := Vector3(0.2, 0.05, 0.0)
const DRIFT_RATE: float = 0.07

## Shaders the game uses that the title's house doesn't draw (see
## _warm_up_shaders), and how many frames they're drawn for.
const WARM_SHADERS: Array[String] = ["res://shaders/beam.gdshader",
	"res://shaders/beam_aura.gdshader", "res://shaders/glow_dot.gdshader",
	"res://shaders/glass_marble.gdshader"]
const WARM_FRAMES: int = 4

var _camera: Camera3D
## A stand-in for the player at the camera: creatures look at whatever's in the
## "player" group, so this makes their peeks land on you.
var _watcher: Node3D
var _head: Node3D
var _time: float = 0.0


func _ready() -> void:
	# Kept on Game so the house's materials and shaders outlive the title:
	# otherwise Play frees them and the game compiles them all over again.
	Game.main_scene = load("res://scenes/main.tscn")
	var house: Node3D = Game.main_scene.instantiate()
	for node_name in STRIP:
		var node := house.get_node_or_null(node_name)
		if node != null:
			house.remove_child(node)
			node.free()
	# The camera sits on the rug, and the marble hiding under it (out of shot)
	# twitches the cloth with every tell, which bobs the whole rug in the
	# foreground. Left out, the rug lies still.
	for node in house.find_children("*", "CharacterBody3D", true, false):
		if node.get("under_rug") == true:
			node.get_parent().remove_child(node)
			node.free()
	# Without its script the root is a plain Node3D, so none of the game flow
	# (counting catches, the timer, restart) runs.
	house.set_script(null)
	add_child(house)
	if WebDemo.active():
		WebDemo.strip(house)
		WebDemo.light(house)
	MainScript.set_up_world(house)
	Game.settings.apply_lighting(house)

	_watcher = Node3D.new()
	_watcher.name = "Watcher"
	_watcher.add_to_group("player")
	add_child(_watcher)
	_head = Node3D.new()
	_head.name = "Head"  # creature.gd looks for a child called Head
	_watcher.add_child(_head)

	_camera = Camera3D.new()
	_camera.fov = 58.0
	add_child(_camera)
	_camera.make_current()
	# Start somewhere random along the drift, so it isn't the same shot each time.
	_time = randf() * 60.0
	_place_camera()
	_face_the_camera()
	_warm_up_shaders()


## Draws the game's own shaders that the title never shows (the beam, its
## aura, the bag's glass marbles) on specks in front of the camera for a few
## frames, so they compile here rather than in the stall after Play, or on the
## first grab. Shaders compile on first draw; holding them on Game keeps them
## compiled after the title is gone.
func _warm_up_shaders() -> void:
	var specks := Node3D.new()
	_camera.add_child(specks)
	for path in WARM_SHADERS:
		var shader: Shader = load(path)
		if not shader in Game.kept:
			Game.kept.append(shader)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.002  # far too small to see
		var speck := MeshInstance3D.new()
		speck.mesh = quad
		speck.material_override = mat
		speck.position = Vector3(0.0, 0.0, -0.5)
		specks.add_child(speck)
	for i in WARM_FRAMES:
		await get_tree().process_frame
	specks.queue_free()


func _process(delta: float) -> void:
	_time += delta
	_place_camera()


func _place_camera() -> void:
	var t: float = _time * DRIFT_RATE
	# Sines at unrelated rates, so the path never quite repeats.
	var offset := Vector3(sin(t), sin(t * 1.7 + 1.0), sin(t * 0.6 + 2.0)) * DRIFT
	var look_offset := Vector3(sin(t * 0.8 + 0.5), sin(t * 1.3), 0.0) * LOOK_DRIFT
	_camera.global_position = CAMERA_HOME + offset
	_camera.look_at(LOOK_HOME + look_offset)
	_watcher.global_position = Vector3(_camera.global_position.x, 0.0, _camera.global_position.z)
	_head.global_position = _camera.global_position


## Turns every hidden marble's face toward the camera. In the game they face
## any which way, but here the eyes are the point, and hidden ones never turn.
func _face_the_camera() -> void:
	for creature: Creature in get_tree().get_nodes_in_group("creatures"):
		var visual := creature.get_node("Visual") as Node3D
		var toward := Vector3(CAMERA_HOME.x, visual.global_position.y, CAMERA_HOME.z)
		visual.look_at(toward, Vector3.UP)  # -Z, its face, toward the camera
