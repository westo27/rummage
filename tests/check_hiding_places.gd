extends Node
## Headless test for the hiding places: inside toys, lumps under cloth and
## cushions, the bowl of marbles, and diving into nooks while fleeing.
## Run: Godot --headless --path . res://tests/check_hiding_places.tscn

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D
var _props: Node
var _creatures: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	_player = _main.get_node("Player")
	_props = _main.get_node("MainRoomProps")
	_creatures = _main.get_node("MainRoomCreatures")
	var side: Node = _main.get_node("SideRoomCreatures")
	_park_player()
	await _wait(2.5)

	var names: Array[String] = ["UnderCushion", "InToyDrum", "UnderRug", "InMarbleBowl", "UnderPillow"]
	var still: Array[String] = []
	for n in names:
		if (_creatures.get_node(n) as Creature).state == Creature.State.HIDDEN:
			still.append(n)
	if (side.get_node("InSideBag") as Creature).state == Creature.State.HIDDEN:
		still.append("InSideBag")
	_check("the new hiders all stay hidden while the room settles", still.size() == 6, "hidden: %s" % ", ".join(still))

	# --- The bowl: the marbles settle in it, and one of them has a face ---
	var bowl: Prop = _props.get_node("MarbleBowl")
	var spilled: int = 0
	for i in 9:
		var m := _props.get_node("BowlMarble%d" % (i + 1)) as Prop
		if _flat(m.global_position, bowl.global_position) > 0.2 or m.global_position.y > 0.3:
			spilled += 1
	_check("the plain marbles stay in the bowl", spilled == 0, "%d out" % spilled)
	var plain := (_props.get_node("BowlMarble1/Mesh") as MeshInstance3D).material_override as ShaderMaterial
	_check("plain marbles have no face", plain.get_shader_parameter("face_shown") == false, "")

	# --- Lumps: the cushion, pillow and rug sit up over their marbles ---
	var cushion: Prop = _props.get_node("FloorCushion")
	_check("the cushion rests on its marble, not flat", cushion.global_position.y > 0.07,
		"y=%.3f" % cushion.global_position.y)
	var pillow: Prop = _props.get_node("PillowL")
	_check("the pillow rests on its marble", pillow.global_position.y > 0.58 and
		_flat(pillow.global_position, Vector3(1.79, 0, -1.98)) < 0.2, "at %s" % pillow.global_position)
	var rug: SoftBody3D = _props.get_node("Rug")
	var lump_at: Vector3 = (_creatures.get_node("UnderRug") as Creature).global_position
	_check("the rug rises over its marble", _cloth_height(rug, lump_at) > 0.09,
		"cloth at %.3f m" % _cloth_height(rug, lump_at))

	# --- Inside toys: tip the drum and it tumbles out ---
	var drum: Prop = _props.get_node("ToyDrum")
	var in_drum: Creature = _creatures.get_node("InToyDrum")
	drum.global_position += Vector3.UP * 0.15
	await get_tree().physics_frame
	_check("a creature in a drum rides it, still hidden", in_drum.state == Creature.State.HIDDEN and
		in_drum.global_position.distance_to(drum.global_position) < 0.05, "")
	drum.global_basis = Basis(Vector3.RIGHT, PI)
	await _wait(0.3)
	_check("tipping the drum over lets it out", in_drum.state == Creature.State.FLEEING, "state=%d" % in_drum.state)
	await _wait(1.0)
	_check("and it's out on the floor, clear of the drum", in_drum.global_position.y < 0.15 and
		_flat(in_drum.global_position, drum.global_position) > 0.15,
		"at %s, drum %s" % [in_drum.global_position, drum.global_position])

	# --- Shaking the bag lets the one inside out ---
	var bag: Prop = _main.get_node("SideRoomProps/SideBag")
	var in_bag: Creature = side.get_node("InSideBag")
	bag.linear_velocity = Vector3(0, 1.0, 0)
	await _wait(0.2)
	_check("a gentle nudge keeps it in the bag", in_bag.state == Creature.State.HIDDEN, "state=%d" % in_bag.state)
	bag.linear_velocity = Vector3(-3.5, 0.5, 0)
	await _wait(0.2)
	_check("shaking the bag hard lets it out", in_bag.state == Creature.State.FLEEING, "state=%d" % in_bag.state)

	# --- Treading on the rug lump ---
	var under_rug: Creature = _creatures.get_node("UnderRug")
	_player.global_position = lump_at + Vector3(0.8, 0.0, 0.0)
	await _wait(0.3)
	_check("walking near the lump doesn't find it", under_rug.state == Creature.State.HIDDEN, "")
	_player.global_position = Vector3(lump_at.x + 0.2, 0.05, lump_at.z)
	await _wait(0.3)
	_check("treading on the lump sends it bolting", under_rug.state == Creature.State.FLEEING, "state=%d" % under_rug.state)
	_park_player()
	await _wait(0.8)
	_check("the rug falls flat again", _cloth_height(rug, lump_at) < 0.06, "%.3f m" % _cloth_height(rug, lump_at))

	# --- Knocking the bowl spills the creature out ---
	var in_bowl: Creature = _creatures.get_node("InMarbleBowl")
	bowl.linear_velocity = Vector3(0.0, 0.0, -1.5)
	await _wait(0.3)
	_check("knocking the bowl startles the face marble", in_bowl.state == Creature.State.FLEEING, "state=%d" % in_bowl.state)
	await _wait(1.0)
	_check("it gets out of the bowl", _flat(in_bowl.global_position, bowl.global_position) > 0.3,
		"%.2f m from the bowl" % _flat(in_bowl.global_position, bowl.global_position))

	# --- Lifting the pillow and the cushion ---
	var under_pillow: Creature = _creatures.get_node("UnderPillow")
	pillow.global_position += Vector3(0.0, 0.3, 0.3)
	await _wait(0.3)
	_check("lifting the pillow finds the one under it", under_pillow.state == Creature.State.FLEEING,
		"state=%d" % under_pillow.state)
	var under_cushion: Creature = _creatures.get_node("UnderCushion")
	cushion.global_position += Vector3(0.0, 0.3, -0.3)
	await _wait(0.3)
	_check("lifting the cushion finds the one under it", under_cushion.state == Creature.State.FLEEING,
		"state=%d" % under_cushion.state)

	# --- Fleeing into nooks: under the bed, under the rug ---
	var runner: Creature = under_rug
	_player.global_position = Vector3(2.0, 0.05, 1.6)
	await _wait(0.2)
	runner.global_position = Vector3(2.0, 0.06, -0.6)
	runner.reset_physics_interpolation()
	runner.velocity = Vector3.ZERO
	runner._start_seeking()
	_check("a fleeing creature picks the nook under the bed", runner._seek_nook != null and
		runner._seek_nook.kind == HideNook.Kind.UNDER_BED, "nook=%s" % runner._seek_nook)
	await _wait(2.0)
	_check("it dives under the bed and hides again", runner.state == Creature.State.HIDDEN and
		runner._nook != null and not runner.is_catchable(), "state=%d at %s" % [runner.state, runner.global_position])
	_check("found there by crouching and looking", runner.reveal_when_spotted, "")

	var runner2: Creature = in_bowl
	# The others found above are still running about and may have claimed the
	# nook this is about, so clear them off.
	for node in get_tree().get_nodes_in_group("creatures"):
		var c := node as Creature
		if c != runner2 and c != runner and c.state != Creature.State.HIDDEN:
			c.queue_free()
	_player.global_position = Vector3(-4.5, 0.05, 1.6)
	await _wait(0.2)
	var nook_rug: HideNook = _main.get_node("HideNooks/UnderRugA")
	runner2.state = Creature.State.FLEEING
	runner2.global_position = nook_rug.global_position + Vector3(-0.4, 0.01, -0.2)
	runner2.reset_physics_interpolation()
	runner2.velocity = Vector3.ZERO
	runner2._start_seeking()
	_check("a creature by the rug picks the rug nook", runner2._seek_nook == nook_rug, "nook=%s" % runner2._seek_nook)
	await _wait(2.0)
	_check("it slips under the rug as a lump", runner2.state == Creature.State.HIDDEN and runner2._lump != null,
		"state=%d at %s" % [runner2.state, runner2.global_position])
	await _wait(0.5)
	_check("the rug rises over it", _cloth_height(rug, runner2.global_position) > 0.08,
		"%.3f m" % _cloth_height(rug, runner2.global_position))
	_check("a nook holds one at a time", not runner2._nook_usable(nook_rug) or nook_rug.occupant == runner2, "")

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Out of the way in the playroom, far from every hiding place.
func _park_player() -> void:
	_player.global_position = Vector3(-0.6, 0.05, 0.0)


## The highest cloth point within 0.1 m (flat) of `at`.
func _cloth_height(rug: SoftBody3D, at: Vector3) -> float:
	var top: float = -1.0
	for i in rug._point_count():
		var p: Vector3 = rug.get_point_transform(i)
		if _flat(p, at) < 0.1:
			top = maxf(top, p.y)
	return top


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
