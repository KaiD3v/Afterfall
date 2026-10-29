# Cena principal: bairro, jogador, zumbis e HUD. Entrar na casa tira o bairro e os zumbis
# da árvore (ficam congelados, sem ouvir nada) e põe o interior; sair faz o inverso.
# Morte: tela de resultado; E começa uma nova run recarregando a cena do zero.
extends Node2D

const INTERIOR := preload("res://scenes/world/house_interior.tscn")
const FADE_TIME := 0.25
const RESTART_DELAY := 1.0  # evita pular o resultado com um E apertado no susto

var interior: Node2D
var _busy := false
var _dead_for := -1.0  # segundos desde a morte; -1 = vivo

@onready var player: CharacterBody2D = $Player
@onready var outside: Array[Node] = [$Neighborhood, $Zombies]
@onready var fade: ColorRect = $Fade/Rect


func _ready() -> void:
	add_to_group("main")
	player.died.connect(_on_player_died)
	_fit_camera($Neighborhood)


func _process(delta: float) -> void:
	if _dead_for < 0.0:
		RunState.run_time += delta
		return
	_dead_for += delta
	if _dead_for >= RESTART_DELAY and Input.is_action_just_pressed("interact"):
		new_run()


# Zera o RunState (inventário, loot sorteado, números) e recarrega a cena: jogador, zumbis
# e casa voltam ao estado inicial. Os containers sorteiam de novo na primeira abertura.
func new_run() -> void:
	RunState.new_run()
	get_tree().reload_current_scene()


func _on_player_died() -> void:
	RunState.deaths += 1
	_dead_for = 0.0
	$HUD.show_result()


func enter_house() -> void:
	if interior or _busy:
		return
	await _transition(func():
		for n in outside:
			remove_child(n)
		interior = INTERIOR.instantiate()
		add_child(interior)
		move_child(interior, 0)
		player.position = interior.get_node("PlayerSpawn").position
		_fit_camera(interior))


func exit_house() -> void:
	if not interior or _busy:
		return
	await _transition(func():
		interior.free()
		interior = null
		for i in outside.size():
			add_child(outside[i])
			move_child(outside[i], i)
		player.position = $Neighborhood/HouseExit.position
		_fit_camera($Neighborhood))


func _transition(swap: Callable) -> void:
	_busy = true
	player.set_physics_process(false)
	$SfxDoor.play()
	await create_tween().tween_property(fade, "color:a", 1.0, FADE_TIME).finished
	swap.call()
	await create_tween().tween_property(fade, "color:a", 0.0, FADE_TIME).finished
	player.set_physics_process(true)
	_busy = false


func _fit_camera(world: Node) -> void:
	var cam: Camera2D = player.get_node("Camera2D")
	var used: Rect2i = world.get_node("Ground").get_used_rect()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = used.end.x * 32
	cam.limit_bottom = used.end.y * 32
	cam.reset_smoothing()
