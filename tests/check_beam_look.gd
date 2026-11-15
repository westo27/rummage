extends Node
## Headless check for the beam's look: its glow, filament and lights come on
## with it, take its colour, sit where it meets the object, turn red and
## agitated when straining, and all go when it does. (How it looks can only
## be judged in tests/shoot.tscn's pictures.) Not part of the game.
## Run: Godot --headless --path . res://tests/check_beam_look.tscn

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D
var _beam: Beam


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	# Light test crates (tests/fixtures): the room's own props are either
	# fixed furniture or odd shapes, and these checks want a plain box.
	var cratea_fixture := (load("res://tests/fixtures/crate.tscn") as PackedScene).instantiate() as Prop
	cratea_fixture.name = "CrateA"
	_main.get_node("MainRoomProps").add_child(cratea_fixture)
	cratea_fixture.global_position = Vector3(2.4, 0.3, 0.5)
	_player = _main.get_node("Player")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	_beam.lift_limit = 10.0
	await _wait(1.0)

	# Two frames: process_frame fires just before nodes update, so the first
	# would read the beam before it has redrawn.
	await get_tree().process_frame
	await get_tree().process_frame
	_check("nothing shows before grabbing", not _any_part_visible(), "")

	# --- Holding a crate ---
	var crate: Prop = _main.get_node("MainRoomProps/CrateA")
	crate.global_position = Vector3(3.0, 0.3, -0.6)  # out on the open bedroom floor
	crate.sleeping = false
	await _wait(0.4)
	_player.global_position = Vector3(3.0, 0.05, 1.5)
	_aim_at(crate.global_position + Vector3(0.0, 0.3, 0.0))
	await _wait(0.1)
	_press("grab")
	await _wait(0.3)
	# Two frames: process_frame fires just before nodes update, so the first
	# would read the beam before it has redrawn.
	await get_tree().process_frame
	await get_tree().process_frame
	_check("holding: the glow, filament, contact glow and both lights show",
		_all_parts_visible(), _visibility())
	_check("holding: it's cyan", _beam.beam_color().is_equal_approx(Beam.HOLD_COLOR), "%s" % _beam.beam_color())
	_check("holding: the end light is the beam's colour",
		_beam._end_light.light_color.is_equal_approx(Beam.HOLD_COLOR), "")
	var grab_point: Vector3 = _beam.grab_point()
	_check("holding: the contact glow sits on the grab point",
		_beam._contact_glow.global_position.distance_to(grab_point) < 0.1,
		"%.2f m away" % _beam._contact_glow.global_position.distance_to(grab_point))
	_check("holding: the end light is right by it",
		_beam._end_light.global_position.distance_to(grab_point) < 0.3, "")
	_check("holding: the crate wears a cyan aura", _aura_on(crate, Beam.HOLD_COLOR), "")
	_check("holding: calm, not agitated",
		is_zero_approx(_beam._beam_material.get_shader_parameter("agitation")), "")
	_release("grab")
	await _wait(0.1)
	# Two frames: process_frame fires just before nodes update, so the first
	# would read the beam before it has redrawn.
	await get_tree().process_frame
	await get_tree().process_frame
	_check("letting go: everything goes", not _any_part_visible(),
		"%s held=%s rejected=%s catching=%s" % [_visibility(), _beam.held, _beam._rejected, _beam._catching])
	_check("letting go: the aura goes", crate._aura != null and not crate._aura.visible, "")

	# --- Straining against something too heavy ---
	# Nothing in the rooms is too heavy for the starting lift, so lower it.
	_beam.lift_limit = 1.0
	var heavy: Prop = crate
	crate.global_position = Vector3(3.0, 0.3, -0.6)
	crate.sleeping = false
	_player.global_position = Vector3(3.0, 0.05, 1.5)
	await _wait(0.5)
	_aim_at(crate.global_position)
	await _wait(0.1)
	_press("grab")
	await _wait(0.3)
	# Two frames: process_frame fires just before nodes update, so the first
	# would read the beam before it has redrawn.
	await get_tree().process_frame
	await get_tree().process_frame
	_check("straining: latched on", _beam._rejected == heavy, "%s" % _beam._rejected)
	_check("straining: everything shows", _all_parts_visible(), _visibility())
	_check("straining: it's red", _beam.beam_color().is_equal_approx(Beam.STRAIN_COLOR), "")
	_check("straining: it wears a red aura", _aura_on(heavy, Beam.STRAIN_COLOR), "")
	_check("straining: agitated",
		is_equal_approx(_beam._beam_material.get_shader_parameter("agitation"), 1.0), "")
	_release("grab")
	await _wait(0.1)
	# Two frames: process_frame fires just before nodes update, so the first
	# would read the beam before it has redrawn.
	await get_tree().process_frame
	await get_tree().process_frame
	_check("letting go of the strain: everything goes", not _any_part_visible(), _visibility())
	_check("letting go of the strain: the aura goes", not heavy._aura.visible, "")

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## True if `prop` is showing the beam's aura, in `color`, around itself.
func _aura_on(prop: Prop, color: Color) -> bool:
	if prop._aura == null or not prop._aura.visible:
		return false
	var shown: Color = (prop._aura.material_override as ShaderMaterial).get_shader_parameter("glow_color")
	return shown.is_equal_approx(color)


func _parts() -> Array[Node3D]:
	return [_beam._beam_mesh, _beam._filament, _beam._contact_glow, _beam._end_light, _beam._mid_light]


func _all_parts_visible() -> bool:
	return _parts().all(func(n: Node3D) -> bool: return n.visible)


func _any_part_visible() -> bool:
	return _parts().any(func(n: Node3D) -> bool: return n.visible)


func _visibility() -> String:
	return ", ".join(_parts().map(func(n: Node3D) -> String: return "%s" % n.visible))


func _aim_at(target: Vector3) -> void:
	var head := _player.get_node("Head") as Node3D
	var dir: Vector3 = (target - head.global_position).normalized()
	_player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _release(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
