# Inventário em slots, um item por slot, sem peso. Serve ao jogador e, depois, a baús e carros.
class_name Inventory
extends RefCounted

signal changed

var slots := 8
var items: Array[ItemData] = []


func add(item: ItemData) -> bool:
	if is_full():
		return false
	items.append(item)
	changed.emit()
	return true


# Tira um item com esse id; false se não houver.
func take(id: StringName) -> bool:
	for i in items.size():
		if items[i].id == id:
			items.remove_at(i)
			changed.emit()
			return true
	return false


# Usa um item que esteja no inventário; gasta só se o efeito aconteceu.
func use(item: ItemData, user: Node) -> bool:
	return count(item.id) > 0 and item.use(user) and take(item.id)


func count(id: StringName) -> int:
	return items.filter(func(it: ItemData): return it.id == id).size()


func size() -> int:
	return items.size()


func is_empty() -> bool:
	return items.is_empty()


func is_full() -> bool:
	return items.size() >= slots


func free_slots() -> int:
	return slots - items.size()


func clear() -> void:
	items.clear()
	changed.emit()
