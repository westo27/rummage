extends Prop
## The rug. Light enough to lift from the start, and what's under it (the
## trapdoor) is the point.
##
## It's on a layer of its own that only meets the floor. Things standing on
## it really stand on the floor, so moving the rug doesn't fling the table and
## balls about: it slides out from under them. The trade-off is that a lifted
## rug passes through furniture rather than knocking it.


func _ready() -> void:
	super()
	collision_layer = LAYER_RUG
	collision_mask = LAYER_WORLD
