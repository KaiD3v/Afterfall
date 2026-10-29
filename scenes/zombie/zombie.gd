# Zumbi básico: parado até ver o jogador ou ouvir um ruído; persegue quem vê e ataca de perto.
# ponytail: anda em linha reta até o alvo, sem pathfinding; obstáculo só é contornado deslizando.
# Se travar demais no playtest, trocar por NavigationAgent2D com navegação no TileSet.
extends CharacterBody2D

enum State { IDLE, INVESTIGATE, CHASE }

@export var max_health := 60.0
@export var walk_speed := 35.0         # investigando um ruído
@export var chase_speed := 60.0        # perseguindo; o jogador anda a 80
@export var sight_range := 140.0
@export var sight_half_angle := 45.0   # graus; cone de 90° à frente
@export var feel_range := 24.0         # percebe quem encosta, mesmo de costas
@export var attack_range := 20.0
@export var attack_damage := 15.0
@export var attack_cooldown := 1.0
@export var facing := Vector2.DOWN

var health := 0.0
var state := State.IDLE
var target_pos := Vector2.ZERO
var player: Node2D
var _attack_wait := 0.0
var _action := ""         # attack, hurt ou death tocando; trava o andar
var _hit_pending := false # mordida esperando o frame de contato

const ATTACK_CONTACT_FRAME := 2  # attack_*: 0 preparo, 1 avanço, 2 contato, 3 recuperação

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var groan: AudioStreamPlayer2D = $Groan


func _ready() -> void:
	health = max_health
	add_to_group("zombies")
	player = get_tree().get_first_node_in_group("player")
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	_update_frame()


func _physics_process(delta: float) -> void:
	_attack_wait -= delta
	if player and not player.is_dead() and sees(player.global_position):
		if state != State.CHASE:
			groan.play()
		state = State.CHASE
		target_pos = player.global_position

	velocity = Vector2.ZERO
	if _action != "":
		pass  # atacando ou tomando o tranco: parado
	elif state != State.IDLE:
		var to := target_pos - global_position
		var near_player := state == State.CHASE and player.global_position.distance_to(global_position) <= attack_range
		if near_player:
			facing = to.normalized()
			if _attack_wait <= 0.0:
				_attack_wait = attack_cooldown
				if _play_action("attack"):
					_hit_pending = true  # dá para fugir no preparo
				else:
					player.take_damage(attack_damage)
		elif to.length() < 4.0:
			state = State.IDLE  # chegou ao ruído ou à última posição vista e não achou ninguém
		else:
			facing = to.normalized()
			velocity = facing * (chase_speed if state == State.CHASE else walk_speed)
	move_and_slide()
	_update_frame()


func sees(point: Vector2) -> bool:
	var to := point - global_position
	var dist := to.length()
	if dist > sight_range:
		return false
	if dist > feel_range and absf(rad_to_deg(facing.angle_to(to))) > sight_half_angle:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, point, 1)  # só paredes bloqueiam a visão
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


# Chamado por tiros e golpes (call_group "zombies").
func hear(pos: Vector2, radius: float) -> void:
	if state != State.CHASE and global_position.distance_to(pos) <= radius:
		state = State.INVESTIGATE
		target_pos = pos


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	sprite.modulate = Color(1.6, 0.6, 0.6)
	get_tree().create_timer(0.1).timeout.connect(func(): sprite.modulate = Color.WHITE)
	_hit_pending = false  # apanhar interrompe a mordida
	if health > 0.0:
		state = State.CHASE  # quem apanha vira para quem bateu
		target_pos = player.global_position
		_play_action("hurt")
		return
	remove_from_group("zombies")
	RunState.kills += 1
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	if not _play_action("death"):
		_fade_out()


func _fade_out() -> void:
	create_tween().tween_property(sprite, "modulate:a", 0.0, 0.4).finished.connect(queue_free)


func _play_action(action: String) -> bool:
	if not Facing.play_action(sprite, action, facing):
		return false
	_action = action
	return true


func _on_frame_changed() -> void:
	if _hit_pending and _action == "attack" and sprite.frame == ATTACK_CONTACT_FRAME:
		_hit_pending = false
		# só acerta se o jogador ainda está perto: recuar no preparo esquiva
		if player.global_position.distance_to(global_position) <= attack_range + 4.0:
			player.take_damage(attack_damage)


func _on_animation_finished() -> void:
	if _action == "death":
		_fade_out()  # corpo some depois de cair
		return
	_action = ""


func _update_frame() -> void:
	if _action != "":
		return
	# ciclo de andar no ritmo da perseguição; investigando, mais lento, para o pé não deslizar
	sprite.speed_scale = velocity.length() / chase_speed if velocity != Vector2.ZERO else 1.0
	Facing.play(sprite, "walk" if velocity != Vector2.ZERO else "idle", facing)
