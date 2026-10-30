# HUD mínimo: vida, stamina, munição (pente | reserva), inventário, mensagens e tela de resultado.
extends CanvasLayer

const BAR_W := 60.0
const TOAST_TIME := 2.5

@export var player: Node

var _toast_left := 0.0

@onready var health_fill: ColorRect = $Health/Fill
@onready var stamina_fill: ColorRect = $Stamina/Fill
@onready var result: ColorRect = $Result
@onready var ammo: Label = $Ammo
@onready var inventory: Label = $Inventory
@onready var toast: Label = $Toast


func _ready() -> void:
	RunState.message.connect(_show_toast)
	$Crosshair.player = player


func _process(delta: float) -> void:
	health_fill.size.x = roundf(BAR_W * player.health.current / player.health.maximum)
	stamina_fill.size.x = roundf(BAR_W * player.stamina.current / player.stamina.maximum)
	# sem fôlego: barra escurece até recuperar (paleta Scavland: ferrugem escura vs verde-oliva tático)
	stamina_fill.color = Color8(66, 40, 29) if player.stamina.exhausted else Color8(99, 117, 80)
	ammo.text = "RECARREGANDO" if player.reloading else "%d | %d" % [player.ammo, player.reserve]
	inventory.text = "Inventário: %s (%d livres)" % [_items_text(), RunState.SLOTS - RunState.items.size()]
	var f = player.focus  # sem tipo: o foco pode ter sido liberado na troca bairro ↔ interior
	$Prompt.visible = is_instance_valid(f) and not player.is_dead()
	if $Prompt.visible:
		$Prompt.text = f.prompt()
	_toast_left -= delta
	toast.visible = _toast_left > 0.0


# Chamado por main.gd quando o jogador morre.
func show_result() -> void:
	var t := int(RunState.run_time)
	result.get_node("Text").text = "VOCÊ MORREU\n\nSobreviveu %d:%02d · %d zumbis · %d itens\nMortes: %d\n\nE para uma nova run" % [
		t / 60, t % 60, RunState.kills, RunState.looted, RunState.deaths]
	result.show()


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
