# Menu do inventário (tecla da ação inventory, hoje E, abre e fecha; Esc fecha): equipamento em volta do protagonista e a
# mochila em blocos. Arrastar e soltar move, troca, equipa e desequipa; botão direito usa ou
# equipa (na mochila) e desequipa (no equipamento). O mundo não pausa: o jogador só fica parado.
# Painel e textos são elementos simples feitos por código (Guia de estilo, seção 7); molduras dos
# slots e ícones dos itens vêm do gerador de imagem (assets/sprites/ui).
extends CanvasLayer

const PANEL := Rect2(84, 32, 312, 206)  # na resolução do jogo (480×270)
const BG := Color8(30, 36, 46)          # shadow_deep
const BORDER_OUT := Color8(20, 24, 32)  # shadow_outline
const BORDER_IN := Color8(68, 76, 87)   # concrete_dark
const RIVET := Color8(132, 140, 148)    # concrete_light
const TEXT := Color8(168, 174, 179)     # concrete_highlight
const DIM := Color8(95, 104, 115)       # concrete_mid
const TITLE := Color8(227, 168, 69)     # amber_light_glow
const GAP := 4
# Slots de equipamento em volta do retrato: [slot, posição na área do equipamento, nome, ícone vazio]
const GEAR := [
	[EquipmentItem.Slot.HEAD, Vector2(48, 0), "Capacete", "res://data/items/helmet.tres"],
	[EquipmentItem.Slot.MELEE, Vector2(4, 48), "Arma branca", "res://data/items/machete.tres"],
	[EquipmentItem.Slot.FIREARM, Vector2(92, 48), "Arma de fogo", "res://data/items/pistol_9mm.tres"],
	[EquipmentItem.Slot.BODY, Vector2(48, 96), "Colete", "res://data/items/vest.tres"],
]
const GEAR_AT := Vector2(8, 34)  # área do equipamento dentro do painel (128×128)
const BAG_AT := Vector2(168, 34)  # mochila dentro do painel, em 3 colunas
const BAG_COLUMNS := 3
const SLOT_FRAME := "res://assets/sprites/ui/slots.png"  # moldura slot_32 (gerador de imagem), 128×128 em 4×

@export var player: Player
@export var pauses_game := false  # false: o mundo segue (tensão do gênero); true: pausa ao abrir

var gear_slots: Array[ItemSlot] = []
var bag_slots: Array[ItemSlot] = []
var _bag_title: Label
var _name: Label
var _desc: Label
var _frame: AtlasTexture

@onready var root: Control = $Root


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # abre e fecha mesmo com o jogo pausado
	_build()
	RunState.inventory.changed.connect(_refresh)
	RunState.equipment.changed.connect(_refresh)
	player.died.connect(_on_player_died)
	root.hide()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and is_open():
		close()
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


func close() -> void:
	root.hide()
	player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # volta a mira desenhada
	if pauses_game:
		get_tree().paused = false


# Botão direito: na mochila, equipa o equipável ou usa o consumível; no equipamento, desequipa
# para o primeiro bloco livre.
func activate(slot: ItemSlot) -> void:
	var item := slot.item()
	if item == null:
		return
	var bag := RunState.inventory
	var gear := RunState.equipment
	if slot.container == gear:
		var free := bag.first_free()
		if free >= 0:
			ItemTransfer.swap(gear, slot.key, bag, free)
	elif item is EquipmentItem:
		ItemTransfer.swap(bag, slot.key, gear, item.slot)
	else:
		player.use_item(item)
	_show_details(slot)


func _refresh() -> void:
	for s in gear_slots + bag_slots:
		s.refresh()
	if _bag_title:
		var bag := RunState.inventory
		_bag_title.text = "MOCHILA  %d/%d" % [bag.size(), bag.capacity]


func _show_details(slot: ItemSlot) -> void:
	var item := slot.item() if slot else null
	if item:
		_name.text = item.display_name
		_desc.text = item.description
	elif slot:
		_name.text = slot.caption if slot.caption else "Bloco vazio"
		_desc.text = "Vazio."
	else:
		_name.text = ""
		_desc.text = "Arraste para mover, equipar ou trocar. Botão direito: usar ou equipar. %s fecha." % Keys.label(&"inventory")


func _build() -> void:
	if ResourceLoader.exists(SLOT_FRAME):
		_frame = AtlasTexture.new()
		_frame.atlas = load(SLOT_FRAME)
		_frame.region = Rect2(0, 0, 128, 128)
	var panel := Control.new()
	panel.position = PANEL.position
	panel.size = PANEL.size
	panel.draw.connect(_draw_panel.bind(panel))
	root.add_child(panel)
	_label(panel, "INVENTÁRIO", Vector2(8, 6), TITLE)
	_label(panel, "%s · fechar" % Keys.label(&"inventory"), Vector2(PANEL.size.x - 58, 6), DIM)
	_label(panel, "EQUIPAMENTO", GEAR_AT + Vector2(0, -10), TEXT)
	_bag_title = _label(panel, "MOCHILA", BAG_AT + Vector2(0, -10), TEXT)

	# Retrato: o protagonista parado, de frente, no meio do equipamento.
	var portrait := TextureRect.new()
	portrait.texture = player.sprite.sprite_frames.get_frame_texture(&"idle_down", 0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size = Vector2(40, 64)
	portrait.position = GEAR_AT + Vector2(44, 30)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait)

	for g in GEAR:
		var s := _slot(panel, GEAR_AT + g[1])
		s.caption = g[2]
		var sample: ItemData = load(g[3])
		s.placeholder = sample.icon
		s.bind(RunState.equipment, g[0])
		gear_slots.append(s)
	for i in RunState.inventory.capacity:
		var at := Vector2(i % BAG_COLUMNS, i / BAG_COLUMNS) * (ItemSlot.SIZE + Vector2(GAP, GAP))
		var s := _slot(panel, BAG_AT + at)
		s.bind(RunState.inventory, i)
		bag_slots.append(s)

	_name = _label(panel, "", Vector2(8, 168), TITLE)
	_desc = _label(panel, "", Vector2(8, 180), TEXT)
	_desc.size = Vector2(PANEL.size.x - 16, 22)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _slot(parent: Control, at: Vector2) -> ItemSlot:
	var s := ItemSlot.new()
	s.position = at
	s.frame_texture = _frame
	s.activated.connect(activate)
	s.hovered.connect(_show_details)
	parent.add_child(s)
	return s


func _label(parent: Control, text: String, at: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", 8)
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
	panel.draw_rect(Rect2(4, 164, panel.size.x - 8, 1), BORDER_IN)  # separa os detalhes
	panel.draw_rect(Rect2(152, 22, 1, 138), BORDER_IN)              # equipamento | mochila
	for c in [Vector2(4, 4), Vector2(panel.size.x - 6, 4), Vector2(4, panel.size.y - 6), Vector2(panel.size.x - 6, panel.size.y - 6)]:
		panel.draw_rect(Rect2(c, Vector2(2, 2)), RIVET)
