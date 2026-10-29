# Protagonista: movimento em 4 direções, corrida com stamina, vida e morte.
# Valores iniciais; ajustar no playtest.
extends CharacterBody2D

signal died

@export var walk_speed := 80.0     # px/s = 2,5 tiles/s
@export var run_speed := 130.0
@export var max_health := 100.0
@export var max_stamina := 100.0
@export var run_cost := 25.0       # stamina por segundo correndo (4 s de fôlego cheio)
@export var stamina_regen := 15.0  # stamina por segundo parado ou andando
@export var regen_delay := 0.8     # segundos sem gastar antes de recuperar
@export var recover_at := 25.0     # sem fôlego: só volta a correr ou golpear acima disso

var health := max_health
var stamina := max_stamina
var exhausted := false
var _regen_wait := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# exports chegam depois dos inicializadores; lê os máximos já ajustados no inspetor
	health = max_health
	stamina = max_stamina

func _physics_process(delta: float) -> void:
	if is_dead():
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := dir != Vector2.ZERO and Input.is_action_pressed("sprint") and not exhausted
	if running:
		_drain(run_cost * delta)
	else:
		_regen_wait -= delta
		if _regen_wait <= 0.0:
			stamina = minf(stamina + stamina_regen * delta, max_stamina)
		if exhausted and stamina >= recover_at:
			exhausted = false
	velocity = dir * (run_speed if running else walk_speed)
	move_and_slide()
	if dir != Vector2.ZERO:
		# frames do character.png: 0 baixo, 1 esquerda, 2 direita, 3 cima
		if absf(dir.x) >= absf(dir.y):
			sprite.frame = 1 if dir.x < 0 else 2
		else:
			sprite.frame = 3 if dir.y < 0 else 0


# Custo fixo de uma ação (golpe de machete no M4). false = sem stamina, a ação não acontece.
func spend_stamina(cost: float) -> bool:
	if exhausted or stamina < cost:
		return false
	_drain(cost)
	return true


# Ponto único de dano para jogador e zumbis (plano, seção 4).
func take_damage(amount: float) -> void:
	if is_dead():
		return
	health = maxf(health - amount, 0.0)
	if is_dead():
		velocity = Vector2.ZERO
		died.emit()


func is_dead() -> bool:
	return health <= 0.0


func _drain(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_wait = regen_delay
	if stamina == 0.0:
		exhausted = true
