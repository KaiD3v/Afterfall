# Fome, sede e cansaço. Fome e sede caem com o tempo de jogo (param com o jogo pausado e com o dono
# morto) e, zeradas, tiram vida devagar até matar; comida e água repõem (FoodItem). O cansaço vem das
# horas acordado: depois de tired_hours, o teto do fôlego (Stamina.cap) cai até a metade em
# exhausted_hours. Dormir (só na cama da casa) passa SLEEP_HOURS: fome e sede caem na taxa normal e
# o cansaço zera. Frio: à noite (NIGHT_START a NIGHT_END) e fora de abrigo, cold sobe 1 por hora de
# jogo; abrigado ou de dia, desce no mesmo ritmo. Com cold_hurts horas seguidas, tira vida como a
# fome zerada. Valores de partida, a medir em teste.
class_name Needs
extends Node

signal changed  # hunger ou thirst mudaram

@export var maximum := 100.0
@export var hunger_hours := 16.0  # horas de jogo de cheia a zero, sem comer
@export var thirst_hours := 10.0  # idem, sem beber
@export var starving_hours := 2.0  # horas de jogo para uma necessidade zerada tirar 100 de vida
@export var sleep_after := 12.0  # horas acordado para conseguir dormir
@export var tired_hours := 16.0  # horas acordado sem efeito; depois o fôlego máximo começa a cair
@export var exhausted_hours := 24.0  # horas acordado com o fôlego máximo na metade (e daí não passa)
@export var cold_shows := 1.0  # horas de exposição para o selo de frio aparecer
@export var cold_hurts := 3.0  # horas de exposição para o frio ferir (e o teto do acúmulo)

const SLEEP_HOURS := 8.0
const HOUR := RunStats.DAY_SECONDS / 24.0  # segundos reais por hora de jogo
const NIGHT_START := 20  # hora em que começa o frio
const NIGHT_END := 6

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
var awake := 0.0  # horas de jogo acordado (a run começa descansada)
var cold := 0.0  # horas de exposição ao frio, de 0 a cold_hurts
var sheltered := false  # dentro de casa: sem frio (main.gd põe ao trocar de local)
var death_cause := ""  # a necessidade zerada que deu o último dano: a tela de resultado mostra

@onready var _health: Health = Health.of(get_parent())
@onready var _stamina: Stamina = get_parent().get_node_or_null(^"Stamina")


func _ready() -> void:
	hunger = maximum
	thirst = maximum


static func of(body: Object) -> Needs:
	return body.get_node_or_null(^"Needs") as Needs if body is Node else null


func _process(delta: float) -> void:
	if _health.is_dead():
		return
	hunger = maxf(hunger - _drop(hunger_hours, delta / HOUR), 0.0)
	thirst = maxf(thirst - _drop(thirst_hours, delta / HOUR), 0.0)
	awake += delta / HOUR
	if _stamina:
		_stamina.cap = _stamina.maximum * stamina_factor()
	# o autoload pelo caminho: este script compila antes dos autoloads quando um teste carrega um item
	var exposed := not sheltered and is_night(get_node(^"/root/RunState").stats.minute())
	cold = clampf(cold + (delta if exposed else -delta) / HOUR, 0.0, cold_hurts)
	var causes: Array[String] = []
	for c in [["fome", hunger == 0.0], ["sede", thirst == 0.0], ["frio", cold >= cold_hurts]]:
		if c[1]:
			causes.append(c[0])
	if causes:
		death_cause = " e ".join(causes)
		_health.damage(causes.size() * 100.0 / (starving_hours * HOUR) * delta, self)


static func is_night(minute_of_day: int) -> bool:
	return minute_of_day >= NIGHT_START * 60 or minute_of_day < NIGHT_END * 60


# Quanto uma necessidade que zera em full_hours cai em hours de jogo.
func _drop(full_hours: float, hours: float) -> float:
	return maximum * hours / full_hours


# Fração do fôlego máximo que o cansaço deixa: 1 até tired_hours, 0,5 em exhausted_hours e depois.
func stamina_factor() -> float:
	return lerpf(1.0, 0.5, clampf((awake - tired_hours) / (exhausted_hours - tired_hours), 0.0, 1.0))


# Motivo para não dormir agora ("" = pode): sono de menos, ou fome/sede que zerariam durante o sono.
func why_not_sleep() -> String:
	if awake < sleep_after:
		return "Sem sono: acordado há %d h (dorme com %d h)" % [int(awake), int(sleep_after)]
	var starving := hunger - _drop(hunger_hours, SLEEP_HOURS) <= 0.0
	var parched := thirst - _drop(thirst_hours, SLEEP_HOURS) <= 0.0
	if starving or parched:
		return "%s demais: zeraria dormindo" % ("Fome e sede" if starving and parched else ("Fome" if starving else "Sede"))
	return ""


# Passa SLEEP_HOURS dormindo (na casa, abrigado): fome e sede caem na taxa normal, o cansaço zera
# e o frio passa.
# Quem chama confere why_not_sleep() e avança o relógio.
func sleep() -> void:
	hunger = maxf(hunger - _drop(hunger_hours, SLEEP_HOURS), 0.0)
	thirst = maxf(thirst - _drop(thirst_hours, SLEEP_HOURS), 0.0)
	awake = 0.0
	cold = maxf(cold - SLEEP_HOURS, 0.0)
	if _stamina:
		_stamina.cap = _stamina.maximum
		_stamina.current = _stamina.maximum


func eat(amount: float) -> void:
	hunger = minf(hunger + amount, maximum)


func drink(amount: float) -> void:
	thirst = minf(thirst + amount, maximum)
