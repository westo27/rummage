extends Node
## Headless check for the room's new parts: the window holds things in, the
## props are glossy, the bedside lamp stands on its table, the table's
## drawer and the chest's drawers slide out and back by physics, the wardrobe doors swing open, and
## pictures come off the wall to show what's behind, and the rug in front of
## the bed drags away. (How the room looks can only be judged in
## tests/shoot.tscn's pictures.) Not part of the game.
## Run: Godot --headless --path . res://tests/check_room.tscn

## Props placed on floors, tables, the desk and the chest. Each must come to
## rest where it was put, not slide off, roll away or fall over.
## (Not the floor cushion: it sits propped on a hidden marble.)
const SMALL_THINGS: Array[String] = ["Teddy", "ToyCar", "StackingRings", "ToyDrum",
	"ShapeSorter", "ToyDinosaur", "AlarmClock", "DeskGlobe", "PencilPot",
	"Mug", "SlipperL", "SlipperR", "SchoolBag", "ShoeBoxLow", "ShoeBoxHigh",
	"FoldedJumpers", "PiggyBank"]

var _failures: int = 0
var _main: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	var placed: Dictionary = {}
	for prop_name in SMALL_THINGS:
		placed[prop_name] = (_main.get_node("MainRoomProps/" + prop_name) as Node3D).global_position
	await _wait(1.0)

	# --- The small household things settle where they were put ---
	var drifted: Array[String] = []
	for prop_name: String in placed:
		var prop := _main.get_node("MainRoomProps/" + prop_name) as Node3D
		var upright: float = prop.global_basis.y.normalized().dot(Vector3.UP)
		if prop.global_position.distance_to(placed[prop_name]) > 0.03 or upright < 0.97:
			drifted.append("%s moved %.3f m, upright %.2f" % [prop_name,
				prop.global_position.distance_to(placed[prop_name]), upright])
	_check("the small household things stay where they were put", drifted.is_empty(), ", ".join(drifted))

	# --- A ball flung at the window stays in the room ---
	var ball: Prop = _main.get_node("MainRoomProps/BallFloor")
	ball.global_position = Vector3(2.6, 1.75, -1.2)  # above the bed, in front of the window
	ball.linear_velocity = Vector3(0.0, 0.0, -15.0)  # straight at the window, hard
	ball.sleeping = false
	ball.reset_physics_interpolation()
	await _wait(1.5)
	_check("a ball thrown at the window bounces back into the room",
		ball.global_position.z > -2.25, "z = %.2f (wall at -2.25)" % ball.global_position.z)

	# --- Wooden props are matte ---
	var crate_mesh := _main.get_node("MainRoomProps/Bookcase").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var crate_material := crate_mesh.material_override as StandardMaterial3D
	_check("wooden props have a matte finish",
		is_equal_approx(crate_material.roughness, 0.72) and not crate_material.clearcoat_enabled,
		"roughness %.2f, clearcoat %s" % [crate_material.roughness, crate_material.clearcoat_enabled])

	# --- The bedside lamp is its own object, standing on the table ---
	var lamp: Prop = _main.get_node("MainRoomProps/BedsideLamp")
	_check("the lamp stands on the bedside table",
		absf(lamp.global_position.y - 0.652) < 0.03 and lamp.global_basis.y.y > 0.99,
		"y = %.3f, upright %.2f" % [lamp.global_position.y, lamp.global_basis.y.y])

	# --- The bedside table's drawer slides on its runner by physics alone ---
	var table: Node = _main.get_node("MainRoomProps/BedsideTable")
	var drawer: Prop = table.drawer
	var inside: int = 0
	for i in 4:
		var block := _main.get_node("MainRoomProps/DrawerBlock%d" % (i + 1)) as Node3D
		if absf(drawer.to_local(block.global_position).y + 0.035) < 0.03:
			inside += 1
	_check("four blocks sit in the shut drawer", inside == 4, "%d inside" % inside)
	_check("the drawer rests shut", absf(table.drawer_out()) < 0.005, "%.3f m out" % table.drawer_out())
	# The drawer is a prop of its own: the beam can take hold of it.
	var beam: Beam = _main.get_node("Player/Head/Camera3D/Beam")
	var player := _main.get_node("Player") as Node3D
	player.global_position = drawer.global_position + Vector3(0.5, -0.3, 1.5)  # within reach
	player.reset_physics_interpolation()
	beam._grab_armed = true
	beam._grab(drawer, drawer.global_position)
	await _wait(0.2)
	_check("the beam can grab the drawer", beam.held == drawer, "held=%s" % beam.held)
	beam._release()
	await _wait(0.5)

	# --- Yanking the drawer up doesn't lift the table: it's fixed furniture ---
	var table_body := table as Prop
	var moved: float = await _yank_drawer(beam, player, table_body, drawer)
	_check("yanking the drawer up leaves the table where it is", moved < 0.01, "moved %.3f m" % moved)
	_check("and the table stays fixed afterwards", table_body.freeze, "freeze=%s" % table_body.freeze)

	# --- Wardrobe doors swing on hinges; the wardrobe itself stays put ---
	var wardrobe: Node = _main.get_node("MainRoomProps/Wardrobe")
	var door: Prop = wardrobe.get_node("DoorA")
	var hidden_inside := _main.get_node("MainRoomCreatures/InWardrobe1") as Creature
	var wardrobe_at: Vector3 = wardrobe.global_position
	_check("the wardrobe doors start shut", wardrobe.door_angle("DoorA") < 0.05 and wardrobe.door_angle("DoorB") < 0.05,
		"%.2f, %.2f rad" % [wardrobe.door_angle("DoorA"), wardrobe.door_angle("DoorB")])
	_check("a creature hides inside", hidden_inside.state == Creature.State.HIDDEN, "")
	player.global_position = Vector3(3.5, 0.05, -0.5)
	player.reset_physics_interpolation()
	var handle: Vector3 = door.global_position + Vector3(0, 0, 0.3)  # near its free edge
	var head := player.get_node("Head") as Node3D
	var look: Vector3 = (handle - head.global_position).normalized()
	player.rotation.y = atan2(-look.x, -look.z)
	head.rotation.x = asin(look.y)
	await _wait(0.1)
	beam._grab_armed = true
	beam._grab(door, handle)
	# Back away, pulling the door's free edge out after you.
	for i in 30:
		player.global_position.x -= 0.03
		await get_tree().physics_frame
	await _wait(0.5)
	beam._release()
	await _wait(0.3)
	_check("pulling a door swings it open", wardrobe.door_angle("DoorA") > 0.6, "%.2f rad" % wardrobe.door_angle("DoorA"))
	_check("the other door stays shut", wardrobe.door_angle("DoorB") < 0.1, "%.2f rad" % wardrobe.door_angle("DoorB"))
	_check("the wardrobe doesn't budge (it guards the doorway)", wardrobe.global_position.distance_to(wardrobe_at) < 0.005,
		"moved %.3f m" % wardrobe.global_position.distance_to(wardrobe_at))
	_check("opening the door reveals the creature inside", hidden_inside.state != Creature.State.HIDDEN,
		"state=%s" % hidden_inside.state)

	# --- You can't catch a creature you can't see: the shut door hides it ---
	var behind_door := _main.get_node("MainRoomCreatures/InWardrobe2") as Creature
	behind_door._set_catchable(true)  # as if it had been uncovered and hid in there
	player.global_position = Vector3(3.5, 0.05, 0.45)
	player.reset_physics_interpolation()
	look = (behind_door.global_position - head.global_position).normalized()
	player.rotation.y = atan2(-look.x, -look.z)
	head.rotation.x = asin(look.y)
	await _wait(0.1)
	_check("a creature behind a shut wardrobe door can't be caught", beam._find_aimed_creature() == null,
		"%s" % beam._find_aimed_creature())
	_check("the click goes to the door instead", beam._find_aimed_prop() == wardrobe.get_node("DoorB"),
		"%s" % beam._find_aimed_prop())
	behind_door._set_catchable(false)

	# --- Pictures hang on the wall; one hides a creature in a hole behind it ---
	var picture: Prop = _main.get_node("MainRoomProps/PictureWest")
	var behind := _main.get_node("MainRoomCreatures/BehindPicture") as Creature
	var block_in_cubby := _main.get_node("MainRoomProps/CubbyBlock1") as Node3D
	_check("pictures stay up on the wall", absf(picture.global_position.y - 1.45) < 0.005
		and absf(_main.get_node("MainRoomProps/PictureNorth").global_position.y - 1.55) < 0.005, "")
	_check("the creature waits in the hole behind it", behind.state == Creature.State.HIDDEN
		and absf(behind.global_position.y - 1.386) < 0.01, "y=%.3f" % behind.global_position.y)
	_check("toy blocks sit in the other hole", block_in_cubby.global_position.y > 1.3, "y=%.3f" % block_in_cubby.global_position.y)
	player.global_position = Vector3(-3.55, 0.05, 1.5)
	player.reset_physics_interpolation()
	look = (picture.global_position - head.global_position).normalized()
	player.rotation.y = atan2(-look.x, -look.z)
	head.rotation.x = asin(look.y)
	await _wait(0.1)
	beam._grab_armed = true
	beam._grab(picture, picture.global_position)
	for i in 30:  # step back, pulling it off the wall
		player.global_position.x += 0.03
		await get_tree().physics_frame
	await _wait(0.3)
	_check("the beam takes the picture down", beam.held == picture and picture.global_position.x > -4.9,
		"x=%.2f" % picture.global_position.x)
	_check("which reveals the creature behind it", behind.state != Creature.State.HIDDEN, "state=%s" % behind.state)
	beam._release()

	# --- The rug in front of the bed drags away; the slippers on it stay put ---
	var rug: Node = _main.get_node("MainRoomProps/Rug")
	var slipper := _main.get_node("MainRoomProps/SlipperR") as Node3D
	var slipper_at: Vector3 = slipper.global_position
	var rug_start: Vector2 = Vector2(rug.centre().x, rug.centre().z)
	_check("the rug lies flat on the floor", absf(rug.centre().y) < 0.03, "y=%.3f" % rug.centre().y)
	_check("the rug lies in front of the bed", absf(rug.centre().x - 2.55) < 0.2 and rug.centre().z > -1.0
		and rug.centre().z < 0.3, "centre %s" % rug.centre())
	# Standing south of the rug, looking at its near edge.
	player.global_position = Vector3(2.55, 0.05, 1.3)
	player.reset_physics_interpolation()
	await _wait(0.3)
	var rug_edge: Vector3 = Vector3(2.55, 0.006, 0.3)  # in from the edge, which droops
	look = (rug_edge - head.global_position).normalized()
	player.rotation.y = atan2(-look.x, -look.z)
	head.rotation.x = asin(look.y)
	await _wait(0.1)
	beam._grab_armed = true
	_check("aiming at the cloth offers its grip", beam._find_aimed_prop() == rug.grip, "got %s" % beam._find_aimed_prop())
	_check("nothing heavy on it, so it comes free", beam._can_lift(rug.grip), beam._refusal(rug.grip))
	beam._grab(rug.grip, rug_edge)
	for i in 60:  # back off, dragging the rug away from the bed
		player.global_position.z += 0.03
		await get_tree().physics_frame
	beam._grab_armed = false  # let go of the button too, or it grabs again
	beam._release()
	await _wait(1.5)
	var rug_flat: Vector2 = Vector2(rug.centre().x, rug.centre().z)
	_check("dragging moves the rug", rug_flat.distance_to(rug_start) > 0.8,
		"moved %.2f m" % rug_flat.distance_to(rug_start))
	_check("the slippers on it stay where they were put", slipper.global_position.distance_to(slipper_at) < 0.05,
		"moved %.3f m" % slipper.global_position.distance_to(slipper_at))
	_check("the rug lands back on the floor", absf(rug.centre().y) < 0.1, "y=%.3f" % rug.centre().y)
	_check("let go, it lets go of the cloth", rug._pinned.is_empty() and rug.grip.freeze, "pins %d, frozen %s, held %s" % [rug._pinned.size(), rug.grip.freeze, beam.held])

	# --- The chest of drawers: three drawers on the same runners ---
	var chest: Node = _main.get_node("MainRoomProps/ChestOfDrawers")
	_check("the chest has three drawers", chest.drawers.size() == 3, "%d" % chest.drawers.size())
	var all_shut: bool = true
	for i in chest.drawers.size():
		all_shut = all_shut and absf(chest.drawer_out(i)) < 0.005
	_check("its drawers rest shut", all_shut, "")
	# Pull the top drawer open with the beam, as a player would.
	var front: Vector3 = (chest as Node3D).global_basis.z
	var chest_at: Vector3 = (chest as Node3D).global_position
	var pull_from: Vector3 = chest_at + front * 1.6
	player.global_position = Vector3(pull_from.x, 0.05, pull_from.z)
	player.reset_physics_interpolation()
	var knob: Vector3 = (chest as Node3D).to_global(Vector3(0.0, 0.2733, 0.25))
	look = (knob - head.global_position).normalized()
	player.rotation.y = atan2(-look.x, -look.z)
	head.rotation.x = asin(look.y)
	await _wait(0.1)
	beam._grab_armed = true
	beam._grab(chest.drawers[0], knob)
	for i in 20:  # step back, pulling it out
		player.global_position += front * 0.025
		await get_tree().physics_frame
	await _wait(0.3)
	beam._grab_armed = false
	beam._release()
	await _wait(0.3)
	_check("pulling a drawer with the beam slides it open", chest.drawer_out(0) > 0.2, "%.3f m out" % chest.drawer_out(0))
	_check("the other drawers stay shut", absf(chest.drawer_out(1)) < 0.05 and absf(chest.drawer_out(2)) < 0.05,
		"%.3f, %.3f m out" % [chest.drawer_out(1), chest.drawer_out(2)])
	_check("and the chest stays where it is", (chest as Node3D).global_position.distance_to(chest_at) < 0.1,
		"moved %.3f m" % (chest as Node3D).global_position.distance_to(chest_at))

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Grabs the drawer and rises 0.6 m, pulling it up. Returns how far the
## table moved meanwhile.
func _yank_drawer(beam: Beam, player: Node3D, table: Prop, drawer: Prop) -> float:
	var start: Vector3 = table.global_position
	beam._grab_armed = true
	beam._grab(drawer, drawer.global_position)
	var moved: float = 0.0
	for i in 30:
		player.global_position.y += 0.02
		await get_tree().physics_frame
		moved = maxf(moved, table.global_position.distance_to(start))
	beam._grab_armed = false
	if beam.held != null:
		beam._release()
	player.global_position.y -= 0.6
	player.reset_physics_interpolation()
	await _wait(0.5)
	return moved


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
