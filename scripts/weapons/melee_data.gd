# Golpe de perto: acerta no frame de contato quem estiver no alcance e no arco à frente.
class_name MeleeData
extends WeaponData

@export var reach := 30.0        # px até o alvo, conferido no frame de contato
@export var half_angle := 180.0  # graus para cada lado da frente; 180 = em volta toda
@export var target_group := &"zombies"
