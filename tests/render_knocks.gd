extends Node
## Tool, not a test: saves each prop's knock as a WAV in user://knocks, at the
## pitch it plays for that prop's mass, so they can be listened to outside the
## game. Each file has the three variants one after another.
## Run: Godot --headless --path . res://tests/render_knocks.tscn

const PROPS: Array = [
	["01_book", Tones.ImpactMaterial.PAPER, 0.66],
	["02_small_box", Tones.ImpactMaterial.PAPER, 2.0],
	["03_ball", Tones.ImpactMaterial.RUBBER, 0.3],
	["04_bin", Tones.ImpactMaterial.PLASTIC, 2.5],
	["05_cushion", Tones.ImpactMaterial.SOFT, 0.4],
	["06_crate", Tones.ImpactMaterial.WOOD, 7.0],
	["07_table", Tones.ImpactMaterial.WOOD, 6.0],
	["08_bookcase", Tones.ImpactMaterial.WOOD, 9.0],
	["09_sofa", Tones.ImpactMaterial.SOFT, 60.0],
	["10_wardrobe", Tones.ImpactMaterial.WOOD, 115.0],
]


## Two versions to compare: how sharply the resonances ring (Tones.resonance).
const SETS: Array = [["A_dry", 0.5], ["B_woody", 1.0]]


func _ready() -> void:
	for set: Array in SETS:
		Tones.resonance = set[1]
		var folder: String = "user://knocks/%s" % set[0]
		DirAccess.make_dir_recursive_absolute(folder)
		for entry: Array in PROPS:
			_render(entry, folder)
	Tones.slurp().save_to_wav("user://knocks/catch_slurp.wav")
	# The beam's loops, a few seconds each: the whirr at rest, the whirr as it
	# sounds mid-swing (higher), and the strain crackle.
	_save_loop(Tones.whirr(), 3, 1.0, "beam_whirr")
	_save_loop(Tones.whirr(), 3, 1.5, "beam_whirr_swinging")
	_save_loop(Tones.strain_crackle(), 2, 1.0, "beam_strain")
	print("Saved to %s" % ProjectSettings.globalize_path("user://knocks"))
	get_tree().quit()


func _render(entry: Array, folder: String) -> void:
	var pitch: float = clampf(pow(ImpactAudio.REFERENCE_MASS[entry[1]] / entry[2], 0.2), 0.5, 1.6)
	var data := PackedByteArray()
	for variant in Tones.KNOCK_VARIANTS:
		data.append_array(Tones.knock(entry[1], variant).data)
		# 0.35 s of silence between takes.
		var gap := PackedByteArray()
		gap.resize(int(0.35 * Tones.MIX_RATE) * 2)
		data.append_array(gap)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	# Playing the same samples at a different rate is the pitch change.
	wav.mix_rate = int(Tones.MIX_RATE * pitch)
	wav.data = data
	wav.save_to_wav("%s/%s.wav" % [folder, entry[0]])


## Saves `repeats` copies of a loop end to end, played at `pitch`.
func _save_loop(loop: AudioStreamWAV, repeats: int, pitch: float, name: String) -> void:
	var data := PackedByteArray()
	for i in repeats:
		data.append_array(loop.data)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = int(Tones.MIX_RATE * pitch)
	wav.data = data
	wav.save_to_wav("user://knocks/%s.wav" % name)
