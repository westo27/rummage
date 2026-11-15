extends Node
## Renders the itch.io cover (630x500): the beam catching a creature out of
## playroom clutter, HUD hidden, the title on top. Takes a few frames along the
## catch so the best can be picked. Needs a real window (no --headless).
## Run: Godot --path . --resolution 1260x1000 res://tests/shoot_cover.tscn

const OUT: String = "user://shots"
const COVER_SIZE := Vector2i(630, 500)
const SPOT := Vector3(-3.5, 0.1, 0.9)  # where the creature is caught
const EYE := Vector3(-2.95, 0.05, 1.35)  # where the player stands


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var player := main.get_node("Player") as Node3D
	player.set_process_unhandled_input(false)
	(main.get_node("HUD") as CanvasLayer).visible = false
	_hide_canvas(main.get_node("Tutorial"))

	# Clutter gathered round the spot, so the creature comes out of a heap.
	var props := main.get_node("MainRoomProps")
	_put(props, "Teddy", SPOT + Vector3(0.35, 0.05, -0.25))
	_put(props, "ToyDinosaur", SPOT + Vector3(-0.35, 0.0, 0.1))
	_put(props, "ToyCar", SPOT + Vector3(0.3, -0.04, 0.3))
	_put(props, "FloorBlock1", SPOT + Vector3(-0.1, -0.07, -0.4))
	_put(props, "FloorBlock2", SPOT + Vector3(0.05, -0.07, 0.4))
	_put(props, "StackingRings", SPOT + Vector3(-0.45, 0.0, -0.3))

	player.global_position = EYE
	player.reset_physics_interpolation()
	await _frames(60)
	_look(player, player.get_node("Head") as Node3D, SPOT + Vector3(0.0, 0.55, 0.0))
	await _frames(30)

	var title := _title()
	add_child(title)
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
	(main.get_node("Player/Head/Camera3D/Beam") as Beam)._capture(creature)
	for i in 5:
		await get_tree().create_timer(0.04).timeout
		_cover("cover_%d" % i)
	print("RESULT cover shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


## The title in marble text across the top of the frame.
func _title() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.add_theme_constant_override("margin_top", 60)
	var label := UiStyle.label("Lost Marbles", 230, UiStyle.CREAM)
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
