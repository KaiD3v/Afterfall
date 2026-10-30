# Menu do inventário (tecla da ação inventory, hoje E, abre e fecha; Esc fecha): equipamento em
# volta do protagonista e a mochila em blocos. Arrastar e soltar move, troca, equipa e desequipa;
# botão direito ou duplo clique usa ou equipa (na mochila) e desequipa (no equipamento). Toda troca
# passa por _transfer: som, pulso no slot, e recusa com motivo no rodapé. O mundo não pausa: o
# jogador só fica parado.
# Saque: abrir um móvel (open_loot) mostra o conteúdo dele num painel ao lado; dá para pegar item
# por item (arrastar, botão direito), pegar tudo (botão ou a tecla de interação) e deixar coisas lá.
# Painel e textos são elementos simples feitos por código (Guia de estilo, seção 7); molduras dos
# slots e ícones dos itens vêm do gerador de imagem (assets/sprites/ui).
extends CanvasLayer

const PANEL := Rect2(84, 17, 312, 236)  # na resolução do jogo (480×270); grade de 4 px
const PANEL_LOOTING := Vector2(8, 17)   # com um móvel aberto, o painel vai para a esquerda
const LOOT_PANEL := Rect2(324, 17, 148, 140)  # conteúdo do móvel, à direita
const LOOT_AT := Vector2(22, 26)        # grade do móvel dentro do painel dele, 3 colunas
const BG := Color8(30, 36, 46)          # shadow_deep
const BORDER_OUT := Color8(20, 24, 32)  # shadow_outline
const BORDER_IN := Color8(68, 76, 87)   # concrete_dark
const RIVET := Color8(132, 140, 148)    # concrete_light
const TEXT := Color8(168, 174, 179)     # concrete_highlight
const DIM := Color8(95, 104, 115)       # concrete_mid
const TITLE := Color8(227, 168, 69)     # amber_light_glow
const WARN := Color8(184, 118, 68)      # rust_highlight: avisos no rodapé
const MESSAGE_TIME := 1.6               # segundos que um aviso fica no rodapé
const DIM_WORLD := Color(0, 0, 0, 0.4)  # véu sobre o mundo, que continua rodando atrás
const GAP := 4
# Slots de equipamento encostados no retrato: [slot, posição na área do equipamento, tamanho,
# nome, rótulo curto, ícone da silhueta]. Armas em 48 px: o item mais importante.
const GEAR := [
	[EquipmentItem.Slot.HEAD, Vector2(56, 0), ItemSlot.SMALL, "Capacete", "ELMO", "res://data/items/helmet.tres"],
	[EquipmentItem.Slot.MELEE, Vector2(4, 52), ItemSlot.LARGE, "Arma branca", "BRANCA", "res://data/items/machete.tres"],
	[EquipmentItem.Slot.FIREARM, Vector2(92, 52), ItemSlot.LARGE, "Arma de fogo", "FOGO", "res://data/items/pistol_9mm.tres"],
	[EquipmentItem.Slot.BODY, Vector2(56, 116), ItemSlot.SMALL, "Colete", "CORPO", "res://data/items/vest.tres"],
]
const GEAR_AT := Vector2(8, 40)   # área do equipamento dentro do painel (144×148)
const PORTRAIT_SCALE := 0.5       # retrato 2× o tamanho do jogo (arte em 4×)
const PORTRAIT_TOP := 36          # topo do retrato, logo abaixo do slot da cabeça
const BAG_AT := Vector2(176, 60)  # mochila 3×3, centrada na metade direita
const BAG_COLUMNS := 3
const SLOT_FRAMES := "res://assets/sprites/ui/slots.png"  # slot_32 e slot_48 (gerador de imagem), em 4×

@export var player: Player
@export var pauses_game := false  # false: o mundo segue (tensão do gênero); true: pausa ao abrir
@export var stow_sound: AudioStream    # item guardado ou movido na mochila
@export var reject_sound: AudioStream  # item recusado ou ação impossível

