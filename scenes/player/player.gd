# Protagonista: movimento em 4 direções, corrida com stamina, vida, machete e pistola.
# Valores iniciais; ajustar no playtest.
extends Actor

@export var walk_speed := 80.0     # px/s = 2,5 tiles/s
@export var aim_walk_speed := 50.0 # px/s andando enquanto mira
@export var run_speed := 130.0
@export var run_cost := 25.0       # stamina por segundo correndo (4 s de fôlego cheio); o resto no nó Stamina
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
@export var pistol_move_spread := 9.0   # graus para cada lado andando enquanto mira
@export var pistol_cooldown := 0.25
@export var shot_noise := 320.0         # raio de ruído do tiro (10 tiles)
@export var mag_size := 12
@export var reload_time := 1.5
@export var reserve := 24               # munição fora do pente; o loot soma a ela

const STEP_FRAMES := [0, 2]     # walk_*: frames de contato do pé com o chão
const STEPS := {&"street": preload("res://assets/audio/steps_street.tres"), &"wood": preload("res://assets/audio/steps_wood.tres")}

var ammo := mag_size
var reloading := false
var aiming := false
var flashlight_on := true
var _moving := false
var focus: Node2D        # interagível mais próximo ao alcance; a HUD mostra o aviso de E
var surface := &"street"  # piso dos passos; main.gd troca para wood dentro da casa
var _running := false
var steps_taken := 0  # para teste e, depois, para o ruído dos passos
var _weapon_wait := 0.0

@onready var stamina: Stamina = $Stamina
@onready var tracer: Line2D = $Tracer


func _ready() -> void:
	super()
	ammo = mag_size  # exports chegam depois dos inicializadores
	_setup_tracer_style()


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	_weapon_wait -= delta
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
		use_bandage()
	if Input.is_action_just_pressed("flashlight"):
		toggle_flashlight()
	_update_anim()
	_update_flashlight(delta)
	_update_focus()


# Usa o interagível mais próximo (porta, container) dentro do alcance.
func interact() -> bool:
	var best := _nearest_interactable()
	if best:
		best.interact(self)
	return best != null


func _nearest_interactable() -> Node2D:
	var best: Node2D = null
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
	if is_instance_valid(focus):  # some na troca bairro ↔ interior
		focus.set_focus(false)
	focus = best
	if focus:
		focus.set_focus(true)


func use_bandage() -> bool:
	if is_dead() or health.is_full() or not RunState.take_item(&"bandage"):
		return false
	health.heal(bandage_heal)
	return true


# Com animação melee_* na sheet, o dano sai no frame de contato; sem ela, na hora.
func melee() -> bool:
	if is_dead() or _weapon_wait > 0.0 or reloading or not stamina.spend(machete_cost):
		return false
	_weapon_wait = machete_cooldown
	$SfxMachete.play()
	Noises.emit(self, melee_noise)
	if not play_action("melee", true):
		_melee_hit()
	return true


# ponytail: acerto por distância e ângulo no frame de contato, sem Area2D; basta para 3–5 zumbis.
func _melee_hit() -> void:
	for z in get_tree().get_nodes_in_group(Groups.ZOMBIES):
		var to: Vector2 = z.global_position - global_position
		if to.length() <= machete_range and absf(rad_to_deg(facing.angle_to(to))) <= machete_half_angle:
			z.health.damage(machete_damage, self)


func _on_contact() -> void:
	_melee_hit()


func _on_frame_changed() -> void:
	super()
	var anim := String(sprite.animation)
	if (anim.begins_with("walk") or anim.begins_with("aim_walk")) and sprite.frame in STEP_FRAMES:
		$SfxSteps.stream = STEPS[surface]
		$SfxSteps.play()
		steps_taken += 1


# Dispersão atual da pistola em graus: aumenta ao andar mirando.
func current_spread() -> float:
	if not _moving or pistol_spread == 0.0:
		return pistol_spread
	return maxf(pistol_spread, pistol_move_spread)


func shoot(dir: Vector2) -> bool:
	if is_dead() or _weapon_wait > 0.0 or reloading or ammo == 0:
		return false
	ammo -= 1
	_weapon_wait = pistol_cooldown
	var muzzle := muzzle_position()
	var spread := current_spread()
	var aim := dir.normalized().rotated(deg_to_rad(randf_range(-spread, spread)))
	var travel_dist := pistol_range
	var hit_collider: Object = null
	# Testa colisão tanto no plano dos pés quanto na projeção do cano da arma (paredes e zumbis)
	for ray_origin: Vector2 in [global_position, muzzle + Vector2(0.0, 24.0), muzzle]:
		var ray := PhysicsRayQueryParameters2D.create(ray_origin, ray_origin + aim * pistol_range, Layers.WORLD | Layers.ZOMBIES)
		ray.exclude = [get_rid()]
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if hit:
			var d: float = ray_origin.distance_to(hit.position)
			if d < travel_dist:
				travel_dist = d
				hit_collider = hit.collider
	var target := Health.of(hit_collider)
	if target:
		target.damage(pistol_damage, self)
	var end := muzzle + aim * travel_dist
	tracer.points = PackedVector2Array([muzzle, end])
	tracer.show()
	_animate_ballistic_shot(muzzle, end, aim, hit_collider)
	$SfxShot.play()
	play_action("shoot")
	Noises.emit(self, shot_noise)
	return true


