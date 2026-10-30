# Autoload RunState: o estado da run em partes (mochila, equipamento, memória dos containers, números)
# e as mensagens para a HUD. new_run() zera tudo menos as mortes, que contam entre runs.
extends Node

signal message(text: String)

# Equipado no começo de cada run.
const STARTING_GEAR: Array[EquipmentItem] = [preload("res://data/items/machete.tres"), preload("res://data/items/pistol_9mm.tres")]

var inventory := Inventory.new()  # a mochila: 9 blocos, um item por bloco, sem peso
var equipment := Equipment.new()
var loot := LootMemory.new()
var stats := RunStats.new()
var deaths := 0


func _init() -> void:
	_equip_starting_gear()


func new_run() -> void:
	inventory.clear()
	_equip_starting_gear()
	loot.clear()
	stats = RunStats.new()


func _equip_starting_gear() -> void:
	equipment.clear()
	for item in STARTING_GEAR:
		equipment.put(item.slot, item)


func notify(text: String) -> void:
	message.emit(text)
