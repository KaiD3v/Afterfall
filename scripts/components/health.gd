# Vida de qualquer coisa que leva dano: criatura, barricada, porta. Health.of(corpo) acha o
# componente num corpo atingido (raycast, golpe) sem depender de duck typing.
class_name Health
extends Node

signal damaged(amount: float, source: Node)
signal died

@export var maximum := 100.0

var current := 0.0


func _ready() -> void:
	current = maximum


static func of(body: Object) -> Health:
	return body.get_node_or_null(^"Health") as Health if body is Node else null


# source: quem causou o dano (null = ambiente ou teste).
func damage(amount: float, source: Node = null) -> void:
	if is_dead():
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, source)
	if is_dead():
		died.emit()


func heal(amount: float) -> void:
	current = minf(current + amount, maximum)


func is_dead() -> bool:
	return current <= 0.0


func is_full() -> bool:
	return current >= maximum
