# HUD mínimo: vida, stamina, munição (pente | reserva), inventário, mensagens e aviso de morte.
extends CanvasLayer

const BAR_W := 60.0
const TOAST_TIME := 2.5

@export var player: Node

var _toast_left := 0.0

@onready var health_fill: ColorRect = $Health/Fill
@onready var stamina_fill: ColorRect = $Stamina/Fill
@onready var death: Label = $Death
@onready var ammo: Label = $Ammo
@onready var inventory: Label = $Inventory
@onready var toast: Label = $Toast


func _ready() -> void:
	player.died.connect(death.show)
	RunState.message.connect(_show_toast)


func _process(delta: float) -> void:
	health_fill.size.x = roundf(BAR_W * player.health / player.max_health)
	stamina_fill.size.x = roundf(BAR_W * player.stamina / player.max_stamina)
	# sem fôlego: barra escurece até recuperar
	stamina_fill.color = Color8(107, 58, 31) if player.exhausted else Color8(232, 197, 71)
	ammo.text = "RECARREGANDO" if player.reloading else "%d | %d" % [player.ammo, player.reserve]
	inventory.text = "Inventário: %s (%d livres)" % [_items_text(), RunState.SLOTS - RunState.items.size()]
	_toast_left -= delta
	toast.visible = _toast_left > 0.0


func _show_toast(text: String) -> void:
	toast.text = text
	_toast_left = TOAST_TIME


func _items_text() -> String:
	if RunState.items.is_empty():
		return "vazio"
	var counts := {}
	for id in RunState.items:
		counts[id] = counts.get(id, 0) + 1
	var parts: Array[String] = []
	for id in counts:
		parts.append("%s ×%d" % [RunState.NAMES[id], counts[id]])
	return ", ".join(parts)
