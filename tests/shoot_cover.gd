extends Node
## Renders the itch.io cover (630x500): the beam pulling a creature out from
## under the bed, HUD hidden, the title on top. Time is slowed to a crawl once
## the catch starts, so the beam reaches the creature while it's still by the
## bed; a few frames are saved to pick from. Needs a real window (no --headless).
## Run: Godot --path . --resolution 1260x1000 res://tests/shoot_cover.tscn

const OUT: String = "user://shots"
const COVER_SIZE := Vector2i(630, 500)
const SPOT := Vector3(2.45, 0.1, -1.17)  # at the bed's front edge, coming out
const EYE := Vector3(2.3, 0.05, 0.5)  # where the player stands
const LOOK_AT := Vector3(2.5, 0.3, -1.6)  # under the bed, just above the creature
const TITLE_SIZE: int = 290
const FOV: float = 42.0
const SEED: int = 2
## How far out the beam is held in each saved frame (1 = on the creature).
const REACHES: Array[float] = [0.55, 0.7, 0.8, 0.9, 1.0]

var _beam: Beam = null
var _reach: float = -1.0


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _beam != null and _reach >= 0.0:
		_beam._catch_started = Time.get_ticks_msec() / 1000.0 - _reach * Beam.CATCH_REACH_TIME


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Creature colours are random; a fixed seed keeps the cover the same each run.
	seed(SEED)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var player := main.get_node("Player") as Node3D
	player.set_process_unhandled_input(false)
	(main.get_node("HUD") as CanvasLayer).visible = false
	_hide_canvas(main.get_node("Tutorial"))

	# The slippers nudged into frame beside it.
	var props := main.get_node("MainRoomProps")
	_put(props, "SlipperL", SPOT + Vector3(-0.32, -0.06, 0.12))
	_put(props, "SlipperR", SPOT + Vector3(0.3, -0.06, 0.2))

	Input.action_press("crouch")  # a low view, level with the gap under the bed
	player.global_position = EYE
	player.reset_physics_interpolation()
	await _frames(60)
	# A narrower lens from further back: a bigger creature, same bed behind it.
	(player.get_node("Head/Camera3D") as Camera3D).fov = FOV
	_look(player, player.get_node("Head") as Node3D, LOOK_AT)
	await _frames(30)

	add_child(_title())
	# A pink one: the catch flash takes the creature's colour, and pink keeps
	# the room warm (a blue flash washes it cold).
	var creature: Creature = null
	for c in main.get_node("MainRoomCreatures").get_children():
		if c is Creature and (c as Creature).body_color == Creature.BODY_COLORS[1]:
			creature = c as Creature
			break
	creature.global_position = SPOT
	creature.reset_physics_interpolation()
	await _frames(3)
	_cover("cover_pre")
	_beam = main.get_node("Player/Head/Camera3D/Beam") as Beam
	_beam._capture(creature)
	# Slow the catch tween (game time) to a crawl so the creature stays round
	# by the bed while the sparkles spread.
	Engine.time_scale = 0.03
	# Hold the beam part-way out (its reach runs in real time): once its tip
	# lands on the creature, the tip's light blows the marble out to white.
	for i in REACHES.size():
		_reach = REACHES[i]
		# ignore_time_scale (4th arg): wait in real seconds.
		await get_tree().create_timer(0.12, true, false, true).timeout
		_cover("cover_%d" % i)
	Engine.time_scale = 1.0
	print("RESULT cover shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


## The title in marble text across the top of the frame.
func _title() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.add_theme_constant_override("margin_top", 30)
	# A dark, fat-outlined copy behind the marble text, so it reads against the
	# wallpaper at thumbnail size. A MarginContainer stacks its children.
	var shade := Label.new()
	shade.text = "Lost Marbles"
	shade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shade.add_theme_font_override("font", UiStyle.font(700))
	shade.add_theme_font_size_override("font_size", TITLE_SIZE)
	shade.add_theme_color_override("font_color", Color(0.12, 0.05, 0.12, 0.55))
	shade.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.12, 0.55))
	shade.add_theme_constant_override("outline_size", 36)
	holder.add_child(shade)
	var label := UiStyle.label("Lost Marbles", TITLE_SIZE, UiStyle.CREAM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.set_marble_drift(label)
	holder.add_child(label)
	layer.add_child(holder)
	return layer


func _put(props: Node, prop_name: String, at: Vector3) -> void:
	var p := props.get_node(prop_name) as RigidBody3D
	p.global_position = at
	p.linear_velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _hide_canvas(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		elif child is CanvasLayer:
			(child as CanvasLayer).visible = false


func _cover(shot_name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(COVER_SIZE.x, COVER_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png("%s/%s.png" % [OUT, shot_name])


func _look(player: Node3D, head: Node3D, target: Vector3) -> void:
	var dir: Vector3 = (target - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
