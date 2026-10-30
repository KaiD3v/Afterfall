# Memória dos móveis numa run: cada um sorteia na primeira abertura e vira um Inventory, que guarda
# o que sobrou e o que o jogador deixar lá (o móvel também serve de esconderijo).
class_name LootMemory
extends RefCounted

const CAPACITY := 6  # blocos de cada móvel (2 fileiras de 3 no menu)

var _loot := {}  # id do móvel -> Inventory


func of(container_id: StringName, table: LootTable) -> Inventory:
	if not _loot.has(container_id):
		var inv := Inventory.new()
		inv.capacity = CAPACITY
		for item in table.roll():
			inv.add(item)
		_loot[container_id] = inv
	return _loot[container_id]


func has_rolled(container_id: StringName) -> bool:
	return _loot.has(container_id)


# Já aberto nesta run e sem nada dentro.
func is_looted(container_id: StringName) -> bool:
	return _loot.has(container_id) and _loot[container_id].is_empty()


func clear() -> void:
	_loot.clear()