var gear_slots: Array[ItemSlot] = []
var bag_slots: Array[ItemSlot] = []
var _bag_title: Label
var _name: Label
var _desc: Label
var _frames := {}  # tamanho do slot -> moldura gerada
var _hovered: ItemSlot
var _audio := AudioStreamPlayer.new()
var sheet := ItemSheet.new()  # ficha do item sob o mouse, ao lado do slot
var loot_slots: Array[ItemSlot] = []
var looting: Node  # móvel aberto agora (null = só o inventário)
var _panel: Control
var _loot_box: Control
var _loot_title: Label
var _message_id := 0  # um aviso novo cancela a volta do anterior

@onready var root: Control = $Root


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # abre e fecha mesmo com o jogo pausado
	add_to_group(Groups.INVENTORY_MENU)
	_audio.bus = &"SFX"
	add_child(_audio)
	_build()
	RunState.inventory.changed.connect(_refresh)
	RunState.equipment.changed.connect(_refresh)
	player.firearm.changed.connect(_on_firearm_changed)
	player.died.connect(_on_player_died)
	_on_firearm_changed()
	root.hide()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and is_open():
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and is_open() and looting:
		take_all()  # a mesma tecla que abriu o móvel pega tudo
		get_viewport().set_input_as_handled()


func _on_player_died() -> void:
	if is_open():
		close()


func is_open() -> bool:
	return root.visible


func toggle() -> void:
	if is_open():
		close()
	elif not player.is_dead():
		open()


func open() -> void:
	root.show()
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if pauses_game:
		get_tree().paused = true
	_show_details(null)
	_refresh()


# Abre o menu com o conteúdo do móvel ao lado da mochila.
func open_loot(container: Node) -> void:
	if player.is_dead():
		return
	looting = container
	var inv: Inventory = container.contents()
	for i in loot_slots.size():
		loot_slots[i].bind(inv, i)
	_loot_title.text = String(container.label).to_upper()
	_panel.position = PANEL_LOOTING
	_loot_box.show()
	open()


# Pega do móvel tudo o que couber na mochila (munição direto para a reserva).
func take_all() -> void:
	if looting == null:
		return
	var result: Dictionary = looting.take_all(player)
	if result.got:
		_play(stow_sound)
		_show_details(null)
		_name.text = "Pegou: " + ", ".join(result.got)
	if result.full:
		var left := loot_slots.filter(func(s): return s.item() != null)
		_warn(left[0] if left else loot_slots[0], "Mochila cheia: o resto ficou no móvel")
	elif not result.got:
		_warn(loot_slots[0], "O móvel está vazio")


func close() -> void:
	root.hide()
	looting = null
	_loot_box.hide()
	_panel.position = PANEL.position
	player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # volta a mira desenhada
	if pauses_game:
		get_tree().paused = false


# Botão direito ou duplo clique: na mochila, equipa o equipável (trocando com o que estava no
# slot) ou usa o consumível; no equipamento, desequipa para o primeiro bloco livre.
func activate(slot: ItemSlot) -> void:
	var item := slot.item()
	if item == null:
		return
	if slot.container == RunState.equipment or _is_loot(slot):
		var free := RunState.inventory.first_free()
		if free < 0 and not (_is_loot(slot) and not _takes_slot(item)):
			_warn(slot, "Mochila cheia")
		else:
			_transfer(slot, bag_slots[maxi(free, 0)])
	elif item is EquipmentItem:
		_transfer(slot, gear_slot(item.slot))
	elif player.use_item(item):  # o som de uso toca no jogador
		_show_details(slot)
	else:
		_warn(slot, _why_not_use(item))


