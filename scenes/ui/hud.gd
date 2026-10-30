# HUD mínimo: retrato, vida, stamina, cartão da arma (pente em traços + reserva), relógio (dia e hora),
# fome e sede (Needs), mensagens e tela de resultado. A temperatura fica escondida até o sistema existir.
# Tudo por sinais dos componentes do jogador e do RunState; nada é lido a cada frame.
extends CanvasLayer

const BAR_W := 60.0
const TOAST_TIME := 2.5
const AMBER := Color8(227, 168, 69)
const DIM := Color8(95, 104, 115)
const EMPTY := Color8(36, 42, 52)  # traço de bala gasta
const LOW := 0.25  # fome ou sede abaixo disto: moodle âmbar; zerada: vermelho piscando
const BLOOD := Color8(150, 33, 39)  # fundo do moodle crítico
const BADGE_BG := Color8(30, 36, 46)  # fundo normal do moodle (o mesmo do hud_glyph)
const PALE := Color8(168, 174, 179)  # pictograma sobre o fundo crítico

@export var player: Player

var _focus: Interactable
var _toast_timer: Tween
var _reload_fill: Tween
var _moodle_level := {}  # moodle → nível mostrado (0 escondido, 1 âmbar, 2 crítico)
var _blink := {}  # moodle crítico → tween do piscar

@onready var health_fill: ColorRect = $Health/Fill
@onready var stamina_fill: ColorRect = $Stamina/Fill
@onready var hunger_fill: ColorRect = $Needs/Hunger/Fill
@onready var thirst_fill: ColorRect = $Needs/Thirst/Fill
@onready var _needs_w := Vector2(hunger_fill.size.x, thirst_fill.size.x)  # larguras cheias, do hud.tscn
@onready var result: ColorRect = $Result
@onready var mag: Control = $WeaponCard/Mag
@onready var reserve: Label = $WeaponCard/Reserve
@onready var toast: Label = $Toast
@onready var prompt: Label = $Prompt


func _ready() -> void:
	$Crosshair.player = player
	for n in [$WeaponCard]:
		n.add_to_group(Groups.HIDE_WITH_MENU)
	$PortraitFrame/Portrait.texture = _face()
	RunState.message.connect(_show_toast)
	player.health.changed.connect(_on_health)
	player.stamina.changed.connect(_on_stamina)
	player.needs.changed.connect(_on_needs)
	player.firearm.changed.connect(_on_ammo)
	player.aim_changed.connect(_on_aim)
	RunState.equipment.changed.connect(_on_weapons)
	RunState.stats.minute_changed.connect(_on_clock)
	player.focus_changed.connect(_on_focus)
	player.died.connect(_update_prompt)
	toast.hide()
	_on_health()
	_on_stamina()
	_on_needs()
	_on_weapons()
	_on_clock()
	_on_focus(player.focus)


# Chamado por main.gd quando o jogador morre.
func show_result() -> void:
	var t := int(RunState.stats.time)
	result.get_node("Text").text = "VOCÊ MORREU\n\nCausa: %s · Dias sobrevividos: %d\nSobreviveu %d:%02d · %d zumbis · %d itens\nMortes: %d\n\n%s para uma nova run" % [
		RunState.stats.cause, RunState.stats.days(), t / 60, t % 60, RunState.stats.kills, RunState.stats.looted, RunState.deaths, Keys.label(&"interact")]
	result.show()


# Dia corrente (o primeiro é o 1) e hora do relógio de jogo.
func _on_clock() -> void:
	var m := RunState.stats.minute()
	$Clock.text = "Dia %d · %02d:%02d" % [RunState.stats.days() + 1, m / 60, m % 60]


func _on_health() -> void:
	health_fill.size.x = roundf(BAR_W * player.health.current / player.health.maximum)


func _on_stamina() -> void:
	stamina_fill.size.x = roundf(BAR_W * player.stamina.current / player.stamina.maximum)
	# sem fôlego: barra escurece até recuperar (paleta Scavland: ferrugem escura vs verde-oliva tático)
	stamina_fill.color = Color8(66, 40, 29) if player.stamina.exhausted else Color8(99, 117, 80)


