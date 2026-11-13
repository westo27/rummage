class_name Settings
extends RefCounted
## The player's own preferences, saved between runs.
##
## Separate from Tunables: tunables are design numbers you tweak while making
## the game, these are choices the player makes and expects to stick. They live
## in `user://settings.cfg`, which on Windows is under %APPDATA%/Godot/app_userdata.
##
## Held by the Game autoload as `Game.settings`, so it survives scene reloads.

const PATH: String = "user://settings.cfg"

## Look sensitivity as a whole number of steps, which is what the menu shows.
## Multiplied by SENSITIVITY_PER_STEP to get radians of turn per mouse pixel.
const SENSITIVITY_PER_STEP: float = 0.00005
const SENSITIVITY_MIN: int = 1
const SENSITIVITY_MAX: int = 24
## Volume as a percentage, in steps of 5.
const VOLUME_STEP: int = 5

var sensitivity_step: int = 8
var volume_percent: int = 80
## When on, moving the mouse down looks up, as in a flight sim.
var invert_look: bool = false

var _loaded_from_disk: bool = false


func _init() -> void:
	# Seed the default from the tunable, so there's one place to change what a
	# brand-new player gets.
	sensitivity_step = clampi(
		int(round(Game.tune.mouse_sensitivity / SENSITIVITY_PER_STEP)),
		SENSITIVITY_MIN, SENSITIVITY_MAX)


## Radians of turn per pixel of mouse movement, what player.gd actually uses.
func mouse_sensitivity() -> float:
	return sensitivity_step * SENSITIVITY_PER_STEP


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # no file yet: first run, keep the defaults
	sensitivity_step = clampi(int(cfg.get_value("look", "sensitivity_step", sensitivity_step)),
		SENSITIVITY_MIN, SENSITIVITY_MAX)
	invert_look = bool(cfg.get_value("look", "invert", invert_look))
	volume_percent = clampi(int(cfg.get_value("audio", "volume_percent", volume_percent)), 0, 100)
	_loaded_from_disk = true


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "sensitivity_step", sensitivity_step)
	cfg.set_value("look", "invert", invert_look)
	cfg.set_value("audio", "volume_percent", volume_percent)
	cfg.save(PATH)


## Pushes the audio setting into the mixer. The look settings are read live by
## player.gd, so they need no applying.
func apply_audio() -> void:
	# Bus 0 is "Master". Volume is in decibels, a logarithmic scale, so a
	# percentage has to be converted rather than used directly.
	var bus: int = AudioServer.get_bus_index("Master")
	if volume_percent <= 0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(volume_percent / 100.0))


func adjust_sensitivity(by: int) -> void:
	sensitivity_step = clampi(sensitivity_step + by, SENSITIVITY_MIN, SENSITIVITY_MAX)


func adjust_volume(by: int) -> void:
	volume_percent = clampi(volume_percent + by * VOLUME_STEP, 0, 100)
	apply_audio()
