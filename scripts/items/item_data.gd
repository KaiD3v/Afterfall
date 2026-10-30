# Um tipo de item. Item novo = um .tres; efeito de uso novo = subclasse com use().
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""  # aparece no menu do inventário
@export var icon: Texture2D  # quadro de 128×128 (escala 0,25 = um slot de 32×32)


# Ao pegar do container: true = ocupa um slot do inventário; false = efeito na hora (munição).
func on_pickup(_user: Node) -> bool:
	return true


# Uso pelo inventário (tecla Q ou botão direito no menu). true = gastou o item.
func use(_user: Node) -> bool:
	return false
