extends Node
## Autoload registered as "Game" (Project Settings > Globals).
##
## An autoload is a node Godot creates once at startup and keeps alive above
## every scene, so any script can write `Game.tune.walk_speed`. Think of it as
## a service container entry. It survives scene reloads (the R restart).
##
## It does three jobs: hands out the tunables, holds the player's saved
## settings, and defines the controls.

var tune: Tunables = preload("res://config/tunables.tres")
## The player's own preferences (look sensitivity, volume, invert). Lives here
## so it survives scene changes and restarts. See scripts/settings.gd.
var settings: Settings
## Plays the knocks when props hit things. See scripts/impact_audio.gd.
var impacts: ImpactAudio
## The soft low-res look, switched by Graphics > Screen filter.
var screen_filter: ScreenFilter
## main.tscn once the title has loaded it. Holding it keeps its resources
## (and so their compiled shaders) alive across the change to the game.
var main_scene: PackedScene
## Shaders the title warmed up, held so they stay compiled for the game.
var kept: Array[Resource] = []
## Temporary: number keys switch looks (see look_switcher.gd).
var looks: LookSwitcher
## Set by the user arg `hands_off` (tools/run_tests.sh passes it): the window
## can't take focus and never really captures the mouse, and real mouse
## movement is ignored, so a test can run beside you while you work.
## Tests drive input with Input.parse_input_event, which still arrives.
var hands_off: bool = "hands_off" in OS.get_cmdline_user_args()
## Whether the mouse counts as captured while hands_off (see capture_mouse).
var _fake_captured: bool = false


func _ready() -> void:
	_setup_input_map()
	if hands_off:
		get_window().unfocusable = true
	# Settings reads its default sensitivity from `tune`, so it's built after
	# the preload above has run.
	settings = Settings.new()
	settings.load_from_disk()
	settings.apply_audio()
	settings.apply_lighting()
	screen_filter = ScreenFilter.new()
	add_child(screen_filter)
	settings.apply_screen_filter()
	get_tree().root.size_changed.connect(settings.apply_render_scale)
	# Temporary: 1/2/3 switch looks while choosing an art direction.
	looks = LookSwitcher.new()
	add_child(looks)
	impacts = ImpactAudio.new()
	add_child(impacts)


## Captures the mouse for mouse look, or frees it for menus. Use this rather
## than setting Input.mouse_mode, so hands_off runs can fake it: a real
## capture would grab the cursor even in a window without focus.
func capture_mouse(on: bool) -> void:
	if hands_off:
		_fake_captured = on
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func mouse_captured() -> bool:
	if hands_off:
		return _fake_captured
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Lets go of the held scene and shaders on quit, so Godot doesn't report them
## as leaked.
func _exit_tree() -> void:
	main_scene = null
	kept.clear()


## Controls are defined here in code rather than in Project Settings > Input Map
## because the project.godot format for key events is very verbose and hard to
## read. The result is the same: named actions that scripts ask about with
## Input.is_action_pressed("run") and so on.
##
## physical_keycode means "the key in this position", so WASD stays WASD on
## non-QWERTY keyboards.
func _setup_input_map() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("run", KEY_SHIFT)
	_add_key("crouch", KEY_C)
	_add_key("crouch", KEY_CTRL)
	_add_key("prone", KEY_Z)
	_add_key("release_mouse", KEY_ESCAPE)
	_add_key("restart", KEY_R)
	_add_key("ping", KEY_Q)
	_add_key("throw", KEY_F)
	_add_mouse("throw", MOUSE_BUTTON_RIGHT)
	_add_mouse("grab", MOUSE_BUTTON_LEFT)
	_add_mouse("beam_nearer", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse("beam_further", MOUSE_BUTTON_WHEEL_UP)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
