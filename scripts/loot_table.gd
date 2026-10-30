# Tabela de loot de um container: itens e pesos (vazio = nada). Sorteada uma vez por run, via RunState.
class_name LootTable
extends Resource

@export var items: Array[ItemData] = []
@export var weights: Array[float] = []
@export var rolls := 1


func roll() -> Array[ItemData]:
	var out: Array[ItemData] = []
	var total := 0.0
	for w in weights:
		total += w
	for i in rolls:
		var r := randf() * total
		for j in items.size():
			r -= weights[j]
			if r < 0.0:
				if items[j] != null:
					out.append(items[j])
				break
	return out
