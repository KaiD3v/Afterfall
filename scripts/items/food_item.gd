# Comida ou bebida: repõe fome e/ou sede de quem usa; com as duas já cheias, não gasta.
class_name FoodItem
extends ItemData

@export var hunger := 0.0
@export var thirst := 0.0


func type_name() -> String:
	return "Consumível"


func stats() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if hunger > 0.0:
		out.append(stat("Fome", hunger, "+" + num(hunger)))
	if thirst > 0.0:
		out.append(stat("Sede", thirst, "+" + num(thirst)))
	return out


func use(user: Node) -> bool:
	var needs := Needs.of(user)
	if needs == null or Health.of(user).is_dead() or not wants(needs):
		return false
	needs.eat(hunger)
	needs.drink(thirst)
	return true


# Repõe algo que não está cheio. "Cheio" tem folga de 1 ponto: a queda é contínua, e logo depois de
# encher o valor já é 99,99, o que gastaria o item quase todo à toa.
func wants(needs: Needs) -> bool:
	var full := needs.maximum - 1.0
	return (hunger > 0.0 and needs.hunger < full) or (thirst > 0.0 and needs.thirst < full)
