# Um bloco do menu de inventário, ligado a um recipiente (Inventory, Equipment...) e a uma chave
# nele. Mostra o ícone do item, aceita arrastar e soltar (sistema nativo do Godot) e avisa o menu
# no botão direito e ao passar o mouse. O mesmo controle serve à mochila, ao equipamento e, depois,
# a baús e carros.
class_name ItemSlot
extends Control

signal activated(slot: ItemSlot)  # botão direito
signal hovered(slot: ItemSlot)    # mouse entrou (para o nome e a descrição)
signal unhovered(slot: ItemSlot)  # mouse saiu

const SMALL := Vector2(32, 32)  # ícones em 4× (128×128) cabem reduzidos a 1/4, como o resto da arte
const LARGE := Vector2(48, 48)  # armas: mais destaque (moldura slot_48)
const FRAME := Color8(68, 76, 87)        # concrete_dark
const FRAME_DARK := Color8(20, 24, 32)   # shadow_outline
const FILL := Color8(30, 36, 46)         # shadow_deep
const RIVET := Color8(132, 140, 148)     # concrete_light
const HOVER := Color8(227, 168, 69)      # amber_light_glow
const GHOST := Color(0.89, 0.66, 0.27, 0.45)  # silhueta do slot vazio, âmbar apagado
const LABEL := Color8(95, 104, 115)      # concrete_mid

var container: Object  # get_at, can_put, put
var key := 0
var placeholder: Texture2D  # ícone apagado do slot vazio (equipamento: silhueta do tipo)
var caption := ""           # nome do slot vazio, para o menu
var short_caption := ""     # rótulo curto escrito dentro do slot vazio ("CABEÇA")
var slot_size := SMALL
var frame_texture: Texture2D  # moldura gerada; sem ela, a moldura é desenhada aqui

var _hover := false
var _icon := TextureRect.new()


func _init(at_size := SMALL) -> void:
	slot_size = at_size
	custom_minimum_size = slot_size
	size = slot_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size = slot_size
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
	refresh()


func item() -> ItemData:
	return container.get_at(key) if container else null


func refresh() -> void:
	var it := item()
	_icon.texture = it.icon if it else placeholder
	_icon.modulate = Color.WHITE if it else GHOST
	tooltip_text = ""  # o menu mostra nome e descrição no rodapé
	queue_redraw()


# Moldura de metal rebitado (elemento simples feito por código; troca pela gerada quando houver).
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, slot_size)
	if frame_texture:
		draw_texture_rect(frame_texture, r, false)
	else:
		draw_rect(r, FRAME_DARK)
		draw_rect(r.grow(-1), FRAME)
		draw_rect(r.grow(-2), FILL)
		for c in [Vector2(2, 2), Vector2(slot_size.x - 3, 2), Vector2(2, slot_size.y - 3), Vector2(slot_size.x - 3, slot_size.y - 3)]:
			draw_rect(Rect2(c, Vector2.ONE), RIVET)
	if short_caption and item() == null:
		draw_string(get_theme_default_font(), Vector2(0, slot_size.y - 4), short_caption, HORIZONTAL_ALIGNMENT_CENTER, slot_size.x, 16, LABEL)
	if _hover:
		draw_rect(r.grow(-1), HOVER, false, 1.0)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		activated.emit(self)
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	var it := item()
	if it == null:
		return null
	var preview := TextureRect.new()
	preview.texture = it.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = slot_size
	preview.position = -slot_size / 2
	preview.modulate = Color(1, 1, 1, 0.8)
	var holder := Control.new()  # o preview fica centrado no cursor
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"slot": self}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var from := _slot_of(data)
	return from != null and ItemTransfer.can_swap(from.container, from.key, container, key)


func _drop_data(_at: Vector2, data: Variant) -> void:
	var from := _slot_of(data)
	ItemTransfer.swap(from.container, from.key, container, key)


func _slot_of(data: Variant) -> ItemSlot:
	return data.get("slot") as ItemSlot if data is Dictionary else null
