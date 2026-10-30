# Pictograma 7×7 da HUD, desenhado por código (elemento simples): vida, fôlego, fome, sede,
# frio e calor. Os de temperatura vêm num selo 11×11 com fundo, para ficar por cima do retrato.
@tool
extends Control

enum Kind { HEART, BOLT, FOOD, WATER, COLD, HOT }

const OUTLINE := Color8(20, 24, 32)
const BG := Color8(30, 36, 46)
const FLAME_CORE := Color8(227, 168, 69)

@export var kind := Kind.HEART:
	set(value):
		kind = value
		queue_redraw()
@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.HEART:
			_px([Rect2(0, 1, 3, 3), Rect2(4, 1, 3, 3), Rect2(1, 3, 5, 2), Rect2(2, 5, 3, 1), Rect2(3, 6, 1, 1)])
		Kind.BOLT:
			_px([Rect2(3, 0, 3, 1), Rect2(2, 1, 3, 2), Rect2(1, 3, 5, 1), Rect2(2, 4, 3, 1), Rect2(2, 5, 2, 1), Rect2(1, 6, 2, 1)])
		Kind.FOOD:
			_px([Rect2(1, 0, 1, 3), Rect2(3, 0, 1, 3), Rect2(5, 0, 1, 3), Rect2(1, 3, 5, 1), Rect2(3, 4, 1, 3)])
		Kind.WATER:
			_px([Rect2(3, 0, 1, 1), Rect2(2, 1, 3, 2), Rect2(1, 3, 5, 3), Rect2(2, 6, 3, 1)])
		Kind.COLD, Kind.HOT:
			draw_rect(Rect2(0, 0, 11, 11), OUTLINE)
			draw_rect(Rect2(1, 1, 9, 9), BG)
			if kind == Kind.COLD:  # floco
				_px([Rect2(5, 2, 1, 7), Rect2(2, 5, 7, 1), Rect2(3, 3, 1, 1), Rect2(7, 3, 1, 1), Rect2(3, 7, 1, 1), Rect2(7, 7, 1, 1)])
			else:  # chama
				_px([Rect2(5, 2, 1, 1), Rect2(4, 3, 3, 2), Rect2(3, 5, 5, 3)])
				draw_rect(Rect2(5, 6, 1, 2), FLAME_CORE)


func _px(rects: Array) -> void:
	for r: Rect2 in rects:
		draw_rect(r, color)
