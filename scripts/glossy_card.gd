class_name GlossyCard
extends PanelContainer
## A container drawn as one big glossy panel, the same finish as the buttons,
## with its children laid out inside it.
##
## PanelContainer normally draws a StyleBox behind its children; here the
## StyleBox is empty (it only supplies the inner margins) and the card itself
## is drawn in _draw. A parent's _draw runs before its children are drawn, so
## the card always sits behind whatever is in it.

@export var accent: Color = UiStyle.AMBER
## Corner radius in design pixels.
@export var radius: float = 70.0
## Space between the card's edge and its contents.
@export var padding: Vector2 = Vector2(90.0, 70.0)


func _ready() -> void:
	var margins := StyleBoxEmpty.new()
	margins.content_margin_left = padding.x
	margins.content_margin_right = padding.x
	margins.content_margin_top = padding.y
	margins.content_margin_bottom = padding.y
	add_theme_stylebox_override("panel", margins)


func _draw() -> void:
	UiStyle.draw_glossy_panel(self, Rect2(Vector2.ZERO, size), radius, accent, 0.0, 0.0)
