# Arma de fogo: raycast do cano, dispersão, pente e recarga.
class_name FirearmData
extends WeaponData

@export var max_range := 320.0
@export var spread := 4.0       # graus para cada lado; o erro lateral cresce com a distância
@export var move_spread := 9.0  # graus para cada lado andando enquanto mira
@export var mag_size := 12
@export var reload_time := 1.5
@export var reload_sound: AudioStream
