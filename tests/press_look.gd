extends RefCounted
## The game's default look for press images and clips, whatever the saved
## settings say: the screen filter at size 1. Nothing is saved.
## Scanlines are left off: scaled down or video-compressed, they turn to moiré.


static func use() -> void:
	var settings: Settings = Game.settings
	settings.screen_filter = true
	settings.filter_size = 1
	settings.apply_screen_filter()
	Game.screen_filter.set_scanlines(0.0)
