# Números de uma arma, comuns a todo tipo. Uma arma nova é um .tres de MeleeData ou FirearmData.
class_name WeaponData
extends Resource

@export var display_name := ""
@export var damage := 10.0
@export var cooldown := 0.5      # segundos entre usos
@export var stamina_cost := 0.0  # por uso; só para quem tem nó Stamina
@export var noise := 0.0         # raio do ruído que os zumbis ouvem (0 = silenciosa)
@export var anim := ""           # ação estado_direção tocada no uso (melee, shoot, attack)
@export var sound: AudioStream
