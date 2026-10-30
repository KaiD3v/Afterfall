# Menu do inventário (tecla da ação inventory, hoje E, abre e fecha; Esc fecha): painel compacto
# embaixo, com abas (Mochila, Diário, Status, Crafting). A aba Mochila tem o equipamento em volta
# do protagonista e a mochila em blocos; as outras são páginas futuras ("Em breve"). Arrastar e soltar move, troca, equipa e desequipa;
# botão direito ou duplo clique usa ou equipa (na mochila) e desequipa (no equipamento). Toda troca
# passa por _transfer: som, pulso no slot, e recusa com motivo no rodapé. O mundo não pausa: o
# jogador só fica parado.
# Saque: abrir um móvel (open_loot) mostra o conteúdo dele num painel ao lado; dá para pegar item
# por item (arrastar, botão direito), pegar tudo (botão ou a tecla de interação) e deixar coisas lá.
# Painel, abas e molduras são elementos simples feitos por código (Guia de estilo, seção 7); os
# ícones dos itens vêm do gerador de imagem (assets/sprites/ui).
extends CanvasLayer

const PANEL := Rect2(152, 76, 176, 118)  # centralizado na tela (480×270)
const PANEL_LOOTING := Vector2(112, 76)    # com um móvel aberto, o painel abre espaço à direita
const LOOT_PANEL := Rect2(292, 76, 76, 96)  # conteúdo do móvel
const LOOT_AT := Vector2(6, 24)             # grade do móvel dentro do painel dele, 3 colunas
const BG := Color8(30, 36, 46)          # shadow_deep
const BORDER_OUT := Color8(20, 24, 32)  # shadow_outline
const BORDER_IN := Color8(68, 76, 87)   # concrete_dark
const TEXT := Color8(168, 174, 179)     # concrete_highlight
const DIM := Color8(95, 104, 115)       # concrete_mid
const TITLE := Color8(227, 168, 69)     # amber_light_glow
const WARN := Color8(184, 118, 68)      # rust_highlight: avisos no rodapé
const MESSAGE_TIME := 1.6               # segundos que um aviso fica no rodapé
const DIM_WORLD := Color(0, 0, 0, 0.35)  # véu sobre o mundo, que continua rodando atrás
const SLOT_GAP := 2
# Abas: [id, título, o que a página vai ter]. Página nova = uma linha aqui e uma cena no lugar do
# "Em breve" (page_for). Só a mochila existe hoje.
const TABS := [
	[&"bag", "MOCHILA", ""],
	[&"journal", "DIÁRIO", "Missões e anotações da run"],
	[&"status", "STATUS", "Vida, fôlego e atributos"],
	[&"crafting", "CRAFTING", "Receitas com o que você carrega"],
]
# Equipamento em duas colunas em volta do retrato: [slot, posição na página, nome, ícone da silhueta]
const GEAR := [
	[EquipmentItem.Slot.HEAD, Vector2(8, 26), "Capacete", "res://data/items/helmet.tres"],
	[EquipmentItem.Slot.BODY, Vector2(8, 50), "Colete", "res://data/items/vest.tres"],
	[EquipmentItem.Slot.MELEE, Vector2(58, 26), "Arma branca", "res://data/items/machete.tres"],
	[EquipmentItem.Slot.FIREARM, Vector2(58, 50), "Arma de fogo", "res://data/items/pistol_9mm.tres"],
]
const PORTRAIT_AT := Vector2(30, 28)  # retrato no tamanho do jogo, entre as colunas
const BAG_AT := Vector2(98, 26)       # mochila 3×3
const BAG_COLUMNS := 3

@export var player: Player
@export var pauses_game := false  # false: o mundo segue (tensão do gênero); true: pausa ao abrir
@export var stow_sound: AudioStream    # item guardado ou movido na mochila
@export var reject_sound: AudioStream  # item recusado ou ação impossível

