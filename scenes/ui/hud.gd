# HUD mínimo: vida, stamina, munição (pente | reserva), inventário, mensagens e tela de resultado.
# Tudo por sinais dos componentes do jogador e do RunState; nada é lido a cada frame.
extends CanvasLayer

const BAR_W := 60.0
const TOAST_TIME := 2.5

@export var player: Player

var _focus: Interactable
var _toast_timer: Tween

@onready var health_fill: ColorRect = $Health/Fill
@onready var stamina_fill: ColorRect = $Stamina/Fill
@onready var result: ColorRect = $Result
@onready var ammo: Label = $Ammo
@onready var inventory: Label = $Inventory
@onready var toast: Label = $Toast
@onready var prompt: Label = $Prompt


func _ready() -> void:
	$Crosshair.player = player
	RunState.message.connect(_show_toast)
	RunState.inventory.changed.connect(_on_inventory)
	player.health.changed.connect(_on_health)
	player.stamina.changed.connect(_on_stamina)
	player.firearm.changed.connect(_on_ammo)
	player.focus_changed.connect(_on_focus)
	player.died.connect(_update_prompt)
	toast.hide()
	_on_health()
	_on_stamina()
	_on_ammo()
	_on_inventory()
	_on_focus(player.focus)


# Chamado por main.gd quando o jogador morre.
func show_result() -> void:
	var t := int(RunState.stats.time)
	result.get_node("Text").text = "VOCÊ MORREU\n\nSobreviveu %d:%02d · %d zumbis · %d itens\nMortes: %d\n\nE para uma nova run" % [
		t / 60, t % 60, RunState.stats.kills, RunState.stats.looted, RunState.deaths]
	result.show()


func _on_health() -> void:
	health_fill.size.x = roundf(BAR_W * player.health.current / player.health.maximum)


func _on_stamina() -> void:
	stamina_fill.size.x = roundf(BAR_W * player.stamina.current / player.stamina.maximum)
	# sem fôlego: barra escurece até recuperar (paleta Scavland: ferrugem escura vs verde-oliva tático)
	stamina_fill.color = Color8(66, 40, 29) if player.stamina.exhausted else Color8(99, 117, 80)


func _on_ammo() -> void:
	var gun := player.firearm
	if not gun.is_equipped():
		ammo.text = "SEM ARMA"
	else:
		ammo.text = "RECARREGANDO" if gun.reloading else "%d | %d" % [gun.ammo, gun.reserve]


func _on_inventory() -> void:
	inventory.text = "Inventário: %s (%d livres)" % [_items_text(), RunState.inventory.free_slots()]


# Troca de foco: passa a ouvir o aviso do novo interativo (o do container muda ao esvaziar).
func _on_focus(target: Interactable) -> void:
	if is_instance_valid(_focus):
		_focus.prompt_changed.disconnect(_update_prompt)
		_focus.tree_exited.disconnect(_update_prompt)
	_focus = target
	if _focus:
		_focus.prompt_changed.connect(_update_prompt)
		_focus.tree_exited.connect(_update_prompt)  # sai junto com o local na troca
	_update_prompt()


func _update_prompt() -> void:
	prompt.visible = is_instance_valid(_focus) and _focus.is_inside_tree() and not player.is_dead()
	if prompt.visible:
		prompt.text = _focus.prompt_text


func _show_toast(text: String) -> void:
	toast.text = text
	toast.show()
	if _toast_timer:
		_toast_timer.kill()
	_toast_timer = create_tween()
	_toast_timer.tween_callback(toast.hide).set_delay(TOAST_TIME)


func _items_text() -> String:
	if RunState.inventory.is_empty():
		return "vazio"
	var counts := {}  # nome -> quantidade, na ordem em que entraram
	for item in RunState.inventory.items:
		counts[item.display_name] = counts.get(item.display_name, 0) + 1
	var parts: Array[String] = []
	for item_name in counts:
		parts.append("%s ×%d" % [item_name, counts[item_name]])
	return ", ".join(parts)
