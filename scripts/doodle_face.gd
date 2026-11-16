class_name DoodleFace
extends RefCounted
## The face a child drew on a marble in felt-tip: which eyes, which mouth,
## and how lopsided. Picked once per creature and shared with the ball that
## drops into the HUD bag, so the caught marble wears the same face.
## The creature's shader (creature_marble.gdshader) draws it in 3D; draw()
## here is the bag's small 2D version.

enum Eyes { DOTS, RINGS, LASHES }
enum Mouth { SMILE, GRIN, WONKY }

const INK := Color(0.03, 0.02, 0.09)
const CHEEK := Color(1.0, 0.42, 0.55, 0.6)

var eyes: Eyes = Eyes.DOTS
var mouth: Mouth = Mouth.SMILE
## -1..1: one eye a touch bigger and higher than the other.
var lop: float = 0.0


static func random() -> DoodleFace:
	var face := DoodleFace.new()
	face.eyes = randi() % Eyes.size() as Eyes
	face.mouth = randi() % Mouth.size() as Mouth
	face.lop = randf_range(-1.0, 1.0)
	return face


func apply(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("face_eyes", eyes)
	mat.set_shader_parameter("face_mouth", mouth)
	mat.set_shader_parameter("face_lop", lop)


## Draws the face on `canvas` for a ball of `radius`, centred on its origin,
## facing the viewer (y down). Positions match the shader's head-on face.
func draw(canvas: CanvasItem, radius: float) -> void:
	var w: float = maxf(radius * 0.085, 1.0)
	var tilt: float = lop * 0.125
	for side: float in [-1.0, 1.0]:
		var at := Vector2(0.36 * side, -0.09 + tilt * 0.14 * side) * radius
		var r: float = radius * 0.16 * (1.0 - tilt * side)
		canvas.draw_circle(Vector2(0.6 * side, 0.17) * radius, radius * 0.12, CHEEK)
		match eyes:
			Eyes.DOTS:
				canvas.draw_circle(at, r * 0.65, INK)
			_:
				canvas.draw_arc(at, r, 0.0, TAU, 16, INK, w, true)
				canvas.draw_circle(at + Vector2(0.0, r * 0.1), r * 0.5, INK)
				if eyes == Eyes.LASHES:
					for i in 3:
						var a: float = -PI * 0.5 + (float(i) - 1.0) * 0.42 - 0.3 * side
						var dir := Vector2(cos(a), sin(a))
						canvas.draw_line(at + dir * r, at + dir * r * 1.55, INK, w * 0.8, true)
	var m := Vector2(0.0, 0.25) * radius
	var mr: float = radius * 0.15
	match mouth:
		Mouth.GRIN:
			canvas.draw_line(m - Vector2(mr * 1.15, 0.0), m + Vector2(mr * 1.15, 0.0), INK, w, true)
			canvas.draw_arc(m, mr * 1.15, 0.0, PI, 12, INK, w, true)
		Mouth.WONKY:
			canvas.draw_arc(m - Vector2(0.0, mr * 1.6), mr * 2.0, PI * 0.37, PI * 0.63, 10, INK, w, true)
		_:
			canvas.draw_arc(m - Vector2(0.0, mr * 0.6), mr, PI * 0.18, PI * 0.82, 10, INK, w, true)
