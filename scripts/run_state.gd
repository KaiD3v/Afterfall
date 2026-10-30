# Autoload RunState: o estado da run em partes (inventário, memória dos containers, números)
# e as mensagens para a HUD. new_run() zera tudo menos as mortes, que contam entre runs.
extends Node

signal message(text: String)

var inventory := Inventory.new()  # 8 slots, um item por slot, sem peso
var loot := LootMemory.new()
var stats := RunStats.new()
var deaths := 0


func new_run() -> void:
	inventory.clear()
	loot.clear()
	stats = RunStats.new()


func notify(text: String) -> void:
	message.emit(text)
