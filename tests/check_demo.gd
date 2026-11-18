extends Node
## Check for the web demo (web_demo.gd): only the bedroom is left, the
## lesson is beside the player, nothing casts a moving shadow, and the
## doorways are shut. Not part of the game. In a real window it also saves
## user://shots/demo_start.png.
## Run: Godot --headless --path . res://tests/check_demo.tscn

var _failures: int = 0
var _main: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	WebDemo.forced = true
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	await _wait(1.0)

	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("user://shots")
		get_viewport().get_texture().get_image().save_png("user://shots/demo_start.png")


	var creatures: Array[Node] = get_tree().get_nodes_in_group("creatures")
	var outside: int = 0
	for creature: Node3D in creatures:
		if not WebDemo._in_bedroom(creature.global_position):
			outside += 1
	_check("every marble left is in the bedroom", outside == 0, "%d outside" % outside)
	_check("ten marbles, all counted",
		creatures.size() == 10 and _main.get("_total_creatures") == 10,
		"%d in group, %d counted" % [creatures.size(), _main.get("_total_creatures")])
	var in_drawers: int = 0
	for creature: Node3D in creatures:
		if not (creature.get("drawer_furniture") as NodePath).is_empty():
			in_drawers += 1
	_check("a marble in each of the four drawers", in_drawers == 4, "%d" % in_drawers)
	var player := _main.get_node("Player") as Node3D
	_check("the player starts in the bedroom", WebDemo._in_bedroom(player.global_position),
		"%s" % player.global_position)
	var bin := _main.get_node("Landing/LessonBin") as Node3D
	_check("the lesson bin is near the player",
		bin.global_position.distance_to(player.global_position) < 2.5,
		"%.2f m" % bin.global_position.distance_to(player.global_position))
	_check("the lesson marble is still under its bin",
		(_main.get_node("Landing/LessonCreature") as Node3D).global_position.distance_to(
			bin.global_position) < 0.3, "%s vs %s" % [(_main.get_node("Landing/LessonCreature") as Node3D).global_position, bin.global_position])

	var lamps: Array[Node] = get_tree().get_nodes_in_group("lamps")
	var shadowed: int = 0
	for lamp: PendantLamp in lamps:
		if lamp.light().shadow_enabled:
			shadowed += 1
	_check("one lamp is left, casting no shadow", lamps.size() == 1 and shadowed == 0,
		"%d lamps, %d shadowed" % [lamps.size(), shadowed])
	_check("the moon casts no shadow",
		not (_main.get_node("Moonlight") as Light3D).shadow_enabled, "")
	_check("no tutorial, and no hint showing",
		_main.get_node_or_null("Tutorial") == null
		and not (_main.get_node("HUD").get("_hint_label") as Label).visible, "")
	var page := SettingsMenu.new()
	add_child(page)
	await get_tree().process_frame
	_check("the settings page has no Graphics rows",
		not page._value_labels.has("lighting") and page._value_labels.has("volume"),
		"%s" % [page._value_labels.keys()])
	page.queue_free()
	_check("the win screen points to the full game",
		_main.get_node("HUD").find_child("DemoNote", true, false) != null, "")
	_check("the box room has a door",
		_main.get_node_or_null("DemoBoxRoomDoor") != null, "")

	# Walk into each doorway: the player must stay in the bedroom.
	for target: Vector3 in [Vector3(-1.0, 0.05, 0.0), Vector3(6.5, 0.05, 0.0)]:
		player.global_position = Vector3(clampf(target.x, 0.6, 4.6), 0.05, 0.0)
		player.reset_physics_interpolation()
		var push: Vector3 = (target - player.global_position).normalized() * 2.0
		for i in 120:
			(player as CharacterBody3D).velocity = push
			(player as CharacterBody3D).move_and_slide()
			await get_tree().physics_frame
		_check("the doorway toward x=%.0f is shut" % target.x,
			WebDemo._in_bedroom(player.global_position), "%s" % player.global_position)

	WebDemo.forced = false
	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