func reload() -> void:
	if is_dead() or reloading or ammo == mag_size or reserve == 0:
		return
	reloading = true
	$SfxReload.play()
	if play_action("reload") and reload_time > 0.0:
		sprite.speed_scale = 1.5 / reload_time
	await get_tree().create_timer(reload_time).timeout
	reloading = false
	if action == "reload":
		action = ""
	if is_dead():
		return
	var n := mini(mag_size - ammo, reserve)
	ammo += n
	reserve -= n


func _on_died() -> void:
	velocity = Vector2.ZERO
	super()


# Boca do cano no mundo, a partir do ponto que o Codex marcou no frame de mira de cada direção.
func muzzle_position() -> Vector2:
	var frames := sprite.sprite_frames
	if not frames.has_meta("muzzle"):
		return global_position + Vector2(0, -10)
	var dir := Facing.dir_name(facing)
	var mirrored := dir == "left"
	var p: Array = frames.get_meta("muzzle")["right" if mirrored else dir]
	var local: Vector2 = Vector2(p[0], p[1]) - frames.get_meta("muzzle_frame") / 2.0 + sprite.offset
	if mirrored:
		local.x = -local.x
	return global_position + local


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


# Liga ou desliga a lanterna tática (tecla T).
func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	if has_node("Flashlight"):
		$Flashlight.enabled = flashlight_on
		$Flashlight.visible = flashlight_on


# Posiciona a lanterna no trilho da pistola ao mirar ou no colete tático ao caminhar.
func _update_flashlight(delta: float) -> void:
	if not has_node("Flashlight"):
		return
	var fl: PointLight2D = $Flashlight
	fl.enabled = flashlight_on
	fl.visible = flashlight_on
	if not flashlight_on:
		return
	var dir_name := Facing.dir_name(facing)
	var target_pos: Vector2
	var target_ang := facing.angle()
	var target_energy := 1.08
	if reloading or action == "reload":
		target_pos = Vector2(-7.0 if dir_name == "left" else 7.0, -21.0)
		target_ang += 0.22 if dir_name != "left" else -0.22
		target_energy = 0.80
	elif aiming or action == "shoot":
		var m := muzzle_position()
		target_pos = m - global_position + Vector2(0.0, 0.5)
		if m.distance_squared_to(get_global_mouse_position()) > 4.0:
			target_ang = m.direction_to(get_global_mouse_position()).angle()
		target_energy = 1.15
	else:
		match dir_name:
			"left":
				target_pos = Vector2(-5.5, -20.0)
			"right":
				target_pos = Vector2(5.5, -20.0)
			"up":
				target_pos = Vector2(3.5, -22.0)
			_:
				target_pos = Vector2(3.5, -19.0)
	var pos_rate := minf(1.0, (28.0 if aiming else 18.0) * delta)
	var ang_rate := minf(1.0, (28.0 if aiming else 14.0) * delta)
	fl.position = fl.position.lerp(target_pos, pos_rate)
	fl.rotation = lerp_angle(fl.rotation, target_ang, ang_rate)
	fl.energy = lerpf(fl.energy, target_energy, minf(1.0, 12.0 * delta))
	if fl.has_node("Lens"):
		fl.get_node("Lens").visible = not (dir_name == "up" and not aiming)


func _setup_tracer_style() -> void:
	tracer.width = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.7, 0.65))
	curve.add_point(Vector2(1.0, 1.0))
	tracer.width_curve = curve
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.55, 0.58, 0.62, 0.0),
		Color8(227, 154, 59, 210),
		Color8(248, 236, 200, 255),
	])
	tracer.gradient = grad