var gear_slots: Array[ItemSlot] = []
var bag_slots: Array[ItemSlot] = []
var tab := 0  # aba aberta (índice em TABS)
var pages := {}  # id da aba -> página (Control)
var _tab_title: Label
var _bag_count: Label  # "2/9" no título, só na mochila
var _ammo: Label       # munição embaixo do slot da arma de fogo
var _name: Label
var _desc: Label
var _hovered: ItemSlot
var _audio := AudioStreamPlayer.new()
var sheet := ItemSheet.new()  # ficha do item sob o mouse, ao lado do slot
var loot_slots: Array[ItemSlot] = []
var looting: Node  # móvel aberto agora (null = só o inventário)
var _loot_inv: Inventory  # conteúdo do móvel aberto; o menu escuta as mudanças dele
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
	get_tree().call_group(Groups.HIDE_WITH_MENU, "hide")
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
	_loot_inv = container.contents()
	_loot_inv.changed.connect(_refresh)  # pegar ou guardar redesenha os blocos do móvel na hora
	for i in loot_slots.size():
		loot_slots[i].bind(_loot_inv, i)
	_loot_title.text = String(container.label).to_upper()
	select_tab(0)  # o saque é na mochila
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
		_footer("Pegou: " + ", ".join(result.got), "", TITLE)
	if result.full:
		var left := loot_slots.filter(func(s): return s.item() != null)
		_warn(left[0] if left else loot_slots[0], "Mochila cheia: o resto ficou no móvel")
	elif not result.got:
		_warn(loot_slots[0], "O móvel está vazio")


func close() -> void:
	root.hide()
	get_tree().call_group(Groups.HIDE_WITH_MENU, "show")
	if _loot_inv and _loot_inv.changed.is_connected(_refresh):
		_loot_inv.changed.disconnect(_refresh)
	_loot_inv = null
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
	_footer(text, "", WARN)
	get_tree().create_timer(MESSAGE_TIME).timeout.connect(func():
		if id == _message_id and is_instance_valid(_name):
			_show_details(_hovered))


func _play(stream: AudioStream) -> void:
	if stream:
		_audio.stream = stream
		_audio.play()


# A arma de fogo não sai nem entra no slot durante a recarga; a munição aparece embaixo do slot.
func _on_firearm_changed() -> void:
	var slot := gear_slot(EquipmentItem.Slot.FIREARM)
	if slot == null:
		return
	var gun := player.firearm
	slot.locked = gun.reloading
	_ammo.text = "" if not gun.is_equipped() else ("REC" if gun.reloading else "%d|%d" % [gun.ammo, gun.reserve])


func gear_slot(slot: int) -> ItemSlot:
	for s in gear_slots:
		if s.key == slot:
			return s
	return null


func _refresh() -> void:
	for s in gear_slots + bag_slots + (loot_slots if looting else []):
		s.refresh()
	if _bag_count:
		var bag := RunState.inventory
		_bag_count.text = "%d/%d" % [bag.size(), bag.capacity]
		_bag_count.add_theme_color_override("font_color", WARN if bag.is_full() else DIM)  # cheia: avisa


func _on_hovered(slot: ItemSlot) -> void:
	_hovered = slot
	_show_details(slot)


func _on_unhovered(slot: ItemSlot) -> void:
	if _hovered == slot:  # o rodapé volta à dica quando o mouse sai do item
		_hovered = null
		_show_details(null)


func _show_details(slot: ItemSlot) -> void:
	_message_id += 1  # um aviso pendente não volta por cima disto
	var item := slot.item() if slot else null
	if item:
		_footer(item.display_name, _action_hint(slot, item), TITLE)
		sheet.show_for(item, _equipped_like(slot, item), slot.get_global_rect(), root.get_global_rect())
		return
	sheet.hide()
	if slot:
		_footer(slot.caption if slot.caption else "Bloco vazio", "vazio", TITLE)
	elif TABS[tab][0] != &"bag":
		_footer("", TABS[tab][2], DIM)
	else:
		_footer("", "Arraste ou botão direito para usar", DIM)