# Move ou troca entre dois slots; se não couber, recusa com o motivo.
func _transfer(from: ItemSlot, to: ItemSlot) -> bool:
	if not to.accepts(from):
		_reject(from, to)
		return false
	var moving := from.item()
	var taking := _is_loot(from) and not _is_loot(to)
	if taking and not moving.on_pickup(player):  # munição: vai direto para a reserva
		from.container.put(from.key, null)
		RunState.stats.looted += 1
		_play(stow_sound)
		_show_details(to)
		return true
	ItemTransfer.swap(from.container, from.key, to.container, to.key)
	if taking:
		RunState.stats.looted += 1
	var gear := moving as EquipmentItem
	var equipped := to.container == RunState.equipment and gear != null and gear.equip_sound != null
	_play(gear.equip_sound if equipped else stow_sound)
	_show_details(to)
	return true


func _is_loot(slot: ItemSlot) -> bool:
	return looting != null and slot in loot_slots


# O item ocupa um bloco ao ser pego? (munição não: vai para a reserva)
func _takes_slot(item: ItemData) -> bool:
	return not item is AmmoItem


func _reject(from: ItemSlot, to: ItemSlot) -> void:
	_warn(to, _why_not(from, to))


func _why_not(from: ItemSlot, to: ItemSlot) -> String:
	if from.locked or to.locked:
		return "Recarregando: espere a arma"
	var moving := from.item()
	if not to.container.can_put(to.key, moving):
		return "%s não vai em %s" % [moving.display_name, to.caption.to_lower()]
	return "%s não vai em %s" % [to.item().display_name, from.caption.to_lower()]  # a troca não volta


func _why_not_use(item: ItemData) -> String:
	if item is HealItem and player.health.is_full():
		return "Vida cheia"
	return "Não dá para usar agora"


# Aviso no rodapé, com contorno vermelho no slot e som de recusa.
func _warn(slot: ItemSlot, text: String) -> void:
	slot.flash()
	_play(reject_sound)
	_message_id += 1
	var id := _message_id
	_name.text = text
	_name.add_theme_color_override("font_color", WARN)
	_desc.text = ""
	get_tree().create_timer(MESSAGE_TIME).timeout.connect(func():
		if id == _message_id and is_instance_valid(_name):
			_show_details(_hovered))


func _play(stream: AudioStream) -> void:
	if stream:
		_audio.stream = stream
		_audio.play()


# A arma de fogo não sai nem entra no slot durante a recarga, e o slot mostra a munição.
func _on_firearm_changed() -> void:
	var slot := gear_slot(EquipmentItem.Slot.FIREARM)
	if slot == null:
		return
	var gun := player.firearm
	slot.locked = gun.reloading
	slot.badge = "REC" if gun.reloading else "%d|%d" % [gun.ammo, gun.reserve]


func gear_slot(slot: int) -> ItemSlot:
	for s in gear_slots:
		if s.key == slot:
			return s
	return null


func _refresh() -> void:
	for s in gear_slots + bag_slots:
		s.refresh()
	if _bag_title:
		var bag := RunState.inventory
		_bag_title.text = "MOCHILA  %d/%d" % [bag.size(), bag.capacity]
		_bag_title.add_theme_color_override("font_color", WARN if bag.is_full() else TEXT)  # cheia: avisa


func _on_hovered(slot: ItemSlot) -> void:
	_hovered = slot
	_show_details(slot)


func _on_unhovered(slot: ItemSlot) -> void:
	if _hovered == slot:  # o rodapé volta à dica quando o mouse sai do item
		_hovered = null
		_show_details(null)


func _show_details(slot: ItemSlot) -> void:
	_message_id += 1  # um aviso pendente não volta por cima disto
	_name.add_theme_color_override("font_color", TITLE)
	var item := slot.item() if slot else null
	if item:
		_name.text = item.display_name
		_desc.text = _action_hint(slot, item)
		sheet.show_for(item, _equipped_like(slot, item), slot.get_global_rect(), root.get_global_rect())
		return
	sheet.hide()
	if slot:
		_name.text = slot.caption if slot.caption else "Bloco vazio"
		_desc.text = "Vazio. Arraste um item para cá."
	else:
		_name.text = ""
		_desc.text = "Arraste para mover · Botão direito ou 2 cliques: usar"  # a tecla de fechar está no título


