# Equipamento: um item por slot (EquipmentItem.Slot). Mesmo contrato de recipiente do Inventory
# (get_at, can_put, put), para o menu e o ItemTransfer tratarem os dois igual.
class_name Equipment
extends RefCounted

signal changed

var _items := {}  # EquipmentItem.Slot -> EquipmentItem


func get_at(slot: int) -> ItemData:
	return _items.get(slot)


# Só aceita equipamento do próprio slot (ou esvaziar).
func can_put(slot: int, item: ItemData) -> bool:
	return item == null or (item is EquipmentItem and item.slot == slot)


func put(slot: int, item: ItemData) -> void:
	if item:
		_items[slot] = item
	else:
		_items.erase(slot)
	changed.emit()


# Arma do slot (MELEE ou FIREARM), ou null com o slot vazio.
func weapon(slot: int) -> WeaponData:
	var item := get_at(slot) as WeaponItem
	return item.weapon if item else null


func is_empty() -> bool:
	return _items.is_empty()


func clear() -> void:
	_items.clear()
	changed.emit()
