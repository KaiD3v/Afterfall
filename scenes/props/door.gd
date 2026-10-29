# Porta da casa: interagir (E) entra ou sai. A troca de cena fica em main.gd.
extends Node2D

@export_enum("enter_house", "exit_house") var action := "enter_house"


func _ready() -> void:
	add_to_group("interactables")


func set_focus(_on: bool) -> void:
	pass  # a porta faz parte da arte da casa: só o aviso de E aparece


func prompt() -> String:
	return "E · Entrar" if action == "enter_house" else "E · Sair"


func interact(_player: Node) -> void:
	get_tree().call_group("main", action)