# O que o botão direito faz com este item, para o rodapé.
func _action_hint(slot: ItemSlot, item: ItemData) -> String:
	if _is_loot(slot):
		return "Botão direito: pegar · %s pega tudo" % Keys.label(&"interact")
	if slot.container == RunState.equipment:
		return "Botão direito: desequipar · arraste para a mochila"
	if item is EquipmentItem:
		var swap := " (troca com o equipado)" if _equipped_like(slot, item) else ""
		return "Botão direito: equipar" + swap
	if item is HealItem:
		return "Botão direito: usar · Q usa sem abrir o menu"
	return "Arraste para mover"


# O item equipado no mesmo slot que este, para a ficha comparar (itens da mochila e do móvel).
func _equipped_like(slot: ItemSlot, item: ItemData) -> ItemData:
	if slot.container == RunState.equipment or not item is EquipmentItem:
		return null
	return RunState.equipment.get_at(item.slot)


func _build() -> void:
	if ResourceLoader.exists(SLOT_FRAMES):
		for spec in [[ItemSlot.SMALL, Rect2(0, 0, 128, 128)], [ItemSlot.LARGE, Rect2(128, 0, 192, 192)]]:
			var frame := AtlasTexture.new()
			frame.atlas = load(SLOT_FRAMES)
			frame.region = spec[1]
			_frames[spec[0]] = frame
	var veil := ColorRect.new()
	veil.color = DIM_WORLD
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var panel := Control.new()
	panel.position = PANEL.position
	panel.size = PANEL.size
	panel.draw.connect(_draw_panel.bind(panel))
	root.add_child(panel)
	_panel = panel
	_build_loot_box()
	_label(panel, "INVENTÁRIO", Vector2(8, 6), TITLE)
	_label(panel, "%s · fechar" % Keys.label(&"inventory"), Vector2(PANEL.size.x - 58, 6), DIM)
	_label(panel, "EQUIPAMENTO", Vector2(8, 24), TEXT)
	_bag_title = _label(panel, "MOCHILA", Vector2(BAG_AT.x, 24), TEXT)
	_portrait(panel)

	for g in GEAR:
		var s := _slot(panel, GEAR_AT + g[1], g[2])
		s.caption = g[3]
		s.short_caption = g[4]
		var sample: ItemData = load(g[5])
		s.placeholder = sample.icon
		s.bind(RunState.equipment, g[0])
		gear_slots.append(s)
	for i in RunState.inventory.capacity:
		var at := Vector2(i % BAG_COLUMNS, i / BAG_COLUMNS) * (ItemSlot.SMALL + Vector2(GAP, GAP))
		var s := _slot(panel, BAG_AT + at, ItemSlot.SMALL)
		s.bind(RunState.inventory, i)
		bag_slots.append(s)

	_name = _label(panel, "", Vector2(8, 198), TITLE)
	_desc = _label(panel, "", Vector2(8, 208), TEXT)
	_desc.size = Vector2(PANEL.size.x - 16, 22)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(sheet)  # por cima do painel


# O protagonista parado, de frente, recortado no corpo (sem a margem do quadro) e 2× maior.
func _portrait(panel: Control) -> void:
	var frame := player.sprite.sprite_frames.get_frame_texture(&"idle_down", 0) as AtlasTexture
	var used := Rect2(frame.get_image().get_used_rect())
	var body := AtlasTexture.new()
	body.atlas = frame.atlas
	body.region = Rect2(frame.region.position + used.position, used.size)
	var portrait := TextureRect.new()
	portrait.texture = body
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size = (used.size * PORTRAIT_SCALE).round()
	portrait.position = (GEAR_AT + Vector2(72 - portrait.size.x / 2, PORTRAIT_TOP)).round()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait)


