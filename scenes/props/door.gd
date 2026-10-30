# Porta: interagir (E) leva ao local de target, ou sai do local atual se target estiver vazio.
# A troca de local fica em main.gd; ao sair, o jogador volta em exit_marker, na frente da porta.
class_name Door
extends Interactable

@export_file("*.tscn") var target := ""
@export var exit_marker: Marker2D  # onde o jogador reaparece ao sair do target


func _ready() -> void:
	super()
	prompt_text = "%s · %s" % [Keys.label(&"interact"), "Entrar" if target != "" else "Sair"]


func interact(by: Node) -> void:
	super(by)
	if target != "":
		get_tree().call_group(Groups.MAIN, "enter", target, exit_marker.global_position)
	else:
		get_tree().call_group(Groups.MAIN, "leave")
