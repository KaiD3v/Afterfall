# Zumbi: parado até ver o jogador ou ouvir um ruído; persegue quem vê ou quem bateu e ataca de perto.
# Números e visual vêm de data (ZombieData). A IA roda em _perceive → estado (_idle, _investigate,
# _chase) → move_and_slide; uma variante de comportamento sobrescreve só o método que muda.
# ponytail: anda em linha reta até o alvo, sem pathfinding; obstáculo só é contornado deslizando.
# Se travar demais no playtest, trocar por NavigationAgent2D com navegação no TileSet.
extends Actor

enum State { IDLE, INVESTIGATE, CHASE }

@export var data: ZombieData

var state := State.IDLE
var target_pos := Vector2.ZERO
var target: Actor  # quem persegue: quem viu ou quem bateu
var player: Actor  # quem a visão procura
var _configured := false

@onready var groan: AudioStreamPlayer2D = $Groan
@onready var attack_weapon: MeleeWeapon = $Attack


# Antes do _ready dos filhos, para a vida e o ataque já nascerem com os números do tipo.
func _enter_tree() -> void:
	if _configured or data == null:
		return
	_configured = true
	$Health.maximum = data.max_health
	$Attack.data = data.attack
	if data.frames:
		$Sprite.sprite_frames = data.frames
	if data.groan:
		$Groan.stream = data.groan


func _ready() -> void:
	super()
	add_to_group(Groups.ZOMBIES)
	player = get_tree().get_first_node_in_group(Groups.PLAYER)
	_update_frame()


func _physics_process(_delta: float) -> void:
	_perceive()
	velocity = Vector2.ZERO
	if action == "":  # atacando ou tomando o tranco: parado
		match state:
			State.IDLE:
				_idle()
			State.INVESTIGATE:
				_investigate()
			State.CHASE:
				_chase()
	move_and_slide()
	_update_frame()


# Visão: ao ver o jogador, geme (se ainda não perseguia) e passa a persegui-lo.
func _perceive() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(Groups.PLAYER)
	if player and not player.is_dead() and sees(player.global_position):
		if state != State.CHASE:
			groan.play()
		_chase_target(player)


func _idle() -> void:
	pass  # parado, esperando ver ou ouvir algo


func _investigate() -> void:
	_walk_to(target_pos, data.walk_speed)


func _chase() -> void:
	if is_instance_valid(target) and target.global_position.distance_to(global_position) <= data.attack_range:
		facing = global_position.direction_to(target_pos)
		attack_weapon.attack()
	else:
		_walk_to(target_pos, data.chase_speed)


# Anda até o ponto; chegando sem achar ninguém, volta a ficar parado.
func _walk_to(point: Vector2, speed: float) -> void:
	var to := point - global_position
	if to.length() < 4.0:
		state = State.IDLE
	else:
		facing = to.normalized()
		velocity = facing * speed


func _chase_target(who: Actor) -> void:
	state = State.CHASE
	target = who
	target_pos = who.global_position


func sees(point: Vector2) -> bool:
	var to := point - global_position
	var dist := to.length()
	if dist > data.sight_range:
		return false
	if dist > data.feel_range and absf(rad_to_deg(facing.angle_to(to))) > data.sight_half_angle:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, point, Layers.WORLD)  # só paredes bloqueiam a visão
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


# Chamado pelos ruídos do mundo (Noises.emit).
func hear(pos: Vector2, radius: float) -> void:
	if state != State.CHASE and global_position.distance_to(pos) <= radius * data.hearing:
		state = State.INVESTIGATE
		target_pos = pos


func _on_damaged(amount: float, source: Node) -> void:
	super(amount, source)
	cancel_contact()  # apanhar interrompe o ataque
	if is_dead():
		return
	var hitter: Actor = source as Actor if source is Actor else player  # sem fonte (ambiente): o jogador
	if hitter:
		_chase_target(hitter)  # quem apanha vira para quem bateu
	play_action("hurt")


func _on_died() -> void:
	remove_from_group(Groups.ZOMBIES)
	RunState.kills += 1
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	if not play_action("death"):
		_fade_out()
	super()


func _fade_out() -> void:
	create_tween().tween_property(sprite, "modulate:a", 0.0, 0.4).finished.connect(queue_free)


func _on_animation_finished() -> void:
	if action == "death":
		_fade_out()  # corpo some depois de cair
		return
	super()


func _update_frame() -> void:
	if action != "":
		return
	# ciclo de andar no ritmo da perseguição; investigando, mais lento, para o pé não deslizar
	sprite.speed_scale = velocity.length() / data.chase_speed if velocity != Vector2.ZERO else 1.0
	Facing.play(sprite, "walk" if velocity != Vector2.ZERO else "idle", facing)
