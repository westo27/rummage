extends Node
## Tool, not a test: renders several candidate marble clacks to user://clacks
## so they can be compared by ear and one picked. Each file plays the clack
## three times, slightly varied, with gaps.
## Run: Godot --headless --path . res://tests/render_clacks.tscn

const RATE: int = 22050

## name, [click loudness, click decay s, click brightness 0..1],
## [[ring Hz, loudness, decay s], ...], second hit delay s (0 = none)
const CANDIDATES: Array = [
	["A_bright_crack", [1.0, 0.0012, 0.9], [[2600.0, 0.6, 0.012], [4100.0, 0.4, 0.008]], 0.0],
	["B_solid_clack", [0.9, 0.0015, 0.7], [[1800.0, 0.7, 0.010], [3000.0, 0.5, 0.007], [900.0, 0.3, 0.006]], 0.0],
	["C_double_clack", [1.0, 0.0012, 0.85], [[2400.0, 0.6, 0.010], [3800.0, 0.4, 0.007]], 0.018],
	["D_dry_knock", [1.0, 0.0020, 0.6], [[1500.0, 0.5, 0.006], [2600.0, 0.3, 0.004]], 0.0],
	["E_ringing_glass", [0.7, 0.0010, 0.9], [[2900.0, 0.7, 0.030], [4600.0, 0.45, 0.020]], 0.0],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://clacks")
	for c: Array in CANDIDATES:
		var data := PackedByteArray()
		for take in 3:
			data.append_array(_clack(c, take))
			var gap := PackedByteArray()
			gap.resize(int(0.4 * RATE) * 2)
			data.append_array(gap)
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = RATE
		wav.data = data
		wav.save_to_wav("user://clacks/%s.wav" % c[0])
	print("Saved to %s" % ProjectSettings.globalize_path("user://clacks"))
	get_tree().quit()


func _clack(c: Array, take: int) -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + take
	var click: Array = c[1]
	var rings: Array = []
	for r: Array in c[2]:
		rings.append([r[0] * rng.randf_range(0.93, 1.07), r[1], r[2]])
	var count: int = int(0.12 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var peak: float = 0.0
	for hit in (2 if c[3] > 0.0 else 1):
		var start: int = int(hit * c[3] * RATE)
		var level: float = 1.0 if hit == 0 else 0.6
		var filtered: float = 0.0
		for i in range(start, count):
			var t: float = float(i - start) / RATE
			filtered += (rng.randf_range(-1.0, 1.0) - filtered) * click[2]
			var v: float = filtered * click[0] * exp(-t / click[1])
			for r: Array in rings:
				v += sin(TAU * r[0] * t) * r[1] * exp(-t / r[2])
			out[i] += v * level
	for i in count:
		out[i] *= clampf((count - i) / (0.005 * RATE), 0.0, 1.0)
		peak = maxf(peak, absf(out[i]))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(out[i] / peak * 0.85 * 32767.0))
	return data
