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


## The catch: a wet, cartoony slurp as the beam sucks the creature up,
## ending in a little "plop".
##
## The slurp is noise through a single resonance whose frequency sweeps
## upward, like the "ooo-ee" of air rushing through a narrowing straw. Its
## loudness wobbles about 28 times a second, which is the bubbly, gurgling
## part. The plop is a quick upward blip at the end.
static func slurp() -> AudioStreamWAV:
	if _cache.has("slurp"):
		return _cache["slurp"]
	const LENGTH: float = 0.38
	const SWEEP_END: float = 0.30
	const PLOP_AT: float = 0.30
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var count: int = int(LENGTH * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var y1: float = 0.0
	var y2: float = 0.0
	var plop_phase: float = 0.0
	var peak: float = 0.0
	for i in count:
		var t: float = float(i) / MIX_RATE
		# Resonance rises from 250 Hz to about 1750 Hz over the sweep.
		var hz: float = 250.0 * pow(7.0, minf(t / SWEEP_END, 1.0))
		var w: float = TAU * hz / MIX_RATE
		var r: float = exp(-PI * (hz / 6.0) / MIX_RATE)
		var y: float = (1.0 - r) * 2.0 * sin(w) * rng.randf_range(-1.0, 1.0) \
			+ 2.0 * r * cos(w) * y1 - r * r * y2
		y2 = y1
		y1 = y
		var gurgle: float = 0.55 + 0.45 * sin(TAU * 28.0 * t)
		var envelope: float = minf(t / 0.03, 1.0) * clampf((SWEEP_END + 0.02 - t) / 0.04, 0.0, 1.0)
		var value: float = y * gurgle * envelope * 3.0
		if t >= PLOP_AT:
			var p: float = t - PLOP_AT
			plop_phase += TAU * lerpf(350.0, 900.0, minf(p / 0.025, 1.0)) / MIX_RATE
			value += sin(plop_phase) * 0.7 * exp(-p / 0.03)
		samples[i] = value * clampf((count - i) / (0.01 * MIX_RATE), 0.0, 1.0)
		peak = maxf(peak, absf(samples[i]))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(samples[i] / peak * 0.85 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	_cache["slurp"] = wav
	return wav


## What a prop is made of, which decides how it sounds when it hits something.
## Set per prop scene (Prop.impact_material).
enum ImpactMaterial { PAPER, WOOD, SOFT, RUBBER, PLASTIC }

## How many slightly different takes of each knock are made, so the same
## object hitting the floor twice doesn't sound copy-pasted.
const KNOCK_VARIANTS: int = 3

## How sharply the knocks' resonances ring, as a multiplier on each one's
## sharpness. Lower = drier and noisier, with no sense of pitch; higher =
## more of the object's body ringing through. Kept below the point where
## the resonances turn into notes, which makes a pile of falling things
## sound like a tune.
static var resonance: float = 1.0

## The recipe for each material's knock. A knock is built from four parts,
## none of which is a steady musical note:
##   click   [loudness, fade s]  the tick at the moment of contact
##   noise   [loudness, fade s, brightness 0..1]  the slap or scuff
##   modes   [[centre Hz, loudness, fade s, sharpness]]  noise filtered through
##           wide resonances, which give it a wooden or plastic colour
##           without a pitch you could hum. Sharpness is how narrow the
##           resonance is; under about 5 it's a colour, not a note.
##   thump   [Hz, loudness, fade s]  a low thud that starts higher and drops
##           fast, like a kick drum: reads as weight rather than as pitch.
##   length, attack  in seconds; soft things push in slowly.
const KNOCK_RECIPES: Dictionary = {
	ImpactMaterial.PAPER: {"length": 0.10, "attack": 0.0005,
		"click": [0.6, 0.003], "noise": [0.9, 0.02, 0.6],
		"modes": [[900.0, 0.4, 0.015, 1.5], [2500.0, 0.3, 0.01, 1.5]],
		"thump": [140.0, 0.2, 0.015]},
	ImpactMaterial.WOOD: {"length": 0.22, "attack": 0.0005,
		"click": [0.7, 0.003], "noise": [0.55, 0.02, 0.15],
		"modes": [[350.0, 0.7, 0.05, 4.0], [900.0, 0.45, 0.03, 4.0], [1700.0, 0.25, 0.02, 3.0]],
		"thump": [110.0, 0.5, 0.025]},
	ImpactMaterial.SOFT: {"length": 0.22, "attack": 0.004,
		"click": [0.0, 0.003], "noise": [0.9, 0.06, 0.04],
		"modes": [[200.0, 0.3, 0.04, 1.2]],
		"thump": [70.0, 0.6, 0.03]},
	ImpactMaterial.RUBBER: {"length": 0.18, "attack": 0.002,
		"click": [0.3, 0.002], "noise": [0.45, 0.02, 0.2],
		"modes": [[600.0, 0.3, 0.03, 3.0]],
		"thump": [180.0, 0.5, 0.02]},
	ImpactMaterial.PLASTIC: {"length": 0.12, "attack": 0.0005,
		"click": [0.8, 0.002], "noise": [0.5, 0.012, 0.5],
		"modes": [[1200.0, 0.5, 0.025, 3.0], [2600.0, 0.4, 0.015, 3.0]],
		"thump": [160.0, 0.2, 0.015]},
}


## One take of a material's knock. Built once and cached, like the others.
## Each take uses different noise and nudges the resonances a little.
static func knock(material: ImpactMaterial, variant: int) -> AudioStreamWAV:
	var key: String = "knock-%d-%d-%.2f" % [material, variant, resonance]
	if _cache.has(key):
		return _cache[key]

	var recipe: Dictionary = KNOCK_RECIPES[material]
	# A seeded random generator: the same material and take always gives the
	# same sound, so it doesn't change between runs.
	var rng := RandomNumberGenerator.new()
	rng.seed = material * 100 + variant

	# Each resonance is a two-pole filter: it rings at its centre frequency
	# when fed noise, for as long as its sharpness lets it. r is how much of
	# its ring survives each sample; b scales the input so it peaks near 1.
	var filters: Array = []
	for mode: Array in recipe["modes"]:
		var hz: float = mode[0] * rng.randf_range(0.93, 1.07)
		var w: float = TAU * hz / MIX_RATE
		var bandwidth: float = hz / maxf(mode[3] * resonance, 0.3)
		var r: float = exp(-PI * bandwidth / MIX_RATE)
		filters.append({"a1": 2.0 * r * cos(w), "a2": -r * r, "b": (1.0 - r) * 2.0 * sin(w) + 0.001,
			"amp": mode[1], "fade": mode[2], "y1": 0.0, "y2": 0.0})

	var click: Array = recipe["click"]
	var noise: Array = recipe["noise"]
	var thump: Array = recipe["thump"]
	var length: int = int(recipe["length"] * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(length)
	var filtered: float = 0.0
	var previous: float = 0.0
	var thump_phase: float = 0.0
	var peak: float = 0.0
	for i in length:
		var t: float = float(i) / MIX_RATE
		var white: float = rng.randf_range(-1.0, 1.0)
		# Click: the change from one noise sample to the next is very bright,
		# like the first instant of contact.
		var value: float = (white - previous) * 0.5 * click[0] * exp(-t / click[1])
		previous = white
		# Scuff: noise through a one-pole low-pass. Brightness near 1 is a
		# hiss, near 0 a rumble.
		filtered += (white - filtered) * noise[2]
		value += filtered * noise[0] * exp(-t / noise[1])
		for f: Dictionary in filters:
			var y: float = f.b * white + f.a1 * f.y1 + f.a2 * f.y2
			f.y2 = f.y1
			f.y1 = y
			value += y * f.amp * exp(-t / f.fade)
		# Thud: a sine whose pitch falls from 2.5x to 1x in the first ~15 ms.
		thump_phase += TAU * thump[0] * (1.0 + 1.5 * exp(-t / 0.012)) / MIX_RATE
		value += sin(thump_phase) * thump[1] * exp(-t / thump[2])

		var attack: float = minf(t / recipe["attack"], 1.0)
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


## The beam's hum while holding something: a warm, rounded whirr with a gentle
## wobble, like a friendly toy gadget. A seamless loop: beam.gd plays it on
## repeat and bends its pitch and loudness as you swing.
##
## Every frequency in it (tone, harmonics, wobbles) goes through a whole
## number of cycles in the loop's one second, so the end joins the start
## without a click.
static func whirr() -> AudioStreamWAV:
	if _cache.has("whirr"):
		return _cache["whirr"]
	const SECONDS: int = 1
	const TONE: float = 140.0
	var count: int = SECONDS * MIX_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var samples := PackedFloat32Array()
	samples.resize(count)
	var breath: float = 0.0
	var peak: float = 0.0
	for i in count:
		var t: float = float(i) / MIX_RATE
		# A slow sway in pitch (5 times a second) and in loudness (3 times).
		var sway: float = 0.35 * sin(TAU * 5.0 * t)
		var tone: float = sin(TAU * TONE * t + sway) * 0.6 \
			+ sin(TAU * TONE * 2.0 * t + sway * 2.0) * 0.22 \
			+ sin(TAU * TONE * 3.0 * t + sway * 3.0) * 0.08
		var swell: float = 0.85 + 0.15 * sin(TAU * 3.0 * t)
		# A whisper of soft air under it, so it's not a pure electronic tone.
		breath += (rng.randf_range(-1.0, 1.0) - breath) * 0.08
		samples[i] = tone * swell + breath * 0.25
		peak = maxf(peak, absf(samples[i]))
	return _store_loop("whirr", samples, peak)


## The beam straining against something too heavy: a strained, wavering hum
## with irregular electric crackles and pops over it. A seamless two-second
## loop; the pops are kept clear of its ends so the join can't click.
static func strain_crackle() -> AudioStreamWAV:
	if _cache.has("strain"):
		return _cache["strain"]
	const SECONDS: int = 2
	var count: int = SECONDS * MIX_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var samples := PackedFloat32Array()
	samples.resize(count)
	# The pops, laid out first as one loudness curve: each starts at a random
	# moment, at a random loudness, and dies away within a few milliseconds.
	var crackle := PackedFloat32Array()
	crackle.resize(count)
	var at: float = 0.02
	while at < SECONDS - 0.04:
		var start: int = int(at * MIX_RATE)
		var loudness: float = rng.randf_range(0.4, 1.0)
		var decay: float = rng.randf_range(0.002, 0.008) * MIX_RATE
		for j in int(0.03 * MIX_RATE):
			crackle[start + j] += loudness * exp(-j / decay)
		at += rng.randf_range(0.02, 0.14)
	var previous: float = 0.0
	var fizz: float = 0.0
	var peak: float = 0.0
	for i in count:
		var t: float = float(i) / MIX_RATE
		# The strained hum: higher than the whirr, wobbling fast and unevenly,
		# and driven hard (tanh) so it's edgy rather than round.
		var wobble: float = 1.2 * sin(TAU * 11.0 * t) + 0.8 * sin(TAU * 3.0 * t)
		var hum: float = tanh(1.8 * sin(TAU * 220.0 * t + wobble)) * 0.32
		var white: float = rng.randf_range(-1.0, 1.0)
		# Fizz: a thin, restless hiss under everything.
		fizz += (white - fizz) * 0.6
		var value: float = hum + (white - previous) * 0.04 + fizz * 0.03 * (0.5 + 0.5 * sin(TAU * 7.0 * t))
		previous = white
		# Crackles: bright noise, shaped by the pops' loudness curve.
		value += white * crackle[i]
		samples[i] = value
		peak = maxf(peak, absf(value))
	return _store_loop("strain", samples, peak)


## Turns samples into a looping sound, peaking at the same level as the rest.
static func _store_loop(key: String, samples: PackedFloat32Array, peak: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(samples[i] / peak * 0.8 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples.size()
	_cache[key] = wav
	return wav


## Marbles knocking together in the HUD bag: very short and high, so it reads
## as glass or stone rather than a voice.
static func clack(variant: int = 0) -> AudioStreamWAV:
	var key: String = "clack-%d" % variant
	if _cache.has(key):
		return _cache[key]
	# Two glass marbles hitting: a crack with body rather than a tick. A
	# softened click, a short low knock underneath for weight, and a ring at
	# two unrelated mid-high pitches (unrelated is what makes it glass rather
	# than a note), dying away over about 60 ms.
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + variant
	var ring_a: float = 1400.0 * rng.randf_range(0.92, 1.08)
	var ring_b: float = 2300.0 * rng.randf_range(0.92, 1.08)
	var knock: float = 750.0 * rng.randf_range(0.9, 1.1)
	var count: int = int(0.09 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var soft: float = 0.0
	var peak: float = 0.0
	for i in count:
		var t: float = float(i) / MIX_RATE
		# Noise through a gentle low-pass: a crack, not a hiss.
		soft += (rng.randf_range(-1.0, 1.0) - soft) * 0.45
		var click: float = soft * exp(-t / 0.002)
		var body: float = sin(TAU * knock * t) * exp(-t / 0.012) * 0.6
		var ring: float = sin(TAU * ring_a * t) * exp(-t / 0.035) * 0.7 			+ sin(TAU * ring_b * t) * exp(-t / 0.022) * 0.4
		samples[i] = (click * 0.9 + body + ring) * clampf((count - i) / (0.006 * MIX_RATE), 0.0, 1.0)
		peak = maxf(peak, absf(samples[i]))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(samples[i] / peak * 0.85 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	_cache[key] = wav
	return wav


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
