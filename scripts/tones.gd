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
