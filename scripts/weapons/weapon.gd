# Arma na mão de um Actor (nó filho dele): espera entre usos, som e ruído. Os números ficam em data.
class_name Weapon
extends Node2D

@export var data: WeaponData

var _wait := 0.0
var _sound: AudioStreamPlayer2D

@onready var user: Actor = get_parent()


func _ready() -> void:
	process_physics_priority = -1  # a espera desconta antes do dono tentar usar, como antes
	_sound = _audio(data.sound)


func _physics_process(delta: float) -> void:
	_wait -= delta


func is_waiting() -> bool:
	return _wait > 0.0


# Começa a espera, toca o som e faz o ruído do uso.
func _used() -> void:
	_wait = data.cooldown
	if _sound:
		_sound.play()
	if data.noise > 0.0:
		Noises.emit(user, data.noise)


func _audio(stream: AudioStream) -> AudioStreamPlayer2D:
	if stream == null:
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = &"SFX"
	add_child(p)
	return p
