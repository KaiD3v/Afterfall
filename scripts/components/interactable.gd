# Algo que o jogador usa com E: porta, container, depois veículo ou bancada. Fica na posição do
# dono; o jogador foca o mais próximo ao alcance e a HUD mostra prompt_text.
class_name Interactable
extends Node2D

signal interacted(by: Node)

@export var prompt_text := ""
@export var focus_visual: CanvasItem  # contorno mostrado em foco; vazio = só o aviso


func _ready() -> void:
	add_to_group(Groups.INTERACTABLES)


func set_focus(on: bool) -> void:
	if focus_visual:
		focus_visual.visible = on


func interact(by: Node) -> void:
	interacted.emit(by)
