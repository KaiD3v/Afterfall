# Fôlego: gasto por ação ou contínuo, esgotamento e recuperação depois de um tempo sem gastar.
class_name Stamina
extends Node

signal changed  # current ou exhausted mudaram

@export var maximum := 100.0
@export var regen := 15.0       # por segundo, sem gastar
@export var regen_delay := 0.8  # segundos sem gastar antes de recuperar
@export var recover_at := 25.0  # esgotado: só volta a aceitar gasto acima disso

var current := 0.0:
	set(value):
		if current != value:
			current = value
			changed.emit()
var exhausted := false:
	set(value):
		if exhausted != value:
			exhausted = value
			changed.emit()
var _regen_wait := 0.0


func _ready() -> void:
	current = maximum


# Custo fixo de uma ação. false = sem fôlego, a ação não acontece.
func spend(cost: float) -> bool:
	if exhausted or current < cost:
		return false
	drain(cost)
	return true


# Gasto contínuo (correr): pode esgotar.
func drain(amount: float) -> void:
	current = maxf(current - amount, 0.0)
	_regen_wait = regen_delay
	if current == 0.0:
		exhausted = true


# Chamado nos frames sem gasto contínuo.
func recover(delta: float) -> void:
	_regen_wait -= delta
	if _regen_wait <= 0.0:
		current = minf(current + regen * delta, maximum)
	if exhausted and current >= recover_at:
		exhausted = false
