# Item que cura quem usa; com a vida cheia não gasta.
class_name HealItem
extends ItemData

@export var heal := 30.0


func type_name() -> String:
	return "Consumível"


func stats() -> Array[Dictionary]:
	return [stat("Cura", heal, "+" + num(heal))]


func use(user: Node) -> bool:
	var health := Health.of(user)
	if health == null or health.is_dead() or health.is_full():
		return false
	health.heal(heal)
	return true
