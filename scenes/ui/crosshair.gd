# Mira no lugar do cursor, desenhada na resolução do jogo (480×270), presa à grade.
# Sem mirar: um ponto. Mirando: 4 traços que abrem com a distância, mostrando a dispersão
# da pistola (o erro lateral cresce com a distância). A cor avisa fora do alcance e sem munição.
extends Node2D

const TICK := 3        # comprimento de cada traço, em px
const MIN_GAP := 2.0   # abertura mínima, para a mira não fechar em cima do alvo
const OUTLINE := Color8(20, 24, 32)
const NORMAL := Color8(168, 174, 179)
const FAR := Color8(68, 76, 87)       # além do alcance da pistola
const EMPTY := Color8(227, 168, 69)   # pente vazio ou recarregando

@export var player: Node


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(_delta: float) -> void:
	position = get_viewport().get_mouse_position().floor()
	queue_redraw()


# Raio em px da dispersão a uma distância: o tiro cai dentro da dispersão atual da arma.
func gap_at(distance: float) -> float:
	return maxf(MIN_GAP, roundf(distance * tan(deg_to_rad(player.firearm.spread_now()))))


func _aim_origin() -> Vector2:
	return player.muzzle_position()


func color_now() -> Color:
	var gun: Firearm = player.firearm
	if gun.reloading or gun.ammo == 0:
		return EMPTY
	if _aim_origin().distance_to(player.get_global_mouse_position()) > gun.gun().max_range:
		return FAR
	return NORMAL


func _draw() -> void:
	if player.is_dead():
		return
	if not player.aiming:
		_pixel_rect(Rect2i(0, 0, 1, 1), NORMAL)
		return
	var g := int(gap_at(_aim_origin().distance_to(player.get_global_mouse_position())))
	var c := color_now()
	for r in [Rect2i(-g - TICK, 0, TICK, 1), Rect2i(g + 1, 0, TICK, 1), Rect2i(0, -g - TICK, 1, TICK), Rect2i(0, g + 1, 1, TICK)]:
		_pixel_rect(r, c)


# Retângulo cheio com contorno de 1 px, para a mira ler sobre qualquer chão.
func _pixel_rect(r: Rect2i, c: Color) -> void:
	draw_rect(Rect2(r.grow(1)), OUTLINE)
	draw_rect(Rect2(r), c)
