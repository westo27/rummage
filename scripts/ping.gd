class_name Ping
extends Node
## Q: every hidden creature within ping_radius squeaks and glows, nearest first.
## Then a cooldown before the next ping.

## Seconds until the next ping is allowed (0 = ready). The HUD shows it.
signal cooldown_changed(seconds_left: float)
## Each time Q sends a ping out (the landing lesson listens).
signal pinged

var _cooldown_left: float = 0.0
var _sound := AudioStreamPlayer.new()


func _ready() -> void:
	_sound.stream = Tones.chirp(700.0, 700.0, 0.25)
	_sound.volume_db = -8.0
	add_child(_sound)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ping") and _cooldown_left <= 0.0:
		_ping()


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
		cooldown_changed.emit(_cooldown_left)


## True once the cooldown has run out.
func is_ready() -> bool:
	return _cooldown_left <= 0.0


func _ping() -> void:
	_cooldown_left = Game.tune.ping_cooldown
	cooldown_changed.emit(_cooldown_left)
	_sound.play()
	pinged.emit()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for node in get_tree().get_nodes_in_group("creatures"):
		var creature := node as Creature
		if creature.state != Creature.State.HIDDEN:
			continue
		var distance: float = creature.global_position.distance_to(player.global_position)
		if distance > Game.tune.ping_radius:
			continue
		# create_timer is a one-shot countdown; when it runs out its `timeout`
		# signal calls the creature back. If the creature is freed first (caught),
		# Godot drops the connection, so there's nothing to clean up.
		var delay: float = distance * Game.tune.ping_delay_per_metre
		get_tree().create_timer(delay, false, true).timeout.connect(creature.answer_ping)