# Painel do móvel aberto: título, 2 fileiras de 3 blocos e o botão de pegar tudo.
func _build_loot_box() -> void:
	_loot_box = Control.new()
	_loot_box.position = LOOT_PANEL.position
	_loot_box.size = LOOT_PANEL.size
	_loot_box.draw.connect(_draw_loot_box)
	_loot_box.hide()
	root.add_child(_loot_box)
	_loot_title = _label(_loot_box, "", Vector2(8, 6), TITLE)
	for i in LootMemory.CAPACITY:
		var at := Vector2(i % BAG_COLUMNS, i / BAG_COLUMNS) * (ItemSlot.SMALL + Vector2(GAP, GAP))
		loot_slots.append(_slot(_loot_box, LOOT_AT + at, ItemSlot.SMALL))
	var take := Button.new()
	take.text = "PEGAR TUDO · %s" % Keys.label(&"interact")
	take.position = Vector2(8, 106)
	take.size = Vector2(LOOT_PANEL.size.x - 16, 24)
	take.focus_mode = Control.FOCUS_NONE
	for state in [["normal", BORDER_IN], ["hover", TITLE], ["pressed", TITLE]]:  # metal do painel
		var box := StyleBoxFlat.new()
		box.bg_color = BORDER_OUT
		box.border_color = state[1]
		box.set_border_width_all(1)
		take.add_theme_stylebox_override(state[0], box)
	take.add_theme_color_override("font_color", TEXT)
	take.add_theme_color_override("font_hover_color", TITLE)
	take.pressed.connect(take_all)
	_loot_box.add_child(take)


func _draw_loot_box() -> void:
	var r := Rect2(Vector2.ZERO, _loot_box.size)
	_loot_box.draw_rect(r, BORDER_OUT)
	_loot_box.draw_rect(r.grow(-1), BORDER_IN)
	_loot_box.draw_rect(r.grow(-2), BORDER_OUT)
	_loot_box.draw_rect(r.grow(-3), BG)
	_loot_box.draw_rect(Rect2(4, 18, _loot_box.size.x - 8, 1), BORDER_IN)


func _slot(parent: Control, at: Vector2, at_size: Vector2) -> ItemSlot:
	var s := ItemSlot.new(at_size)
	s.position = at
	s.frame_texture = _frames.get(at_size)
	s.activated.connect(activate)
	s.drop_requested.connect(_transfer)
	s.rejected.connect(_reject)
	s.blocked.connect(func(blocked_slot): _warn(blocked_slot, "Recarregando: espere a arma"))
	s.hovered.connect(_on_hovered)
	s.unhovered.connect(_on_unhovered)
	parent.add_child(s)
	return s


func _label(parent: Control, text: String, at: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# Metal escuro com moldura dupla e rebites nos cantos, nas cores da HUD.
func _draw_panel(panel: Control) -> void:
	var r := Rect2(Vector2.ZERO, panel.size)
	panel.draw_rect(r, BORDER_OUT)
	panel.draw_rect(r.grow(-1), BORDER_IN)
	panel.draw_rect(r.grow(-2), BORDER_OUT)
	panel.draw_rect(r.grow(-3), BG)
	panel.draw_rect(Rect2(4, 18, panel.size.x - 8, 1), BORDER_IN)  # separa o título
	panel.draw_rect(Rect2(4, 194, panel.size.x - 8, 1), BORDER_IN)  # separa os detalhes
	panel.draw_rect(Rect2(156, 22, 1, 168), BORDER_IN)              # equipamento | mochila
	for c in [Vector2(4, 4), Vector2(panel.size.x - 6, 4), Vector2(4, panel.size.y - 6), Vector2(panel.size.x - 6, panel.size.y - 6)]:
		panel.draw_rect(Rect2(c, Vector2(2, 2)), RIVET)
