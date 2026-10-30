# Caixa de munição: vai direto para a reserva da arma de fogo de quem pega, sem ocupar slot.
# ponytail: uma arma de fogo só (user.firearm); com mais calibres, casar por tipo de munição.
class_name AmmoItem
extends ItemData

@export var amount := 6


func on_pickup(user: Node) -> bool:
	user.firearm.reserve += amount
	return false
