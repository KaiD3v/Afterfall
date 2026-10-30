# Move ou troca itens entre dois recipientes (Inventory, Equipment, depois baús e carros), cada um
# com get_at, can_put e put. A troca só acontece se cada item couber onde vai parar.
class_name ItemTransfer


static func can_swap(from: Object, from_key: int, to: Object, to_key: int) -> bool:
	if from == to and from_key == to_key:
		return false
	var moving: ItemData = from.get_at(from_key)
	var other: ItemData = to.get_at(to_key)
	return moving != null and to.can_put(to_key, moving) and from.can_put(from_key, other)


static func swap(from: Object, from_key: int, to: Object, to_key: int) -> bool:
	if not can_swap(from, from_key, to, to_key):
		return false
	var moving: ItemData = from.get_at(from_key)
	var other: ItemData = to.get_at(to_key)
	to.put(to_key, moving)
	from.put(from_key, other)
	return true
