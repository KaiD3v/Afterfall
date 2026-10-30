# Protagonista: lê o input e move; as armas (nós Machete e Pistol), a vida e o fôlego ficam nos
# componentes. Valores iniciais; ajustar no playtest.
class_name Player
extends Actor

signal focus_changed(target: Interactable)  # null = nada ao alcance

@export var walk_speed := 80.0     # px/s = 2,5 tiles/s
@export var aim_walk_speed := 50.0 # px/s andando enquanto mira
@export var run_speed := 130.0
@export var run_cost := 25.0       # stamina por segundo correndo (4 s de fôlego cheio); o resto no nó Stamina
@export var interact_range := 32.0
@export var heal_item: ItemData = preload("res://data/items/bandage.tres")  # tecla Q

const STEP_FRAMES := [0, 2]     # walk_*: frames de contato do pé com o chão
const STEPS := {&"street": preload("res://assets/audio/steps_street.tres"), &"wood": preload("res://assets/audio/steps_wood.tres")}

var aiming := false
var _moving := false
var focus: Interactable  # interagível mais próximo ao alcance; a HUD mostra o aviso de E
var surface := &"street"  # piso dos passos; main.gd põe o do local (Location.surface)
var _running := false
var steps_taken := 0  # para teste e, depois, para o ruído dos passos

@onready var melee_weapon: MeleeWeapon = $Machete
@onready var firearm: Firearm = $Pistol
@onready var flashlight: Flashlight = $Flashlight


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	# Mirando (botão direito), o clique atira; sem mirar, o clique golpeia com o machete.
	aiming = Input.is_action_pressed("aim")
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := dir != Vector2.ZERO and not aiming and Input.is_action_pressed("sprint") and not stamina.exhausted
	_running = running
	if running:
		stamina.drain(run_cost * delta)
	else:
		stamina.recover(delta)
	_moving = dir != Vector2.ZERO
	firearm.moving = _moving
	var speed := aim_walk_speed if aiming else (run_speed if running else walk_speed)
	velocity = dir * speed
	move_and_slide()

	if aiming:
		var aim_origin := global_position + Vector2(0.0, -24.0)
		if aim_origin.distance_squared_to(get_global_mouse_position()) > 1.0:
			facing = aim_origin.direction_to(get_global_mouse_position())
	elif dir != Vector2.ZERO:
		facing = dir.normalized()
	if aiming and Input.is_action_just_pressed("shoot"):
		var m := muzzle_position()
		var shot_dir := m.direction_to(get_global_mouse_position()) if m.distance_squared_to(get_global_mouse_position()) > 4.0 else facing
		shoot(shot_dir)
	elif not aiming and Input.is_action_just_pressed("attack"):
		melee()
	if Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_just_pressed("interact"):
		interact()
	if Input.is_action_just_pressed("heal"):
		use_item(heal_item)
	if Input.is_action_just_pressed("flashlight"):
		flashlight.toggle()
	_update_anim()
	_update_focus()


func melee() -> bool:
	return not is_dead() and not firearm.reloading and melee_weapon.attack()


func shoot(dir: Vector2) -> bool:
	return not is_dead() and firearm.fire(dir)


func reload() -> void:
	if not is_dead():
		firearm.reload()


# Usa o interagível mais próximo (porta, container) dentro do alcance.
func interact() -> bool:
	var best := _nearest_interactable()
	if best:
		best.interact(self)
	return best != null


func _nearest_interactable() -> Interactable:
	var best: Interactable = null
	var best_dist := interact_range
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLES):
		var d := global_position.distance_to(n.global_position)
		if d <= best_dist:
			best = n
			best_dist = d
	return best


func _update_focus() -> void:
	var best := _nearest_interactable()
	if best == focus:
		return
	if is_instance_valid(focus):  # some na troca de local
		focus.set_focus(false)
	focus = best
	if focus:
		focus.set_focus(true)
	focus_changed.emit(focus)


func use_item(item: ItemData) -> bool:
	return not is_dead() and RunState.inventory.use(item, self)


func _on_frame_changed() -> void:
	super()
	var anim := String(sprite.animation)
	if (anim.begins_with("walk") or anim.begins_with("aim_walk")) and sprite.frame in STEP_FRAMES:
		$SfxSteps.stream = STEPS[surface]
		$SfxSteps.play()
		steps_taken += 1


func _on_died() -> void:
	velocity = Vector2.ZERO
	super()


func _update_anim() -> void:
	if action != "":
		if action == "reload":
			var pick := Facing.resolve(sprite, "reload", facing)
			if pick[0] != &"":
				sprite.flip_h = pick[1]
				if sprite.animation != pick[0]:
					var f := sprite.frame
					var p := sprite.frame_progress
					sprite.play(pick[0])
					sprite.set_frame_and_progress(f, p)
		return
	if aiming and _moving:
		sprite.speed_scale = aim_walk_speed / walk_speed
		var pick := Facing.resolve(sprite, "aim_walk", facing)
		Facing.play(sprite, "aim_walk" if pick[0] != &"" else "aim", facing)
		return
	# correndo, o mesmo ciclo de andar fica mais rápido; os passos acompanham
	sprite.speed_scale = run_speed / walk_speed if _running else 1.0
	Facing.play(sprite, "aim" if aiming else ("walk" if _moving else "idle"), facing)
