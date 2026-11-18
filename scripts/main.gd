extends Node3D
## Root of the main scene and the game's flow: physics setup, wiring systems to
## the HUD, counting catches, the timer, winning, restart.

@onready var _beam: Beam = $Player/Head/Camera3D/Beam
@onready var _hud: Hud = $HUD
@onready var _ping: Ping = $Ping

var _caught: int = 0
var _total_creatures: int = 0
var _elapsed: float = 0.0
var _won: bool = false


# Godot calls _ready on children before their parent, so by the time this runs
# the beam, HUD, props and creatures have already set themselves up.
func _ready() -> void:
	# Gravity for rigid bodies lives on the physics "space" (the simulated world),
	# not on each body. Setting it here means the value comes from tunables.tres
	# instead of a second copy in Project Settings.
	set_up_world(self)
	# The browser build is the bedroom-only demo (see web_demo.gd).
	if WebDemo.active():
		WebDemo.strip(self, $Player)
		WebDemo.light(self)

	# connect() subscribes a function to a signal: whenever the beam emits
	# aim_changed, hud.set_aim is called with the same arguments.
	_beam.aim_changed.connect(_hud.set_aim)
	_beam.lift_limit_changed.connect(_hud.set_lift_limit)
	_ping.cooldown_changed.connect(_hud.set_ping_cooldown)
	_hud.set_lift_limit(_beam.lift_limit)

	# Each creature added itself to the "creatures" group in its own _ready.
	for creature: Creature in get_tree().get_nodes_in_group("creatures"):
		creature.captured.connect(_on_creature_captured)
		_total_creatures += 1
	_hud.set_caught(_caught, _total_creatures)

	# Graphics > Lighting, for this level's lamps and environment.
	Game.settings.apply_lighting(self)


func _process(delta: float) -> void:
	if not _won:
		_elapsed += delta
		_hud.set_time(_elapsed)


# _unhandled_input only receives events nothing else (such as UI) has consumed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		# Throws away the whole scene tree under Main and loads it fresh from the
		# .tscn file. The Game autoload is not part of the scene, so it survives.
		get_tree().reload_current_scene()


## Gives every prop a finish that suits what it's made of (the same material
## that picks its knock sound): matte painted wood, flat fabric and paper, and
## a soft satin on plastic and rubber toys. Roughness is how blurry
## reflections are (0 = mirror, 1 = chalk); specular is how strong they are.
## (The earlier all-glossy clearcoat finish read as too plastic.) Prop
## materials are shared between copies of the same prop, so this sets the
## same values on a material several times; that's harmless.
const FINISH: Dictionary = {
	Tones.ImpactMaterial.WOOD: [0.72, 0.35],
	Tones.ImpactMaterial.PAPER: [0.9, 0.25],
	Tones.ImpactMaterial.SOFT: [0.95, 0.2],
	Tones.ImpactMaterial.RUBBER: [0.55, 0.4],
	Tones.ImpactMaterial.PLASTIC: [0.45, 0.45],
}


## Gravity and the prop finishes. Static so the title screen's backdrop
## (title_backdrop.gd), which shows this scene without this script, can use it.
static func set_up_world(scene: Node3D) -> void:
	var space: RID = scene.get_world_3d().space
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, Game.tune.gravity)
	_apply_prop_finish(scene.get_tree())


static func _apply_prop_finish(tree: SceneTree) -> void:
	for prop: Prop in tree.get_nodes_in_group("props"):
		var finish: Array = FINISH[prop.impact_material]
		for child in prop.get_children():
			var mesh := child as MeshInstance3D
			if mesh == null or not (mesh.material_override is StandardMaterial3D):
				continue
			var material := mesh.material_override as StandardMaterial3D
			material.roughness = finish[0]
			material.metallic_specular = finish[1]
			material.clearcoat_enabled = false


func _on_creature_captured(creature: Creature) -> void:
	_caught += 1
	_hud.add_to_bag(creature.body_color, creature.face)
	_beam.add_lift(Game.tune.lift_per_capture)
	_hud.set_caught(_caught, _total_creatures)
	if _caught >= _total_creatures:
		_won = true
		_end_play()
		_hud.show_win(_elapsed, _total_creatures)


## Once everything is caught the win screen has buttons to click, so stop the
## things that would otherwise react to the mouse or Esc: the player (who
## recaptures the cursor on any click), the beam (which grabs on click) and the
## pause menu. R still restarts, because that's handled here.
func _end_play() -> void:
	$Player.set_process_input(false)
	_beam.set_process_unhandled_input(false)
	$PauseMenu.set_process_unhandled_input(false)
