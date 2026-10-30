# Autoload RunState: inventário, loot sorteado por container e números da run.
# new_run() zera tudo menos as mortes, que contam entre runs.
extends Node

signal message(text: String)

var inventory := Inventory.new()  # 8 slots, um item por slot, sem peso
var deaths := 0
var run_time := 0.0  # segundos vivo nesta run
var kills := 0
var looted := 0      # itens tirados de containers, munição incluída
var _loot := {}  # id do container -> itens que ainda estão nele


func new_run() -> void:
	inventory.clear()
	_loot.clear()
	run_time = 0.0
	kills = 0
	looted = 0


# Sorteia o container na primeira abertura da run; depois devolve o que sobrou nele.
func loot_of(container_id: StringName, table: LootTable) -> Array:
	if not _loot.has(container_id):
		_loot[container_id] = table.roll()
	return _loot[container_id]


func has_rolled(container_id: StringName) -> bool:
	return _loot.has(container_id)


func is_looted(container_id: StringName) -> bool:
	return _loot.has(container_id) and _loot[container_id].is_empty()


func notify(text: String) -> void:
	message.emit(text)
