# Um tipo de item. Item novo = um .tres; efeito de uso novo = subclasse com use().
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name := ""


# Ao pegar do container: true = ocupa um slot do inventário; false = efeito na hora (munição).
func on_pickup(_user: Node) -> bool:
	return true


# Uso pelo inventário (tecla Q, por enquanto só a bandagem). true = gastou o item.
func use(_user: Node) -> bool:
	return false
