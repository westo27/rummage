extends Node
## Renders the itch page theme images:
## - banner.png: the logo alone on a transparent background, at most 900 wide
##   (itch shows the banner at its own size, up to the 960 px page column).
## - background.png: the bedroom at night from the title's low camera, blurred
##   soft and darkened, to sit fixed behind the page.
## Needs a real window (no --headless).
## Run: Godot --path . --resolution 1920x1080 res://tests/shoot_banner.tscn

const PressLogo = preload("res://tests/press_logo.gd")
const OUT: String = "user://shots"
const BANNER_WIDTH: int = 900
## The logo's size as the cover draws it at 1260x1000; at 1920x1080 it comes
## out bigger than the banner, then is scaled down, for clean edges.
const LOGO_SIZE: int = 420
const BACKGROUND_SIZE := Vector2i(1920, 1080)
## The blur: shrink by this much, then scale back up.
const BLUR_SHRINK: int = 10
## How much the background is darkened toward the night plum.
const DARKEN: float = 0.45
const NIGHT := Color(0.04, 0.02, 0.09)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await _banner()
	await _background()
	print("RESULT banner and background in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


## Drawn on the window itself with its background cleared to transparent, so
## the logo matches the cover exactly and the PNG keeps its alpha.
func _banner() -> void:
	get_viewport().transparent_bg = true
	var layer := CanvasLayer.new()
	add_child(layer)
	PressLogo.build(layer, LOGO_SIZE, 40)
	await _frames(10)
	var image: Image = get_viewport().get_texture().get_image()
	# Trim the empty margin, then scale to the banner width.
	image = image.get_region(image.get_used_rect().grow(8))
	var h: int = roundi(image.get_height() * float(BANNER_WIDTH) / image.get_width())
	image.resize(BANNER_WIDTH, h, Image.INTERPOLATE_LANCZOS)
	image.save_png("%s/banner.png" % OUT)
	layer.queue_free()
	get_viewport().transparent_bg = false


func _background() -> void:
	var backdrop := TitleBackdrop.new()
	add_child(backdrop)
	backdrop._time = 0.0  # the drift's middle: the bed straight ahead
	await _frames(60)
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(BACKGROUND_SIZE.x, BACKGROUND_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.resize(BACKGROUND_SIZE.x / BLUR_SHRINK, BACKGROUND_SIZE.y / BLUR_SHRINK, Image.INTERPOLATE_LANCZOS)
	image.resize(BACKGROUND_SIZE.x, BACKGROUND_SIZE.y, Image.INTERPOLATE_CUBIC)
	image.convert(Image.FORMAT_RGB8)
	# Darker toward the edges, so the page column in the middle stands out less
	# than the room around it, and the corners fade into the plain night colour.
	var centre := Vector2(BACKGROUND_SIZE) * 0.5
	for y in BACKGROUND_SIZE.y:
		for x in BACKGROUND_SIZE.x:
			var d: float = ((Vector2(x, y) - centre) / centre).length()
			var amount: float = DARKEN + (1.0 - DARKEN) * smoothstep(0.7, 1.45, d) * 0.8
			image.set_pixel(x, y, image.get_pixel(x, y).lerp(NIGHT, amount))
	image.save_png("%s/background.png" % OUT)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