# Rodapé de uma linha: nome em destaque e, logo depois, a dica.
func _footer(title: String, hint: String, color: Color) -> void:
	_name.text = title
	_name.add_theme_color_override("font_color", color)
	_desc.text = ("· " + hint) if title and hint else hint
	var w := 0.0 if title == "" else _name.get_theme_default_font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 4
	_desc.position.x = _name.position.x + w


# O que o botão direito faz com este item, para o rodapé.
func _action_hint(slot: ItemSlot, item: ItemData) -> String:
	if _is_loot(slot):
		return "botão direito: pegar"
	if slot.container == RunState.equipment:
		return "botão direito: desequipar"
	if item is EquipmentItem:
		return "botão direito: trocar" if _equipped_like(slot, item) else "botão direito: equipar"
	if item is HealItem:
		return "botão direito: usar"
	return "arraste para mover"


# O item equipado no mesmo slot que este, para a ficha comparar (itens da mochila e do móvel).
func _equipped_like(slot: ItemSlot, item: ItemData) -> ItemData:
	if slot.container == RunState.equipment or not item is EquipmentItem:
		return null
	return RunState.equipment.get_at(item.slot)


func _build() -> void:
	var veil := ColorRect.new()
	veil.color = DIM_WORLD
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	_panel = _box(root, PANEL)
	_panel.draw.connect(func(): _panel.draw_rect(Rect2(4, 18, PANEL.size.x - 8, 1), BORDER_IN))
	_panel.draw.connect(func(): _panel.draw_rect(Rect2(4, PANEL.size.y - 17, PANEL.size.x - 8, 1), BORDER_IN))
	for i in TABS.size():
		_panel.add_child(_tab_button(i))
	_tab_title = _label(_panel, "", Vector2(80, 3), TITLE)
	_bag_count = _label(_panel, "", Vector2(PANEL.size.x - 24, 3), DIM)
	for t in TABS:
		pages[t[0]] = _bag_page() if t[0] == &"bag" else _soon_page(t[2])
		_panel.add_child(pages[t[0]])
	_name = _label(_panel, "", Vector2(6, PANEL.size.y - 15), TITLE)
	_desc = _label(_panel, "", Vector2(6, PANEL.size.y - 15), TEXT)
	_build_loot_box()
	root.add_child(sheet)  # por cima de tudo
	select_tab(0)


# Troca a aba: mostra a página dela e o título; o contador da mochila só na mochila.
func select_tab(index: int) -> void:
	tab = index
	for i in TABS.size():
		pages[TABS[i][0]].visible = i == index
	_tab_title.text = TABS[index][1]
	_bag_count.visible = TABS[index][0] == &"bag"
	for b in _panel.get_children():
		if b.has_meta("tab"):
			b.queue_redraw()
	if _name:
		_show_details(null)


# Página da mochila: equipamento em duas colunas em volta do retrato e a mochila 3×3.
func _bag_page() -> Control:
	var page := Control.new()
	page.size = PANEL.size
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for g in GEAR:
		var s := _slot(page, g[1])
		s.caption = g[2]
		var sample: ItemData = load(g[3])
		s.placeholder = sample.icon
		s.bind(RunState.equipment, g[0])
		gear_slots.append(s)
	page.add_child(_portrait())
	var gun_slot: ItemSlot = gear_slot(EquipmentItem.Slot.FIREARM)
	_ammo = _label(page, "", gun_slot.position + Vector2(-4, ItemSlot.SIZE.y), TITLE)
	page.draw.connect(func(): page.draw_rect(Rect2(BAG_AT.x - 10, 24, 1, 66), BORDER_IN))
	for i in RunState.inventory.capacity:
		var at := Vector2(i % BAG_COLUMNS, i / BAG_COLUMNS) * (ItemSlot.SIZE + Vector2(SLOT_GAP, SLOT_GAP))
		var s := _slot(page, BAG_AT + at)
		s.bind(RunState.inventory, i)
		bag_slots.append(s)
	return page


