extends Node
## Autoload registered as "Game" (Project Settings > Globals).
##
## An autoload is a node Godot creates once at startup and keeps alive above
## every scene, so any script can write `Game.tune.walk_speed`. Think of it as
## a service container entry. It survives scene reloads (the R restart).
##
## It does two jobs: hands out the tunables, and defines the controls.

var tune: Tunables = preload("res://config/tunables.tres")


func _ready() -> void:
	_setup_input_map()


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
