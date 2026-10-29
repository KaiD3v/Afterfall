# Protagonista: movimento em 4 direções, corrida com stamina, vida, machete e pistola.
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
@export var interact_range := 32.0
@export var bandage_heal := 30.0

@export_group("Machete")
@export var machete_damage := 25.0      # zumbi tem 60: 3 golpes
@export var machete_cost := 20.0        # stamina por golpe
@export var machete_range := 30.0
@export var machete_half_angle := 60.0  # graus; arco de 120° à frente
@export var machete_cooldown := 0.5
@export var melee_noise := 64.0         # raio de ruído do golpe

@export_group("Pistola 9 mm")
@export var pistol_damage := 40.0       # 2 tiros por zumbi
@export var pistol_range := 320.0
@export var pistol_spread := 4.0        # graus para cada lado; o erro lateral cresce com a distância
@export var pistol_cooldown := 0.25
@export var shot_noise := 320.0         # raio de ruído do tiro (10 tiles)
@export var mag_size := 12
@export var reload_time := 1.5
@export var reserve := 24               # munição fora do pente; vem do loot a partir do M6

var health := max_health
var stamina := max_stamina
var exhausted := false
var ammo := mag_size
var reloading := false
var facing := Vector2.DOWN
var _regen_wait := 0.0
var _weapon_wait := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var tracer: Line2D = $Tracer


func _ready() -> void:
	# exports chegam depois dos inicializadores; lê os máximos já ajustados no inspetor
	health = max_health
	stamina = max_stamina
	ammo = mag_size
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	_weapon_wait -= delta
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

	# Mirando (botão direito), o clique atira; sem mirar, o clique golpeia com o machete.
	var aiming := Input.is_action_pressed("aim")
	if aiming:
		facing = global_position.direction_to(get_global_mouse_position())
	elif dir != Vector2.ZERO:
		facing = dir.normalized()
	if aiming and Input.is_action_just_pressed("shoot"):
		shoot(facing)
	elif not aiming and Input.is_action_just_pressed("attack"):
		melee()
	if Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_just_pressed("interact"):
		interact()
	if Input.is_action_just_pressed("heal"):
		use_bandage()
	_update_frame()


# Usa o interagível mais próximo (porta, container) dentro do alcance.
func interact() -> bool:
	var best: Node2D = null
	var best_dist := interact_range
	for n in get_tree().get_nodes_in_group("interactables"):
		var d := global_position.distance_to(n.global_position)
		if d <= best_dist:
			best = n
			best_dist = d
	if best:
		best.interact(self)
	return best != null


func use_bandage() -> bool:
	if is_dead() or health >= max_health or not RunState.take_item(&"bandage"):
		return false
	health = minf(health + bandage_heal, max_health)
	return true


# ponytail: acerto por distância e ângulo no instante do golpe, sem Area2D; trocar quando houver frames de ataque.
func melee() -> bool:
	if is_dead() or _weapon_wait > 0.0 or not spend_stamina(machete_cost):
		return false
	_weapon_wait = machete_cooldown
	$SfxMachete.play()
	for z in get_tree().get_nodes_in_group("zombies"):
		var to: Vector2 = z.global_position - global_position
		if to.length() <= machete_range and absf(rad_to_deg(facing.angle_to(to))) <= machete_half_angle:
			z.take_damage(machete_damage)
	_noise(melee_noise)
	return true


func shoot(dir: Vector2) -> bool:
	if is_dead() or _weapon_wait > 0.0 or reloading or ammo == 0:
		return false
	ammo -= 1
	_weapon_wait = pistol_cooldown
	var aim := dir.normalized().rotated(deg_to_rad(randf_range(-pistol_spread, pistol_spread)))
	var end := global_position + aim * pistol_range
	var ray := PhysicsRayQueryParameters2D.create(global_position, end, 1 | 4)  # paredes e zumbis
	ray.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if hit:
		end = hit.position
		if hit.collider.has_method("take_damage"):
			hit.collider.take_damage(pistol_damage)
	tracer.points = PackedVector2Array([global_position + Vector2(0, -10), end])
	tracer.show()
	get_tree().create_timer(0.05).timeout.connect(tracer.hide)
	$SfxShot.play()
	_noise(shot_noise)
	return true


func reload() -> void:
	if is_dead() or reloading or ammo == mag_size or reserve == 0:
		return
	reloading = true
	$SfxReload.play()
	await get_tree().create_timer(reload_time).timeout
	reloading = false
	if is_dead():
		return
	var n := mini(mag_size - ammo, reserve)
	ammo += n
	reserve -= n


# Custo fixo de uma ação. false = sem stamina, a ação não acontece.
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
	sprite.modulate = Color(1.6, 0.6, 0.6)
	get_tree().create_timer(0.1).timeout.connect(func(): sprite.modulate = Color.WHITE)
	if is_dead():
		velocity = Vector2.ZERO
		died.emit()


func is_dead() -> bool:
	return health <= 0.0


func _noise(radius: float) -> void:
	get_tree().call_group("zombies", "hear", global_position, radius)


func _drain(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_wait = regen_delay
	if stamina == 0.0:
		exhausted = true


func _update_frame() -> void:
	# frames do character.png: 0 baixo, 1 esquerda, 2 direita, 3 cima
	if absf(facing.x) >= absf(facing.y):
		sprite.frame = 1 if facing.x < 0 else 2
	else:
		sprite.frame = 3 if facing.y < 0 else 0
