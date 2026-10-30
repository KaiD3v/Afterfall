# Um bloco do menu de inventário, ligado a um recipiente (Inventory, Equipment...) e a uma chave
# nele. Mostra o ícone do item e cuida da parte visual de arrastar e soltar (sistema nativo do
# Godot): durante um arrasto, acende se aceita o item e apaga se recusa. Quem move de fato é o
# menu (sinais drop_requested, activated, rejected). O mesmo controle serve à mochila, ao
# equipamento e, depois, a baús e carros.
class_name ItemSlot
extends Control

signal activated(slot: ItemSlot)                       # botão direito ou duplo clique
signal hovered(slot: ItemSlot)                         # mouse entrou (nome e descrição)
signal unhovered(slot: ItemSlot)                       # mouse saiu
signal drop_requested(from: ItemSlot, to: ItemSlot)    # item solto aqui, e cabe
signal rejected(from: ItemSlot, to: ItemSlot)          # item solto aqui, e não cabe
signal blocked(slot: ItemSlot)                         # tentou arrastar um slot travado

enum Drop { NONE, ACCEPT, REJECT }

const SIZE := Vector2(20, 20)  # slot compacto; o ícone tem 16 px
const ICON := 16               # ícones em 4× (128×128) reduzidos exatamente à metade na tela 4×
const FRAME_DARK := Color8(20, 24, 32)   # shadow_outline
const FILL := Color8(47, 54, 64)         # concrete_darkest: slot com item
const EMPTY := Color8(36, 42, 52)        # slot vazio, um tom abaixo
const HOVER := Color8(227, 168, 69)      # amber_light_glow
const ERROR := Color8(150, 33, 39)       # blood_fresh
const GHOST := Color(0.89, 0.66, 0.27, 0.45)  # silhueta do slot vazio, âmbar apagado
const REJECT_DIM := Color(1, 1, 1, 0.35)  # slot que recusa o item arrastado
const PULSE := 1.25                      # escala do ícone ao entrar no slot

var container: Object  # get_at, can_put, put
var key := 0
var placeholder: Texture2D  # ícone apagado do slot vazio (equipamento: silhueta do tipo)
var caption := ""           # nome do slot, para o menu ("Capacete")
var locked := false:        # travado (arma recarregando): não sai nem entra item
	set(value):
		locked = value
		queue_redraw()
var drop_state := Drop.NONE

var _hover := false
var _icon := TextureRect.new()
var _shown: ItemData        # item mostrado agora, para o pulso só quando ele muda
var _flash := 0.0           # 1 = contorno vermelho cheio, some em 0,3 s
var _drag_from: ItemSlot


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size = Vector2(ICON, ICON)
	_icon.position = (SIZE - _icon.size) / 2
	_icon.pivot_offset = _icon.size / 2
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_icon)
	mouse_entered.connect(func():
		_hover = true
		queue_redraw()
		hovered.emit(self))
	mouse_exited.connect(func():
		_hover = false
		queue_redraw()
		unhovered.emit(self))


func bind(to: Object, at: int) -> void:
	container = to
	key = at
	_shown = item()
	refresh()


func item() -> ItemData:
	return container.get_at(key) if container else null


func refresh() -> void:
	var it := item()
	_icon.texture = it.icon if it else placeholder
	_icon.modulate = Color.WHITE if it else GHOST
	if it and it != _shown and is_inside_tree():
		_icon.scale = Vector2.ONE * PULSE  # o item "assenta" no slot
		create_tween().tween_property(_icon, "scale", Vector2.ONE, 0.1)
	_shown = it
	tooltip_text = ""  # o menu mostra nome e descrição no rodapé
	queue_redraw()


# Contorno vermelho rápido: recusa ou bloqueio.
func flash() -> void:
	_flash = 1.0
	create_tween().tween_property(self, "_flash", 0.0, 0.3).finished.connect(queue_redraw)


func _process(_delta: float) -> void:
	if _flash > 0.0:
		queue_redraw()


# Moldura de 1 px e fundo escuro (elemento simples feito por código), mais claro com item.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, SIZE)
	draw_rect(r, FRAME_DARK)
	draw_rect(r.grow(-1), FILL if item() else EMPTY)
	if drop_state == Drop.ACCEPT:
		draw_rect(r.grow(-1), HOVER, false, 2.0 if _hover else 1.0)
	elif _hover and drop_state == Drop.NONE:
		draw_rect(r.grow(-1), HOVER, false, 1.0)
	if _flash > 0.0:
		draw_rect(r.grow(-1), Color(ERROR, _flash), false, 2.0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:  # qualquer arrasto na tela: este slot aceita ou recusa?
			_drag_from = _slot_of(get_viewport().gui_get_drag_data())
			if _drag_from == null or _drag_from == self:
				drop_state = Drop.NONE
			else:
				drop_state = Drop.ACCEPT if accepts(_drag_from) else Drop.REJECT
			modulate = REJECT_DIM if drop_state == Drop.REJECT else Color.WHITE
			queue_redraw()
		NOTIFICATION_DRAG_END:
			if drop_state == Drop.REJECT and _hover and not get_viewport().gui_is_drag_successful():
				rejected.emit(_drag_from, self)  # soltou aqui, e não cabia
			drop_state = Drop.NONE
			modulate = Color.WHITE
			_drag_from = null
			queue_redraw()


func accepts(from: ItemSlot) -> bool:
	return container != null and not locked and not from.locked and ItemTransfer.can_swap(from.container, from.key, container, key)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT or (click.button_index == MOUSE_BUTTON_LEFT and click.double_click):
		activated.emit(self)
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	var it := item()
	if it == null:
		return null
	if locked:
		blocked.emit(self)
		return null
	var preview := TextureRect.new()
	preview.texture = it.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(ICON, ICON)
	preview.position = -preview.size / 2
	preview.modulate = Color(1, 1, 1, 0.8)
	var holder := Control.new()  # o preview fica centrado no cursor
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"slot": self}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var from := _slot_of(data)
	return from != null and accepts(from)


func _drop_data(_at: Vector2, data: Variant) -> void:
	drop_requested.emit(_slot_of(data), self)


func _slot_of(data: Variant) -> ItemSlot:
	return data.get("slot") as ItemSlot if data is Dictionary else null
