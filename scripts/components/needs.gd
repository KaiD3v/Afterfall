# Fome e sede: caem com o tempo de jogo (param com o jogo pausado e com o dono morto) e, zeradas,
# tiram vida devagar até matar. Comida e água repõem (FoodItem). Valores de partida, a medir em teste.
class_name Needs
extends Node

signal changed  # hunger ou thirst mudaram

@export var maximum := 100.0
@export var hunger_hours := 16.0  # horas de jogo de cheia a zero, sem comer
@export var thirst_hours := 10.0  # idem, sem beber
@export var starving_hours := 2.0  # horas de jogo para uma necessidade zerada tirar 100 de vida

var hunger := 0.0:
	set(value):
		if hunger != value:
			hunger = value
			changed.emit()
var thirst := 0.0:
	set(value):
		if thirst != value:
			thirst = value
			changed.emit()
var death_cause := ""  # a necessidade zerada que deu o último dano: a tela de resultado mostra

@onready var _health: Health = Health.of(get_parent())


func _ready() -> void:
	hunger = maximum
	thirst = maximum


static func of(body: Object) -> Needs:
	return body.get_node_or_null(^"Needs") as Needs if body is Node else null


func _process(delta: float) -> void:
	if _health.is_dead():
		return
	var hour := RunStats.DAY_SECONDS / 24.0  # segundos reais por hora de jogo
	hunger = maxf(hunger - maximum / (hunger_hours * hour) * delta, 0.0)
	thirst = maxf(thirst - maximum / (thirst_hours * hour) * delta, 0.0)
	var empty := [hunger == 0.0, thirst == 0.0].count(true)
	if empty:
		death_cause = "fome e sede" if empty == 2 else ("fome" if hunger == 0.0 else "sede")
		_health.damage(empty * 100.0 / (starving_hours * hour) * delta, self)


func eat(amount: float) -> void:
	hunger = minf(hunger + amount, maximum)


func drink(amount: float) -> void:
	thirst = minf(thirst + amount, maximum)
