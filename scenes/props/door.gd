# Porta da casa: interagir (E) entra ou sai. A troca de cena fica em main.gd.
extends Node2D

@export_enum("enter_house", "exit_house") var action := "enter_house"


func _ready() -> void:
	add_to_group("interactables")


func interact(_player: Node) -> void:
	get_tree().call_group("main", action)
