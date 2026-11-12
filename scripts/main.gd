extends Node3D
## Root of the main scene. Applies world settings and handles restart.


func _ready() -> void:
	# Gravity for rigid bodies lives on the physics "space" (the simulated world),
	# not on each body. Setting it here means the value comes from tunables.tres
	# instead of a second copy in Project Settings.
	var space: RID = get_world_3d().space
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, Game.tune.gravity)


# _unhandled_input only receives events nothing else (such as UI) has consumed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		# Throws away the whole scene tree under Main and loads it fresh from the
		# .tscn file. The Game autoload is not part of the scene, so it survives.
		get_tree().reload_current_scene()