func _on_needs() -> void:
	hunger_fill.size.x = roundf(_needs_w.x * player.needs.hunger / player.needs.maximum)
	thirst_fill.size.x = roundf(_needs_w.y * player.needs.thirst / player.needs.maximum)
	var n := player.needs
	_moodle($Moodles/Hunger, _level(n.hunger / n.maximum))
	_moodle($Moodles/Thirst, _level(n.thirst / n.maximum))
	_moodle($Moodles/Tired, 0 if n.awake < n.tired_hours else (1 if n.awake < n.exhausted_hours else 2))


# Fome ou sede: 0 acima de LOW, 1 abaixo, 2 zerada (já tira vida).
static func _level(fraction: float) -> int:
	return 2 if fraction <= 0.0 else (1 if fraction < LOW else 0)


# Moodles na linha abaixo do painel: só os ativos aparecem (o HBox junta os visíveis à esquerda).
# Nível 1: pictograma âmbar; nível 2: fundo de sangue e pisca. Só mexe quando o nível muda.
func _moodle(badge: Control, level: int) -> void:
	if _moodle_level.get(badge, 0) == level:
		return
	_moodle_level[badge] = level
	badge.visible = level > 0
	badge.color = PALE if level == 2 else AMBER
	badge.bg = BLOOD if level == 2 else BADGE_BG
	if _blink.has(badge):
		_blink[badge].kill()
		_blink.erase(badge)
		badge.modulate.a = 1.0
	if level == 2:
		var t := create_tween().set_loops()
		t.tween_property(badge, "modulate:a", 0.35, 0.4)
		t.tween_property(badge, "modulate:a", 1.0, 0.4)
		_blink[badge] = t


# Ícones das duas armas do equipamento; slot vazio fica sem ícone.
func _on_weapons() -> void:
	for pair in [[$WeaponCard/MeleeIcon, EquipmentItem.Slot.MELEE], [$WeaponCard/FirearmIcon, EquipmentItem.Slot.FIREARM]]:
		var item := RunState.equipment.get_at(pair[1])
		pair[0].texture = item.icon if item else null
	_on_ammo()
	_on_aim()


# Sublinha a arma que o clique vai usar: mirando, a de fogo; sem mirar, a branca.
func _on_aim() -> void:
	$WeaponCard/Mark.position.x = ($WeaponCard/FirearmIcon if player.aiming else $WeaponCard/MeleeIcon).position.x


# Pente: um traço por bala, em 2 fileiras; a reserva ao lado acende em âmbar com o pente vazio.
# Na recarga, os traços enchem da esquerda para a direita no tempo da recarga.
func _on_ammo() -> void:
	var gun := player.firearm.gun()
	mag.visible = gun != null
	reserve.visible = gun != null
	if gun == null:
		return
	if mag.get_child_count() != gun.mag_size:
		_build_mag(gun.mag_size)
	reserve.text = "+%d" % player.firearm.reserve
	reserve.add_theme_color_override("font_color", AMBER if player.firearm.ammo == 0 else DIM)
	if player.firearm.reloading:
		if not (_reload_fill and _reload_fill.is_running()):
			_reload_fill = create_tween()
			_reload_fill.tween_method(_light_mag, 0, gun.mag_size, gun.reload_time)
		return
	if _reload_fill:
		_reload_fill.kill()
	_light_mag(player.firearm.ammo)


func _light_mag(count: int) -> void:
	for i in mag.get_child_count():
		mag.get_child(i).color = AMBER if i < count else EMPTY


# ponytail: 2 fileiras cabem até ~14 balas no cartão; pentes maiores pedem número em vez de traços.
func _build_mag(size: int) -> void:
	for c in mag.get_children():
		mag.remove_child(c)
		c.queue_free()
	var cols := ceili(size / 2.0)
	for i in size:
		var pip := ColorRect.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.position = Vector2((i % cols) * 3, (i / cols) * 6)
		pip.size = Vector2(2, 4)
		mag.add_child(pip)


# Retrato: rosto recortado do sprite parado, no dobro da escala do mundo (densidade dos ícones).
# Os moodles vão trocar esta textura pelas expressões geradas.
func _face() -> AtlasTexture:
	var sf: SpriteFrames = preload("res://assets/sprites/character_frames.tres")
	var frame := sf.get_frame_texture(&"idle_down", 0) as AtlasTexture
	var used := Rect2(frame.get_image().get_used_rect())
	var face := AtlasTexture.new()
	face.atlas = frame.atlas
	face.region = Rect2(frame.region.position + used.position, Vector2(used.size.x, minf(used.size.x, used.size.y * 0.5)))
	return face


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
