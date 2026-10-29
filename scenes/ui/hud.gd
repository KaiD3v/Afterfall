# HUD mínimo: barras de vida e stamina e aviso de morte.
extends CanvasLayer

const BAR_W := 60.0

@export var player: Node

@onready var health_fill: ColorRect = $Health/Fill
@onready var stamina_fill: ColorRect = $Stamina/Fill
@onready var death: Label = $Death


func _ready() -> void:
	player.died.connect(death.show)


func _process(_delta: float) -> void:
	health_fill.size.x = roundf(BAR_W * player.health / player.max_health)
	stamina_fill.size.x = roundf(BAR_W * player.stamina / player.max_stamina)
	# sem fôlego: barra escurece até recuperar
	stamina_fill.color = Color8(107, 58, 31) if player.exhausted else Color8(232, 197, 71)
