# Números e visual de um tipo de zumbi. Variante nova = um .tres deste tipo; comportamento novo =
# cena herdada de zombie.tscn com um script que estende o zumbi e troca só o estado que muda.
class_name ZombieData
extends Resource

@export var display_name := "Zumbi"
@export var max_health := 60.0
@export var walk_speed := 35.0        # investigando um ruído
@export var chase_speed := 60.0       # perseguindo; o jogador anda a 80
@export var sight_range := 140.0
@export var sight_half_angle := 45.0  # graus; cone de 90° à frente
@export var feel_range := 24.0        # percebe quem encosta, mesmo de costas
@export var hearing := 1.0            # multiplica o raio dos ruídos (2 = ouve o dobro de longe)
@export var attack_range := 20.0      # começa o ataque a esta distância
@export var attack: MeleeData         # dano, alcance e espera do ataque
@export var frames: SpriteFrames      # vazio = o da cena
@export var groan: AudioStream        # vazio = o da cena