# Página de uma aba que ainda não existe.
func _soon_page(what: String) -> Control:
	var page := Control.new()
	page.size = PANEL.size
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(page, "Em breve", Vector2(0, 52), DIM)
	l.size.x = PANEL.size.x
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.set_meta("soon", what)
	return page


# Ícone de aba 12×12 (pictograma simples por código): âmbar e sublinhado se ativo, clicável.
func _tab_button(index: int) -> Control:
	var b := Control.new()
	b.position = Vector2(6 + index * 18, 4)
	b.size = Vector2(12, 14)
	b.set_meta("tab", index)
	b.tooltip_text = TABS[index][1].capitalize()
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			select_tab(index))
	b.draw.connect(func():
		var col := TITLE if index == tab else DIM
		match TABS[index][0]:
			&"bag":  # mochila
				b.draw_rect(Rect2(2, 3, 8, 8), col)
				b.draw_rect(Rect2(4, 1, 4, 2), col)
				b.draw_rect(Rect2(3, 6, 6, 1), BG)
			&"journal":  # caderno
				b.draw_rect(Rect2(2, 1, 8, 10), col)
				b.draw_rect(Rect2(3, 2, 1, 8), BG)
				b.draw_rect(Rect2(5, 4, 4, 1), BG)
				b.draw_rect(Rect2(5, 6, 4, 1), BG)
			&"status":  # figura
				b.draw_rect(Rect2(5, 1, 3, 3), col)
				b.draw_rect(Rect2(3, 5, 7, 2), col)
				b.draw_rect(Rect2(4, 7, 5, 4), col)
			&"crafting":  # martelo
				b.draw_rect(Rect2(2, 2, 7, 3), col)
				b.draw_rect(Rect2(5, 5, 2, 6), col)
		if index == tab:
			b.draw_rect(Rect2(0, 13, 12, 1), TITLE))
	return b


# O protagonista parado, de frente, recortado no corpo e no tamanho do jogo.
func _portrait() -> TextureRect:
	var frame := player.sprite.sprite_frames.get_frame_texture(&"idle_down", 0) as AtlasTexture
	var used := Rect2(frame.get_image().get_used_rect())
	var body := AtlasTexture.new()
	body.atlas = frame.atlas
	body.region = Rect2(frame.region.position + used.position, used.size)
	var portrait := TextureRect.new()
	portrait.texture = body
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size = (used.size * World.ART_SCALE).round()
	portrait.position = PORTRAIT_AT
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait


# Painel do móvel aberto: título, 2 fileiras de 3 blocos e "F pegar tudo" (clicável).
func _build_loot_box() -> void:
	_loot_box = _box(root, LOOT_PANEL)
	_loot_box.draw.connect(func(): _loot_box.draw_rect(Rect2(4, 18, LOOT_PANEL.size.x - 8, 1), BORDER_IN))
	_loot_box.hide()
	_loot_title = _label(_loot_box, "", Vector2(6, 3), TITLE)
	for i in LootMemory.CAPACITY:
		var at := Vector2(i % BAG_COLUMNS, i / BAG_COLUMNS) * (ItemSlot.SIZE + Vector2(SLOT_GAP, SLOT_GAP))
		loot_slots.append(_slot(_loot_box, LOOT_AT + at))
	var take := Button.new()
	take.text = "%s pegar tudo" % Keys.label(&"interact")
	take.flat = true
	take.position = Vector2(4, 70)
	take.focus_mode = Control.FOCUS_NONE
	take.add_theme_color_override("font_color", DIM)
	take.add_theme_color_override("font_hover_color", TITLE)
	take.pressed.connect(take_all)
	_loot_box.add_child(take)


# Caixa de metal escuro com moldura de 1 px.
func _box(parent: Control, r: Rect2) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.draw.connect(func():
		var rr := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(rr, BORDER_OUT)
		c.draw_rect(rr.grow(-1), BORDER_IN)
		c.draw_rect(rr.grow(-2), BG))
	parent.add_child(c)
	return c


func _slot(parent: Control, at: Vector2) -> ItemSlot:
	var s := ItemSlot.new()
	s.position = at
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
