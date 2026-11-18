extends RefCounted
## The game's default look for press images and clips, whatever the saved
## settings say: the Soft screen filter at size 1. Nothing is saved.
## Scanlines are left off: scaled down or video-compressed, they turn to moiré.
## `pixel` gives the Pixel filter at its finest instead.


static func use(pixel: bool = false) -> void:
	var settings: Settings = Game.settings
	settings.pixel_filter = true
	settings.soft_filter = not pixel
	settings.pixel_strength = 1
	settings.apply_pixel_filter()
	Game.pixel_filter._material.set_shader_parameter("scanlines", 0.0)
