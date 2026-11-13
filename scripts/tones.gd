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
