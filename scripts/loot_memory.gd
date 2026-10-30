# Memória dos containers numa run: cada um sorteia na primeira abertura e depois guarda o que sobrou.
class_name LootMemory
extends RefCounted

var _loot := {}  # id do container -> itens que ainda estão nele


func of(container_id: StringName, table: LootTable) -> Array:
	if not _loot.has(container_id):
		_loot[container_id] = table.roll()
	return _loot[container_id]


func has_rolled(container_id: StringName) -> bool:
	return _loot.has(container_id)


# Já aberto nesta run e sem nada dentro.
func is_looted(container_id: StringName) -> bool:
	return _loot.has(container_id) and _loot[container_id].is_empty()


func clear() -> void:
	_loot.clear()
