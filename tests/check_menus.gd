extends Node
## Headless smoke test for the title screen, pause menu and settings.
## Not part of the game.
## Run: Godot --headless --path . res://tests/check_menus.tscn

var _failures: int = 0
## The player's real saved settings, put back at the end so running the test
## doesn't change them.
var _saved: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_saved = [Game.settings.sensitivity_step, Game.settings.volume_percent, Game.settings.invert_look]

	# --- Title screen ---
	var title: Control = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await _wait(0.2)
	var panels: Array[MenuPanel] = _panels_under(title)
	var labels: Array[String] = []
	for p in panels:
		labels.append(p.label_text)
	_check("title screen shows Play, Settings and Quit", labels == ["Play", "Settings", "Quit"],
		"%s" % [labels])
	var focusable: int = 0
	for p in panels:
		if p.focus_mode != Control.FOCUS_NONE:
			focusable += 1
	_check("no panel can take keyboard focus (mouse only)", focusable == 0,
		"%d focusable" % focusable)
	_check("nothing is pre-selected", title.get_viewport().gui_get_focus_owner() == null,
		"%s" % title.get_viewport().gui_get_focus_owner())
	_press("ui_down")
	await _wait(0.1)
	_check("arrow keys don't select a panel", title.get_viewport().gui_get_focus_owner() == null,
		"%s" % title.get_viewport().gui_get_focus_owner())

	# --- Settings page, opened from the title ---
	panels[1].pressed.emit()
	await _wait(0.2)
	var settings_menu: SettingsMenu = _settings_under(title)
	_check("Settings opens the settings page", settings_menu != null, "")
	var steppers: Array[MenuPanel] = _panels_under(settings_menu)
	_check("settings page has 3 rows of steppers plus Back", steppers.size() == 7,
		"%d panels" % steppers.size())

	var before: int = Game.settings.sensitivity_step
	steppers[1].pressed.emit()  # the "+" of the first row
	await _wait(0.05)
	_check("the + stepper raises look sensitivity", Game.settings.sensitivity_step == before + 1,
		"%d -> %d" % [before, Game.settings.sensitivity_step])
	_check("sensitivity maps to radians per pixel",
		is_equal_approx(Game.settings.mouse_sensitivity(),
			Game.settings.sensitivity_step * Settings.SENSITIVITY_PER_STEP), "")
	steppers[0].pressed.emit()
	steppers[0].pressed.emit()
	await _wait(0.05)
	_check("the - stepper lowers it", Game.settings.sensitivity_step == before - 1,
		"%d" % Game.settings.sensitivity_step)

	var invert_before: bool = Game.settings.invert_look
	steppers[3].pressed.emit()
	await _wait(0.05)
	_check("invert look toggles", Game.settings.invert_look != invert_before, "")

	var volume_before: int = Game.settings.volume_percent
	steppers[4].pressed.emit()  # the "-" of the volume row
	await _wait(0.05)
	_check("volume steps down by 5", Game.settings.volume_percent == volume_before - Settings.VOLUME_STEP,
		"%d -> %d" % [volume_before, Game.settings.volume_percent])

	# Clamping at the ends.
	for i in 40:
		Game.settings.adjust_volume(-1)
	var muted: bool = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	_check("volume stops at 0 and mutes", Game.settings.volume_percent == 0 and muted,
		"%d" % Game.settings.volume_percent)
	for i in 40:
		Game.settings.adjust_sensitivity(1)
	_check("sensitivity stops at its maximum",
		Game.settings.sensitivity_step == Settings.SENSITIVITY_MAX, "%d" % Game.settings.sensitivity_step)

	# --- Back closes it and writes the file ---
	steppers[6].pressed.emit()  # Back
	await _wait(0.2)
	_check("Back closes the settings page", _settings_under(title) == null, "")
	_check("the title panels come back", _panels_under(title).size() == 3, "")

	var reloaded := Settings.new()
	reloaded.load_from_disk()
	_check("settings survive a reload from disk",
		reloaded.sensitivity_step == Game.settings.sensitivity_step \
		and reloaded.volume_percent == Game.settings.volume_percent \
		and reloaded.invert_look == Game.settings.invert_look,
		"%d/%d/%s" % [reloaded.sensitivity_step, reloaded.volume_percent, reloaded.invert_look])

	title.queue_free()
	await _wait(0.2)

	# --- Pause menu in a real game ---
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _wait(0.6)
	var pause: PauseMenu = main.get_node("PauseMenu")
	var hud: CanvasLayer = main.get_node("HUD")
	_check("the game starts unpaused with the pause menu hidden",
		not get_tree().paused and not pause._root.visible, "")

	_press("release_mouse")
	await _wait(0.2)
	_check("Esc pauses the game", get_tree().paused, "")
	_check("Esc shows the pause panels", pause._root.visible, "")
	_check("the HUD hides while paused", not hud.visible, "")
	var pause_labels: Array[String] = []
	for p in _panels_under(pause):
		pause_labels.append(p.label_text)
	_check("pause menu shows Resume, Settings, Restart and Title",
		pause_labels == ["Resume", "Settings", "Restart", "Title"], "%s" % [pause_labels])

	_press("release_mouse")
	await _wait(0.2)
	_check("Esc again resumes", not get_tree().paused and not pause._root.visible, "")
	_check("the HUD comes back", hud.visible, "")

	# Esc inside settings backs out to the pause panels, not into the game.
	_press("release_mouse")
	await _wait(0.2)
	_panels_under(pause)[1].pressed.emit()  # Settings
	await _wait(0.2)
	_check("the pause menu can open settings", _settings_under(pause) != null, "")
	_press("ui_cancel")
	await _wait(0.2)
	_check("Esc in settings returns to the pause panels",
		_settings_under(pause) == null and get_tree().paused, "")

	# --- Restart from the pause menu ---
	_panels_under(pause)[2].pressed.emit()  # Restart
	await _wait(0.8)
	main = get_tree().current_scene
	var caught: String = (main.get_node("HUD/CaughtLabel") as Label).text
	_check("Restart reloads the game unpaused",
		not get_tree().paused and caught == "Caught: 0 / 25", "'%s'" % caught)

	# --- Quit to title ---
	_press("release_mouse")
	await _wait(0.2)
	_panels_under(main.get_node("PauseMenu"))[3].pressed.emit()  # Title
	await _wait(0.8)
	var now: Node = get_tree().current_scene
	_check("Title returns to the title screen", now != null and now.name == "Title", "%s" % now)
	_check("time is running again after quitting to the title", not get_tree().paused, "")

	# Put the player's own settings back.
	Game.settings.sensitivity_step = _saved[0]
	Game.settings.volume_percent = _saved[1]
	Game.settings.invert_look = _saved[2]
	Game.settings.save()

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Every MenuPanel below `root`, in tree order (so left to right on screen).
## Hidden branches are skipped, so a closed page's panels don't show up.
func _panels_under(root: Node) -> Array[MenuPanel]:
	var found: Array[MenuPanel] = []
	if root == null:
		return found
	for child in root.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is MenuPanel:
			found.append(child as MenuPanel)
		found.append_array(_panels_under(child))
	return found


func _settings_under(root: Node) -> SettingsMenu:
	for child in root.get_children():
		if child is SettingsMenu:
			return child as SettingsMenu
		var deeper: SettingsMenu = _settings_under(child)
		if deeper != null:
			return deeper
	return null


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	_release.call_deferred(action)


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
