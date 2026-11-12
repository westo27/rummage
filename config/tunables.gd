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
@export var mouse_sensitivity: float = 0.0025
