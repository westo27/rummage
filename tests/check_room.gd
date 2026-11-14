extends Node
## Headless check for the room's new parts: the window holds things in, the
## props are glossy, the bedside lamp stands on its table, and the table's
## drawer slides out and back by physics, the wardrobe doors swing open, and
## pictures come off the wall to show what's behind, and the rug drags away
## to show a trapdoor. (How the room looks can only be judged in
## tests/shoot.tscn's pictures.) Not part of the game.
## Run: Godot --headless --path . res://tests/check_room.tscn

var _failures: int = 0
var _main: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	await _wait(1.0)

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
	var crate_mesh := _main.get_node("MainRoomProps/CrateA").get_child(0) as MeshInstance3D
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
	# Shove the table forward along the floor: friction stops it, the drawer
	# carries on and slides out.
	table.linear_velocity = Vector3(0, 0, 3.0)
	await _wait(1.0)
	_check("stopping the table suddenly slides the drawer out", table.drawer_out() > 0.2,
		"%.3f m out" % table.drawer_out())
	_check("but no further than its stop", table.drawer_out() < 0.27, "%.3f m out" % table.drawer_out())
	table.linear_velocity = Vector3(0, 0, -3.0)
	await _wait(1.0)
	_check("a shove the other way slides it home", table.drawer_out() < 0.02, "%.3f m out" % table.drawer_out())
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
		and absf(behind.global_position.y - 1.422) < 0.01, "y=%.3f" % behind.global_position.y)
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

	# --- The rug lifts away to show a trapdoor; what's on it stays put ---
	var rug: Node = _main.get_node("MainRoomProps/Rug")
	var table_on_rug := _main.get_node("MainRoomProps/Table") as Node3D
	var table_at: Vector3 = table_on_rug.global_position
	var trapdoor := _main.get_node("House/Trapdoor") as Node3D
	_check("the rug lies flat on the floor", absf(rug.centre().y) < 0.02, "y=%.3f" % rug.centre().y)
	_check("the table stands on the rug", Vector2(table_at.x - rug.centre().x, table_at.z - rug.centre().z).length() < 0.1, "")
	_check("the trapdoor is under the rug", absf(trapdoor.global_position.x - rug.centre().x) < 1.5
		and absf(trapdoor.global_position.z - rug.centre().z) < 1.0, "")
	# From the doorway to the bedroom, looking at the rug's east edge.
	player.global_position = Vector3(0.1, 0.05, -0.05)
	player.reset_physics_interpolation()
	var rug_edge: Vector3 = Vector3(-1.6, 0.006, -0.05)
	look = (rug_edge - head.global_position).normalized()
	player.rotation.y = atan2(-look.x, -look.z)
	head.rotation.x = asin(look.y)
	await _wait(0.1)
	beam._grab_armed = true
	_check("aiming at the cloth offers its grip", beam._find_aimed_prop() == rug.grip, "got %s" % beam._find_aimed_prop())
	_check("but not while the table stands on it", not beam._can_lift(rug.grip)
		and beam._refusal(rug.grip) == "SOMETHING'S ON IT", beam._refusal(rug.grip))
	table_on_rug.global_position += Vector3(0, 0, 1.35)  # lift the table off, out of the way
	(table_on_rug as RigidBody3D).sleeping = false
	await _wait(0.5)
	table_at = table_on_rug.global_position
	_check("with the table off, the rug comes free", beam._can_lift(rug.grip), beam._refusal(rug.grip))
	beam._grab(rug.grip, rug_edge)
	for i in 60:  # back off, dragging the rug out from under the table
		player.global_position.x += 0.03
		await get_tree().physics_frame
	beam._grab_armed = false  # let go of the button too, or it grabs again
	beam._release()
	await _wait(1.5)
	var rug_flat: Vector2 = Vector2(rug.centre().x, rug.centre().z)
	var trap_flat: Vector2 = Vector2(trapdoor.global_position.x, trapdoor.global_position.z)
	_check("dragging the rug uncovers the trapdoor", rug_flat.distance_to(trap_flat) > 1.4,
		"rug %.2f m from the trapdoor" % rug_flat.distance_to(trap_flat))
	_check("the table stays where it was put", table_on_rug.global_position.distance_to(table_at) < 0.05,
		"moved %.3f m" % table_on_rug.global_position.distance_to(table_at))
	_check("the rug lands back on the floor", absf(rug.centre().y) < 0.1, "y=%.3f" % rug.centre().y)
	_check("let go, it lets go of the cloth", rug._pinned.is_empty() and rug.grip.freeze, "pins %d, frozen %s, held %s" % [rug._pinned.size(), rug.grip.freeze, beam.held])

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
