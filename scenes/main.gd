# Cena principal: o local atual (bairro com seus zumbis), jogador e HUD. Uma porta com destino
# empilha o local atual fora da árvore (congelado, sem ouvir nada) e põe o novo; sair desempilha.
# Morte: tela de resultado; E começa uma nova run recarregando a cena do zero.
# Sono (cama da casa): a tela escurece, o relógio avança 8 h e o jogador acorda descansado.
# Noite: o bairro escurece aos poucos (18:00 a 21:00) e clareia (05:00 a 08:00), pela cor da sua
# camada AtmosphereModulate; o interior tem as luzes dele e não muda.
# Ambiente: cada local tem o seu loop; todos tocam o tempo todo e a troca só mexe no volume.
extends Node2D

const FADE_TIME := 0.25
const RESTART_DELAY := 1.0  # evita pular o resultado com um E apertado no susto
const AMBIENCE_FADE := FADE_TIME * 2  # a troca dura o escurecer e o clarear da porta
const SLEEP_FADE := 0.6
const NIGHT_TINT := Color(0.16, 0.19, 0.30)  # cor do bairro na noite fechada

var _stack: Array[Dictionary] = []  # locais de onde se entrou: {location, back}
var _busy := false
var _dead_for := -1.0  # segundos desde a morte; -1 = vivo
var _hood_tint: CanvasModulate  # camada de cor do bairro
var _day_tint: Color

@onready var player: Player = $Player
@onready var location: Location = $Neighborhood
@onready var fade: ColorRect = $Fade/Rect


func _ready() -> void:
	add_to_group(Groups.MAIN)
	player.died.connect(_on_player_died)
	_arrive(location)
	_ambience(location.ambience, 0.0)
	_hood_tint = location.get_node_or_null(^"AtmosphereModulate")
	if _hood_tint:
		_day_tint = _hood_tint.color
		RunState.stats.minute_changed.connect(_on_clock)
		_on_clock()


func _process(delta: float) -> void:
	if _dead_for < 0.0:
		RunState.stats.time += delta
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
	if player.action == "death":  # a tela de resultado espera o corpo cair
		await player.sprite.animation_finished
	_dead_for = 0.0  # o atraso do recomeço conta da tela de resultado
	$HUD.show_result()


# Dorme SLEEP_HOURS (Needs) se puder; se não, o aviso diz o motivo. Cruzar 00:00 dormindo conta o dia.
func sleep() -> bool:
	var why := player.needs.why_not_sleep()
	if why != "":
		RunState.notify(why)
		return false
	if _busy:
		return false
	_busy = true
	player.set_physics_process(false)
	await create_tween().tween_property(fade, "color:a", 1.0, SLEEP_FADE).finished
	player.needs.sleep()
	RunState.stats.time += Needs.SLEEP_HOURS * Needs.HOUR
	await create_tween().tween_property(fade, "color:a", 0.0, SLEEP_FADE).finished
	player.set_physics_process(true)
	_busy = false
	RunState.notify("Dormiu %d h" % Needs.SLEEP_HOURS)
	return true


func _on_clock() -> void:
	_hood_tint.color = _day_tint.lerp(NIGHT_TINT, darkness(RunState.stats.minute()))


# Quanto a noite escurece o bairro (0 dia, 1 noite fechada), pelo minuto do dia.
static func darkness(minute_of_day: int) -> float:
	var h := minute_of_day / 60.0
	if h < 5.0 or h >= 21.0:
		return 1.0
	if h < 8.0:
		return (8.0 - h) / 3.0
	return 0.0 if h < 18.0 else (h - 18.0) / 3.0


# Dentro de algum local que não é o primeiro (a casa).
func is_inside() -> bool:
	return not _stack.is_empty()


# Entra no local da cena scene_path; ao sair, o jogador volta em back.
func enter(scene_path: String, back: Vector2) -> void:
	if _busy:
		return
	var next: Location = load(scene_path).instantiate()
	_ambience(next.ambience)
	await _transition(func():
		_stack.push_back({location = location, back = back})
		remove_child(location)
		_show(next)
		player.position = next.get_node("PlayerSpawn").position)


func leave() -> void:
	if _busy or _stack.is_empty():
		return
	var prev: Dictionary = _stack.pop_back()
	_ambience(prev.location.ambience)
	await _transition(func():
		location.free()
		_show(prev.location)
		player.position = prev.back)


func _show(next: Location) -> void:
	add_child(next)
	move_child(next, 0)
	_arrive(next)


func _arrive(next: Location) -> void:
	location = next
	player.surface = next.surface
	player.needs.sheltered = is_inside()
	var cam: Camera2D = player.get_node("Camera2D")
	var rect := next.bounds()
	cam.limit_left = rect.position.x
	cam.limit_top = rect.position.y
	cam.limit_right = rect.end.x
	cam.limit_bottom = rect.end.y
	cam.reset_smoothing()


func _transition(swap: Callable) -> void:
	_busy = true
	player.set_physics_process(false)
	$SfxDoor.play()
	await create_tween().tween_property(fade, "color:a", 1.0, FADE_TIME).finished
	swap.call()
	await create_tween().tween_property(fade, "color:a", 0.0, FADE_TIME).finished
	player.set_physics_process(true)
	_busy = false


# Crossfade em volume linear (em dB a troca soaria com um buraco no meio). Cada stream ganha um
# player na primeira vez e segue tocando em silêncio quando o local muda.
func _ambience(stream: AudioStream, time := AMBIENCE_FADE) -> void:
	var t := create_tween().set_parallel()
	t.tween_interval(0.0)  # tween vazio dá erro quando não há ambiente
	for p: AudioStreamPlayer in $Ambience.get_children():
		t.tween_property(p, "volume_linear", 1.0 if p.stream == stream else 0.0, time)
	if stream and not $Ambience.get_children().any(func(p): return p.stream == stream):
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = &"Ambience"
		p.volume_linear = 0.0
		$Ambience.add_child(p)
		p.play()
		t.tween_property(p, "volume_linear", 1.0, time)


# Player de ambiente que toca stream (para teste e depuração).
func ambience_player(stream: AudioStream) -> AudioStreamPlayer:
	for p: AudioStreamPlayer in $Ambience.get_children():
		if p.stream == stream:
			return p
	return null
