class_name Tunables
extends Resource
## Every number worth tweaking lives here.
##
## To tune: open res://config/tunables.tres in the FileSystem dock and edit the
## values in the Inspector. The values saved in the .tres win over the defaults
## written below, so once you change one in the editor, editing the default
## here has no effect on that field (the .tres stores only overridden fields).
##
## Why a Resource and not constants: a Resource is a plain data object Godot can
## save to disk and show in the Inspector, a bit like a config model with a
## form already built for it.

@export_group("World")
## m/s². Applied to the physics world at startup by main.gd, and used by the player.
@export var gravity: float = 14.0
## If the player's feet drop below this height they are put back at the start.
@export var fall_reset_y: float = -5.0

@export_group("Player")
@export var walk_speed: float = 4.5
@export var run_speed: float = 7.5
## Radians of turn per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.0010

@export_group("Beam")
## How far the beam can reach to grab something, in metres.
@export var beam_reach: float = 7.0
## Held object velocity = (distance from hold point) × this. Higher = snappier.
@export var hold_stiffness: float = 12.0
## Held top speed = hold_speed_base / (1 + mass / hold_speed_mass_scale).
@export var hold_speed_base: float = 14.0
@export var hold_speed_mass_scale: float = 8.0
## Throw speed = throw_speed_base / (1 + mass / throw_speed_mass_scale).
@export var throw_speed_base: float = 16.0
@export var throw_speed_mass_scale: float = 6.0
## Closest the hold point gets to the camera (plus the object's own hold_radius).
@export var min_hold_distance: float = 0.9
## Metres the hold point moves per mouse-wheel notch.
@export var hold_distance_step: float = 0.35
## If a held object gets stuck this far from the hold point (e.g. pushed into a
## wall), the beam lets go rather than straining forever.
@export var beam_break_distance: float = 3.0
## Fraction of a held object's spin removed each physics tick, so things
## don't twirl wildly in the beam.
@export_range(0.0, 1.0) var held_spin_damping: float = 0.15
## How strongly the beam line curves toward where you're aiming when the held
## object lags behind. 0 = always straight; around 0.5–0.8 reads well.
@export_range(0.0, 1.0) var beam_arc_bend: float = 0.6

@export_group("Lift")
## Heaviest mass (kg) the beam can lift at the start.
@export var start_lift_limit: float = 10.0
