# Autoload RunState: inventário, loot sorteado por container e mortes. new_run() zera tudo (M6).
extends Node

signal message(text: String)

const SLOTS := 8
const AMMO_PER_BOX := 6  # munição vai direto para a reserva da pistola, sem ocupar slot
const NAMES := {&"bandage": "Bandagem", &"ammo_9mm": "Munição 9 mm"}

var items: Array[StringName] = []  # um item por slot, sem peso
var deaths := 0
var _loot := {}  # id do container -> itens que ainda estão nele


func new_run() -> void:
	items.clear()
	_loot.clear()


# Sorteia o container na primeira abertura da run; depois devolve o que sobrou nele.
func loot_of(container_id: StringName, table: LootTable) -> Array:
	if not _loot.has(container_id):
		_loot[container_id] = table.roll()
	return _loot[container_id]


func add_item(id: StringName) -> bool:
	if items.size() >= SLOTS:
		return false
	items.append(id)
	return true


func take_item(id: StringName) -> bool:
	var i := items.find(id)
	if i < 0:
		return false
	items.remove_at(i)
	return true


func notify(text: String) -> void:
	message.emit(text)
