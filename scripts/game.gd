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

## How a caught creature leaves the room. Three versions to compare in play,
## switched with the 1, 2 and 3 keys (main.gd). Kept here rather than in the
## scene so the choice survives pressing R. Temporary: once one is chosen,
## the other two and the keys can go.
enum CatchStyle { FLY_TO_BAG, POP, SUCK }
const CATCH_STYLE_NAMES: Array[String] = ["flies into the bag", "pops on the spot", "sucked into the beam"]
var catch_style: CatchStyle = CatchStyle.FLY_TO_BAG


func _ready() -> void:
	_setup_input_map()
	# Settings reads its default sensitivity from `tune`, so it's built after
	# the preload above has run.
	settings = Settings.new()
	settings.load_from_disk()
	settings.apply_audio()
	# Swap the mouse arrow for the menus' pointing hand. See pointer_cursor.gd.
	add_child(PointerCursor.new())
	impacts = ImpactAudio.new()
	add_child(impacts)


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
	_add_key("release_mouse", KEY_ESCAPE)
	_add_key("restart", KEY_R)
	_add_key("ping", KEY_Q)
	_add_key("throw", KEY_F)
	_add_mouse("throw", MOUSE_BUTTON_RIGHT)
	_add_mouse("grab", MOUSE_BUTTON_LEFT)
	_add_mouse("beam_nearer", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse("beam_further", MOUSE_BUTTON_WHEEL_UP)
	# Temporary: compare the three catch styles (see CatchStyle above).
	_add_key("catch_style_1", KEY_1)
	_add_key("catch_style_2", KEY_2)
	_add_key("catch_style_3", KEY_3)


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
