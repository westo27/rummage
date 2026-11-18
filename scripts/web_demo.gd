class_name WebDemo
extends RefCounted
## The browser build is a demo: the bedroom only, lit without moving shadows,
## so it runs on low-powered laptops. The house is cut down after loading, so
## main.tscn stays the one level for both.
##
## The landing's lesson bin and its marble are moved into the bedroom as one
## more hiding place beside the player's start. There are no tutorial hints
## (the Tutorial node is dropped). The doorways out are
## shut: the stable door's bottom half is held closed and the box room gets a
## plain door.
## Add the user arg `demo` to try it on desktop: Godot --path . -- demo

## The bedroom's floor, inside its walls (the cubby in the south wall too).
const BEDROOM_MIN := Vector2(0.05, -2.3)
const BEDROOM_MAX := Vector2(5.15, 2.3)
## Where the player starts and what they face, and where the lesson goes:
## clear floor at the edge of the rug, between the desk and the bed.
const SPAWN := Vector3(0.9, 0.05, 0.3)
const SPAWN_LOOK := Vector3(4.0, 0.3, 1.6)
const LESSON_BIN := Vector3(2.4, 0.18, 0.95)
## Groups of house parts that belong to the rooms left out.
const STRIP_HOUSE: Array[String] = ["LampPlayroom", "LampSide", "LampLanding",
	"ReflectionsPlayroom", "ReflectionsSide", "ReflectionsLanding"]
const STRIP_CHILDREN_OF: Array[String] = ["MainRoomProps", "MainRoomCreatures",
	"SideRoomProps", "SideRoomCreatures", "Landing"]
## Bedroom marbles left out, so the demo has ten: one in each drawer (four),
## the lesson's, and five more.
const DROP_CREATURES: Array[String] = ["UnderBed2", "UnderBed4", "UnderPillow",
	"UnderBin03", "InWardrobe2", "InShoeBox"]
## The box room's doorway (DoorBoxRoom in main.tscn): a door to fill it.
const BOX_ROOM_DOOR := Vector3(5.2, 1.05, 0.0)
const BOX_ROOM_DOOR_SIZE := Vector3(0.08, 2.1, 1.0)
const DOOR_COLOUR := Color(0.55, 0.33, 0.2)


## Set by tests to get the demo on desktop.
static var forced: bool = false


static func active() -> bool:
	return forced or OS.has_feature("web") or "demo" in OS.get_cmdline_user_args()


## Cuts `house` (main.tscn's root, before it counts its creatures) down to the
## bedroom. `player` is moved to the bedroom if given.
static func strip(house: Node3D, player: Node3D = null) -> void:
	var lesson_bin: Node3D = house.get_node_or_null("Landing/LessonBin")
	var lesson_creature: Node3D = house.get_node_or_null("Landing/LessonCreature")
	for name in STRIP_HOUSE:
		_drop(house.get_node_or_null("House/" + name))
	for name in STRIP_CHILDREN_OF:
		var parent: Node = house.get_node_or_null(name)
		if parent == null:
			continue
		for child in parent.get_children():
			if child == lesson_bin or child == lesson_creature:
				continue
			if child.name in DROP_CREATURES and parent.name == "MainRoomCreatures":
				_drop(child)
			elif child is Node3D and not _in_bedroom(_where(child as Node3D)):
				_drop(child)
	# The lesson: the bin over its marble, now on the bedroom floor.
	# Its lid is top_level (lidded_box.gd), so it has to be moved too, or the
	# marble sees an open bin and leaves.
	if lesson_bin != null and lesson_creature != null:
		var shift: Vector3 = LESSON_BIN - lesson_bin.global_position
		var moving: Array[Node3D] = [lesson_bin, lesson_creature]
		var lid := lesson_bin.get("lid") as Node3D
		if lid != null:
			moving.append(lid)
		for node in moving:
			node.global_position += shift
			node.reset_physics_interpolation()
	_shut_doorways(house)
	# No tutorial hints. It has already put its first one up, so that goes too.
	_drop(house.get_node_or_null("Tutorial"))
	var hud := house.get_node_or_null("HUD")
	if hud != null:
		hud.hide_hint()
	if player != null:
		player.global_position = SPAWN
		var dir: Vector3 = SPAWN_LOOK - SPAWN
		player.rotation.y = atan2(-dir.x, -dir.z)
		player.reset_physics_interpolation()  # a jump, not a glide


## Lamps light the room without shadows, and so does the moon. `house` must
## be in the tree (lamps are found by their group).
static func light(house: Node) -> void:
	for lamp: PendantLamp in house.get_tree().get_nodes_in_group("lamps"):
		lamp.shadows_allowed = false
	var moon := house.get_node_or_null("Moonlight") as Light3D
	if moon != null:
		moon.shadow_enabled = false


## Where a node really is. A marble hiding in a drawer, box or other prop has
## no position of its own yet (it moves there a frame later), so it counts
## as wherever that prop is.
static func _where(node: Node3D) -> Vector3:
	if node is Creature:
		for key in ["drawer_furniture", "hiding_box", "inside"]:
			var path: NodePath = node.get(key)
			if not path.is_empty():
				var host := node.get_node_or_null(path) as Node3D
				return host.global_position if host != null else Vector3.INF
	return node.global_position


static func _in_bedroom(at: Vector3) -> bool:
	return at.x > BEDROOM_MIN.x and at.x < BEDROOM_MAX.x \
		and at.z > BEDROOM_MIN.y and at.z < BEDROOM_MAX.y


## Freed at once, so nothing (the creature count, the ping) still finds it.
static func _drop(node: Node) -> void:
	if node == null:
		return
	if node.is_in_group("creatures"):
		node.remove_from_group("creatures")
	node.get_parent().remove_child(node)
	node.queue_free()


static func _shut_doorways(house: Node3D) -> void:
	var door := StaticBody3D.new()
	door.name = "DemoBoxRoomDoor"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = BOX_ROOM_DOOR_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = DOOR_COLOUR
	material.roughness = 0.7
	box.material = material
	mesh.mesh = box
	door.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = BOX_ROOM_DOOR_SIZE
	shape.shape = box_shape
	door.add_child(shape)
	house.add_child(door)
	door.global_position = BOX_ROOM_DOOR
	# The stable door's bottom half swings into the playroom: an unseen block
	# just behind it stops it opening.
	var stop := StaticBody3D.new()
	stop.name = "DemoStableDoorStop"
	var stop_shape := CollisionShape3D.new()
	var stop_box := BoxShape3D.new()
	stop_box.size = Vector3(0.1, 1.1, 1.0)
	stop_shape.shape = stop_box
	stop.add_child(stop_shape)
	house.add_child(stop)
	stop.global_position = Vector3(-0.2, 0.55, 0.0)
