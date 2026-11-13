class_name ImpactAudio
extends Node
## Plays the knock when a prop hits something, from the spot where it
## happened, so a crash behind you sounds behind you.
##
## A small pool of 3D speakers is shared by every prop, rather than one each:
## it caps how many knocks can sound at once, so a whole shelf of books
## tumbling down is a clatter rather than a wall of noise. When every speaker
## is busy, the one that started longest ago is reused.
##
## The Game autoload makes one of these at startup, reachable as Game.impacts.
## prop.gd decides when something was hit and how hard; this decides what
## that sounds like.

const VOICES: int = 14
## Each material's knock is tuned to sound right at roughly this mass (kg).
## Lighter things play it higher and heavier things lower, which is what
## turns the soft pillow thump into the bed's deep thud.
const REFERENCE_MASS: Dictionary = {
	Tones.ImpactMaterial.PAPER: 0.75,
	Tones.ImpactMaterial.WOOD: 7.0,
	Tones.ImpactMaterial.SOFT: 0.4,
	Tones.ImpactMaterial.RUBBER: 0.3,
	Tones.ImpactMaterial.PLASTIC: 2.5,
}

## Every knock played, newest last: {material, at, speed, mass, db, pitch}.
## Kept only so tests can check what was heard; trimmed to the last 64.
var log: Array[Dictionary] = []

var _voices: Array[AudioStreamPlayer3D] = []
var _oldest: int = 0


func _ready() -> void:
	for i in VOICES:
		var voice := AudioStreamPlayer3D.new()
		# The same falloff with distance as the creature squeaks, so the two
		# sit together in the room.
		voice.unit_size = 3.0
		voice.max_distance = 18.0
		add_child(voice)
		_voices.append(voice)


## `speed` is how hard it hit, as the change in velocity the hit caused (m/s).
func play(material: Tones.ImpactMaterial, at: Vector3, speed: float, mass: float) -> void:
	var tune: Tunables = Game.tune
	var hardness: float = clampf(
		(speed - tune.impact_min_speed) / (tune.impact_full_speed - tune.impact_min_speed), 0.0, 1.0)
	# Heavier things are a little louder for the same hit: a 115 kg wardrobe
	# landing gently still makes itself heard.
	var heft: float = clampf(0.4 + 0.12 * log(mass + 1.0) / log(2.0), 0.4, 1.2)
	var loudness: float = hardness * heft
	if loudness < 0.03:
		return
	var voice: AudioStreamPlayer3D = _free_voice()
	voice.stream = Tones.knock(material, randi() % Tones.KNOCK_VARIANTS)
	voice.global_position = at
	voice.volume_db = linear_to_db(loudness) + tune.impact_max_db
	var pitch: float = pow(REFERENCE_MASS[material] / maxf(mass, 0.01), 0.2)
	voice.pitch_scale = clampf(pitch, 0.5, 1.6) * randf_range(0.97, 1.03)
	voice.play()
	log.append({"material": material, "at": at, "speed": speed, "mass": mass,
		"db": voice.volume_db, "pitch": voice.pitch_scale})
	if log.size() > 64:
		log.pop_front()


func _free_voice() -> AudioStreamPlayer3D:
	for voice in _voices:
		if not voice.playing:
			return voice
	var reused: AudioStreamPlayer3D = _voices[_oldest]
	_oldest = (_oldest + 1) % VOICES
	return reused
