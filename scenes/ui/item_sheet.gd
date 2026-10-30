# Ficha curta do item ao lado do slot sob o mouse: nome, tipo e números (ItemData.stats).
# Com compare_to (o item equipado no mesmo slot), cada número mostra a diferença: verde se o
# item da ficha é melhor, ferrugem se é pior. Painel e textos são elementos simples por código.
class_name ItemSheet
extends Control

const MIN_WIDTH := 70  # a ficha cresce até o texto mais largo
const VALUE_X := 56  # coluna dos valores (cabe "Proteção")
const PAD := 5
const LINE := 10
const GAP := 4  # distância do slot
const BG := Color8(20, 24, 32)          # shadow_outline
const BORDER := Color8(227, 168, 69)    # amber_light_glow
const TITLE := Color8(227, 168, 69)
const TEXT := Color8(168, 174, 179)     # concrete_highlight
const DIM := Color8(95, 104, 115)       # concrete_mid
const BETTER := Color8(128, 138, 96)    # foliage_dry
const WORSE := Color8(184, 118, 68)     # rust_highlight

var item: ItemData
var compare_to: ItemData


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


# Mostra a ficha de it ao lado de slot_rect (coordenadas da tela), dentro de bounds.
func show_for(it: ItemData, other: ItemData, slot_rect: Rect2, bounds: Rect2) -> void:
	item = it
	compare_to = other if other != it else null
	for c in get_children():
		c.queue_free()
	var y := 1  # a fonte já tem respiro em cima
	y = _line(it.display_name, y, TITLE)
	y = _line(it.type_name() + (" · vs. equipado" if compare_to else ""), y, DIM)
	var theirs := {}
	if compare_to:
		for s in compare_to.stats():
			theirs[s.label] = s
	for s in it.stats():
		y = _stat(s, theirs.get(s.label), y)
	var w := MIN_WIDTH
	for c in get_children():
		if not c.is_queued_for_deletion():
			w = maxi(w, int(c.position.x + c.get_minimum_size().x) + PAD)
	for c in get_children():  # diferenças da comparação encostam na borda direita
		if c.has_meta("diff"):
			c.position.x = w - PAD - c.get_minimum_size().x
	size = Vector2(w, y + 4)  # a última linha precisa de respiro embaixo
	# à direita do slot; sem espaço, à esquerda; sempre dentro dos limites
	var at := Vector2(slot_rect.end.x + GAP, slot_rect.position.y)
	if at.x + size.x > bounds.end.x:
		at.x = slot_rect.position.x - GAP - size.x
	at.y = clampf(at.y, bounds.position.y, bounds.end.y - size.y)
	position = at.round()
	queue_redraw()
	show()


func _line(text: String, y: int, color: Color) -> int:
	var l := Label.new()
	l.text = text
	l.position = Vector2(PAD, y)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return y + LINE


# "Dano 25", com "+15" ou "-15" ao lado na cor de melhor ou pior.
func _stat(s: Dictionary, other, y: int) -> int:
	_label(s.label, Vector2(PAD, y), DIM)
	_label(s.text, Vector2(VALUE_X, y), TEXT)
	if other != null and s.value != other.value:
		var diff: float = s.value - other.value
		var better: bool = (diff > 0) == s.higher_is_better
		var d := _label(("+" if diff > 0 else "-") + ItemData.num(absf(diff)), Vector2(VALUE_X + 70, y), BETTER if better else WORSE)
		d.set_meta("diff", true)
	return y + LINE


func _label(text: String, at: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BG)
	draw_rect(r, BORDER, false, 1.0)
