class_name Tones
## Builds short sound effects from maths, so the project needs no audio files.
##
## Everything here is `static`: call it as Tones.squeak() without creating an
## object, like a static helper class in PHP. Generated sounds are cached so
## each one is built only once.

const MIX_RATE: int = 22050

static var _cache: Dictionary = {}


## A short rising chirp: the creature voice.
static func squeak() -> AudioStreamWAV:
	return chirp(1500.0, 2600.0, 0.09)


## A longer rising sweep: played when you catch a creature.
static func capture() -> AudioStreamWAV:
	return chirp(500.0, 1900.0, 0.2)


## What a prop is made of, which decides how it sounds when it hits something.
## Set per prop scene (Prop.impact_material).
enum ImpactMaterial { PAPER, WOOD, SOFT, RUBBER, PLASTIC }

## How many slightly different takes of each knock are made, so the same
## object hitting the floor twice doesn't sound copy-pasted.
const KNOCK_VARIANTS: int = 3

## The recipe for each material's knock. A knock is a burst of noise (the
## slap or click of contact) plus a few ringing tones (the body of the object
## sounding), each fading away at its own rate.
##   length   seconds of audio
##   attack   seconds to reach full volume (soft things push in slowly)
##   noise    [loudness, fade time in s, brightness 0..1]
##   modes    ringing tones: [frequency Hz, loudness, fade time in s]
##   drop     how much higher the tones start than they end (rubber's "bonk")
const KNOCK_RECIPES: Dictionary = {
	ImpactMaterial.PAPER: {"length": 0.12, "attack": 0.0005, "noise": [0.9, 0.018, 0.55],
		"modes": [[260.0, 0.35, 0.03], [640.0, 0.15, 0.02]], "drop": 0.0},
	ImpactMaterial.WOOD: {"length": 0.32, "attack": 0.0005, "noise": [0.45, 0.012, 0.35],
		"modes": [[180.0, 0.55, 0.11], [420.0, 0.4, 0.07], [810.0, 0.2, 0.04]], "drop": 0.0},
	ImpactMaterial.SOFT: {"length": 0.26, "attack": 0.006, "noise": [0.5, 0.05, 0.06],
		"modes": [[95.0, 0.6, 0.07]], "drop": 0.0},
	ImpactMaterial.RUBBER: {"length": 0.22, "attack": 0.002, "noise": [0.12, 0.01, 0.3],
		"modes": [[230.0, 0.75, 0.09], [560.0, 0.15, 0.04]], "drop": 0.3},
	ImpactMaterial.PLASTIC: {"length": 0.16, "attack": 0.0005, "noise": [0.5, 0.015, 0.5],
		"modes": [[520.0, 0.4, 0.05], [1150.0, 0.3, 0.035], [1900.0, 0.15, 0.02]], "drop": 0.0},
}


## One take of a material's knock. Built once and cached, like the others.
## Each variant nudges the tones' pitches a little and uses different noise.
static func knock(material: ImpactMaterial, variant: int) -> AudioStreamWAV:
	var key: String = "knock-%d-%d" % [material, variant]
	if _cache.has(key):
		return _cache[key]

	var recipe: Dictionary = KNOCK_RECIPES[material]
	# A seeded random generator: the same material and variant always gives
	# the same sound, so it doesn't change between runs.
	var rng := RandomNumberGenerator.new()
	rng.seed = material * 100 + variant
	var modes: Array = []
	for mode: Array in recipe["modes"]:
		modes.append([mode[0] * rng.randf_range(0.94, 1.06), mode[1], mode[2]])

	var length: int = int(recipe["length"] * MIX_RATE)
	var noise: Array = recipe["noise"]
	var samples := PackedFloat32Array()
	samples.resize(length)
	var phases := PackedFloat32Array()
	phases.resize(modes.size())
	var filtered: float = 0.0
	var peak: float = 0.0
	for i in length:
		var t: float = float(i) / MIX_RATE
		var attack: float = minf(t / recipe["attack"], 1.0)
		# Noise through a one-pole low-pass filter: brightness 1 lets it all
		# through (a hiss), near 0 leaves only the low rumble (a thud).
		filtered += (rng.randf_range(-1.0, 1.0) - filtered) * noise[2]
		var value: float = filtered * noise[0] * exp(-t / noise[1])
		var bend: float = 1.0 + recipe["drop"] * exp(-t / 0.03)
		for m in modes.size():
			var mode: Array = modes[m]
			phases[m] += TAU * mode[0] * bend / MIX_RATE
			value += sin(phases[m]) * mode[1] * exp(-t / mode[2])
		# Fade the last 10 ms to silence so the end never clicks.
		var tail: float = clampf((length - i) / (0.01 * MIX_RATE), 0.0, 1.0)
		value *= attack * tail
		samples[i] = value
		peak = maxf(peak, absf(value))

	# Every take peaks at the same level, so loudness is set only at play time.
	var data := PackedByteArray()
	data.resize(length * 2)
	for i in length:
		data.encode_s16(i * 2, int(samples[i] / peak * 0.85 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	_cache[key] = wav
	return wav


## Marbles knocking together in the HUD bag: very short and high, so it reads
## as glass or stone rather than a voice.
static func clack() -> AudioStreamWAV:
	return chirp(2900.0, 2200.0, 0.03)


## Menu sounds. Soft and short: a single high blip when the pointer lands on a
## panel, a rising pair when you choose one, a falling pair when you back out.
static func ui_hover() -> AudioStreamWAV:
	return notes([1660.0], 0.04, 0.10)


static func ui_select() -> AudioStreamWAV:
	return notes([880.0, 1318.5], 0.07, 0.22)


static func ui_back() -> AudioStreamWAV:
	return notes([1318.5, 880.0], 0.065, 0.20)


## One sine tone per entry in `hz`, played one after another, each faded in and
## out. Used for the little two-note menu chimes.
static func notes(hz: Array, seconds_each: float, volume: float) -> AudioStreamWAV:
	var key: String = "notes-%s-%d-%d" % [hz, seconds_each * 1000.0, volume * 100.0]
	if _cache.has(key):
		return _cache[key]

	var per_note: int = int(seconds_each * MIX_RATE)
	var data := PackedByteArray()
	data.resize(per_note * hz.size() * 2)
	var index: int = 0
	for note_hz: float in hz:
		var phase: float = 0.0
		for i in per_note:
			var t: float = float(i) / per_note
			phase += TAU * note_hz / MIX_RATE
			var envelope: float = sin(PI * t)  # 0 → 1 → 0, so no click either end
			data.encode_s16(index * 2, int(sin(phase) * envelope * volume * 32767.0))
			index += 1

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	_cache[key] = wav
	return wav


## A sine wave that slides from one pitch to another, faded in and out so it
## doesn't click. Written as 16-bit samples into an AudioStreamWAV.
static func chirp(from_hz: float, to_hz: float, seconds: float) -> AudioStreamWAV:
	var key: String = "%d-%d-%d" % [from_hz, to_hz, seconds * 1000.0]
	if _cache.has(key):
		return _cache[key]

	var sample_count: int = int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)  # 2 bytes per 16-bit sample
	var phase: float = 0.0
	for i in sample_count:
		var t: float = float(i) / sample_count
		phase += TAU * lerpf(from_hz, to_hz, t) / MIX_RATE
		var envelope: float = sin(PI * t)  # 0 → 1 → 0
		data.encode_s16(i * 2, int(sin(phase) * envelope * 0.45 * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	_cache[key] = wav
	return wav
