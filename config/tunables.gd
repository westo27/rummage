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
## Hold C or Ctrl to crouch, Z to lie flat. Running has no effect while down.
@export var crouch_speed: float = 2.5
@export var prone_speed: float = 1.4
## Head height (eyes above the feet) standing, crouched and lying flat, metres.
@export var stand_eye_height: float = 1.15
@export var crouch_eye_height: float = 0.6
@export var prone_eye_height: float = 0.16
## Radians of turn per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.0004
## Props this light or lighter are "clutter": the player walks through them,
## kicking them aside, instead of being blocked. Heavier props block the player.
@export var player_push_max_mass: float = 3.0
## Clutter is kicked ahead at this multiple of the player's walking speed.
@export var player_kick_factor: float = 1.3

@export_group("Beam")
## How far the beam can reach to grab something, in metres.
@export var beam_reach: float = 4.0
## Held object velocity = (distance from hold point) × this. Higher = snappier.
@export var hold_stiffness: float = 12.0
## Held top speed = hold_speed_base / (1 + mass / hold_speed_mass_scale).
@export var hold_speed_base: float = 9.0
@export var hold_speed_mass_scale: float = 8.0
## Throw speed = throw_speed_base / (1 + mass / throw_speed_mass_scale).
@export var throw_speed_base: float = 10.0
@export var throw_speed_mass_scale: float = 6.0
## Share of its speed a held thing keeps when you let go, so a swing tosses it
## a little way rather than across the room.
@export_range(0.0, 1.0) var release_speed_keep: float = 0.5
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
@export var start_lift_limit: float = 4.0
## Added to the lift limit per creature caught. 0 now that furniture is fixed:
## everything the beam can grab is under the starting limit.
@export var lift_per_capture: float = 0.0

@export_group("Creatures")
## Running speed while fleeing, m/s.
@export var flee_speed: float = 2.2
## A revealed creature runs away for a random time in this range, in seconds…
@export var flee_time_min: float = 2.0
@export var flee_time_max: float = 3.5
## …then spends up to this long running to a nearby object to cower beside.
@export var seek_time: float = 2.5
## Upward speed of the startled hop when a creature is uncovered.
@export var pop_speed: float = 3.0
## A cowering creature bolts again if the player gets this close (metres).
@export var startle_distance: float = 1.3
## A hidden creature gives itself away (squeak + rattle/glow/hop) at random
## intervals in this range, in seconds.
@export var tell_interval_min: float = 7.0
@export var tell_interval_max: float = 18.0
## Moving a covering object more than this (metres) uncovers the creature.
@export var disturb_distance: float = 0.06
## A prop flying faster than this (m/s) past a creature startles it.
@export var knock_speed: float = 1.5
## A covering object jolted to this speed (m/s), e.g. by something thrown at
## it, startles the creature under it even if it barely moves. (Not used for
## the bed's creatures, so its gate can't be skipped by pelting it.)
@export var jolt_speed: float = 0.35
## Loudness of creature squeaks, in decibels (0 = full, -10 = quieter).
@export var squeak_volume_db: float = -4.0

@export_group("Ping")
## Seconds between pings (Q).
@export var ping_cooldown: float = 8.0
## Hidden creatures within this many metres answer a ping.
@export var ping_radius: float = 4.5
## Each creature answers after (its distance × this) seconds, so the answers
## ripple outward like sonar and nearer ones come first.
@export var ping_delay_per_metre: float = 0.07

@export_group("Impacts")
## A hit has to change an object's speed by at least this much (m/s) to make
## a sound. Below it, things settling, rolling and sliding stay quiet.
@export var impact_min_speed: float = 0.8
## A hit this hard (m/s) or harder plays at full loudness. A crate dropped
## from head height lands at about 7.
@export var impact_full_speed: float = 7.0
## Loudness of the hardest knock, in decibels. The creature squeaks play at
## squeak_volume_db (-4); keeping this well below means a squeak can always
## be heard through a crash.
@export var impact_max_db: float = -10.0