# Anima o projétil 9 mm em alta velocidade, clarão no cano, cápsula ejetada e impacto no alvo.
func _animate_ballistic_shot(muzzle: Vector2, end: Vector2, aim: Vector2, hit_collider: Object) -> void:
	var scene_root := get_parent()
	if scene_root == null:
		get_tree().create_timer(0.05).timeout.connect(tracer.hide)
		return

	# 1. Clarão rápido na boca do cano (luz dinâmica + faísca pixelada)
	var flash := Node2D.new()
	flash.global_position = muzzle
	flash.rotation = aim.angle()
	var spark_outer := Polygon2D.new()
	spark_outer.color = Color8(227, 154, 59, 230)
	spark_outer.polygon = PackedVector2Array([Vector2(-1, -2.5), Vector2(5.5, 0), Vector2(-1, 2.5), Vector2(1.5, 0)])
	flash.add_child(spark_outer)
	var spark_core := Polygon2D.new()
	spark_core.color = Color8(248, 236, 200, 255)
	spark_core.polygon = PackedVector2Array([Vector2(0, -1.2), Vector2(3.5, 0), Vector2(0, 1.2)])
	flash.add_child(spark_core)
	if has_node("AmbientLight"):
		var m_light := PointLight2D.new()
		m_light.texture = $AmbientLight.texture
		m_light.color = Color8(235, 168, 72)
		m_light.energy = 1.25
		m_light.texture_scale = 0.28
		flash.add_child(m_light)
	scene_root.add_child(flash)
	get_tree().create_timer(0.045).timeout.connect(flash.queue_free)

	# 2. Cápsula de latão 9 mm ejetada lateralmente
	var casing := Node2D.new()
	casing.global_position = muzzle - aim * 2.5
	var c_border := Polygon2D.new()
	c_border.color = Color8(20, 24, 32)
	c_border.polygon = PackedVector2Array([Vector2(-1.6, -1.1), Vector2(1.6, -1.1), Vector2(1.6, 1.1), Vector2(-1.6, 1.1)])
	casing.add_child(c_border)
	var c_brass := Polygon2D.new()
	c_brass.color = Color8(212, 163, 73)
	c_brass.polygon = PackedVector2Array([Vector2(-1.0, -0.6), Vector2(1.0, -0.6), Vector2(1.0, 0.6), Vector2(-1.0, 0.6)])
	casing.add_child(c_brass)
	scene_root.add_child(casing)
	var eject_side := -1.0 if aim.x < 0.0 else 1.0
	var eject_dir := (aim.rotated(-1.35 * eject_side) + Vector2(0.0, -0.5)).normalized()
	var land_pos := casing.global_position + eject_dir * randf_range(8.0, 13.0) + Vector2(0.0, randf_range(16.0, 21.0))
	var tw_c := casing.create_tween()
	tw_c.tween_property(casing, "global_position", land_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_c.parallel().tween_property(casing, "rotation", randf_range(-5.0, 5.0), 0.22)
	tw_c.tween_interval(0.55)
	tw_c.tween_property(casing, "modulate:a", 0.0, 0.25)
	tw_c.tween_callback(casing.queue_free)

	# 3. Projétil 9 mm em deslocamento balístico rápido + rastro curto
	var bullet := Node2D.new()
	bullet.global_position = muzzle
	bullet.rotation = aim.angle()
	var b_outline := Polygon2D.new()
	b_outline.color = Color8(20, 24, 32)
	b_outline.polygon = PackedVector2Array([Vector2(-2.5, -1.3), Vector2(2.5, -1.0), Vector2(3.4, 0.0), Vector2(2.5, 1.0), Vector2(-2.5, 1.3)])
	bullet.add_child(b_outline)
	var b_core := Polygon2D.new()
	b_core.color = Color8(248, 236, 200)
	b_core.polygon = PackedVector2Array([Vector2(-1.8, -0.7), Vector2(2.2, -0.5), Vector2(2.8, 0.0), Vector2(2.2, 0.5), Vector2(-1.8, 0.7)])
	bullet.add_child(b_core)
	scene_root.add_child(bullet)

	var total_dist := muzzle.distance_to(end)
	var flight_time := clampf(total_dist / 1800.0, 0.035, 0.085)
	var wake_len := minf(34.0, total_dist)
	var is_zombie_hit := Health.of(hit_collider) != null
	var had_hit := hit_collider != null
	var tw_b := create_tween()
	tw_b.tween_method(func(p: float) -> void:
		var head := muzzle.lerp(end, p)
		var tail_d := maxf(0.0, p * total_dist - wake_len)
		var tail := muzzle + aim * tail_d
		if is_instance_valid(bullet):
			bullet.global_position = head
		tracer.points = PackedVector2Array([tail, head])
	, 0.0, 1.0, flight_time)
	tw_b.tween_callback(func() -> void:
		tracer.hide()
		if is_instance_valid(bullet):
			bullet.queue_free()
		if had_hit and is_instance_valid(scene_root):
			_spawn_impact_fx(scene_root, end, aim, is_zombie_hit)
	)


func _spawn_impact_fx(scene_root: Node, pos: Vector2, aim: Vector2, is_blood: bool) -> void:
	var count := 4 if is_blood else 3
	for i in count:
		var p := Polygon2D.new()
		p.global_position = pos
		if is_blood:
			p.color = Color8(138, 38, 38) if i % 2 == 0 else Color8(92, 24, 24)
			p.polygon = PackedVector2Array([Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(1.2, 1.2), Vector2(-1.2, 1.2)])
		else:
			p.color = Color8(227, 154, 59) if i == 0 else Color8(168, 174, 179)
			p.polygon = PackedVector2Array([Vector2(-1.0, -0.8), Vector2(1.0, -0.8), Vector2(1.0, 0.8), Vector2(-1.0, 0.8)])
		scene_root.add_child(p)
		var base_dir := aim if is_blood else -aim
		var dir := base_dir.rotated(randf_range(-0.65, 0.65))
		var target := pos + dir * randf_range(5.0, 14.0) + (Vector2(0.0, randf_range(3.0, 8.0)) if is_blood else Vector2.ZERO)
		var tw := p.create_tween()
		tw.tween_property(p, "global_position", target, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.16)
		tw.tween_callback(p.queue_free)
