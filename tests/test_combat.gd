# Checagem do M4: visão e audição do zumbi, machete, pistola, recarga e ataque do zumbi.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_combat.gd
extends SceneTree

const HZ := 60.0
var ZOMBIE: PackedScene  # load em _initialize: zombie.gd usa o autoload RunState
var player: CharacterBody2D
var failed := false


func _initialize() -> void:
	ZOMBIE = load("res://scenes/zombie/zombie.tscn")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	for z in main.get_node("Zombies").get_children():  # cada caso monta os próprios zumbis
		z.free()
	root.add_child(main)
	player = main.get_node("Player")
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	# Casos na rua principal (linhas 15–18, sem obstáculos entre x 700 e 860).
	player.position = Vector2(760, 592)

	# 1. Visão: vê de frente, não vê de costas a 80 px; percebe encostado.
	var z := await spawn(Vector2(840, 592), Vector2.LEFT)
	await frames(0.1)
	check("vê o jogador à frente", z.state == z.State.CHASE)
	z.queue_free()
	z = await spawn(Vector2(840, 592), Vector2.RIGHT)
	await frames(0.5)
	check("não vê de costas", z.state == z.State.IDLE)
	z.position = player.position + Vector2(18, 0)
	await frames(0.1)
	check("percebe quem encosta", z.state == z.State.CHASE)
	z.queue_free()

	# 2. Parede bloqueia a visão: zumbi atrás da casa (do outro lado da cerca/casa).
	player.position = Vector2(336, 410)  # terreno, logo abaixo da casa
	z = await spawn(Vector2(336, 280), Vector2.DOWN)  # 130 px, dentro do alcance; casa no meio
	await frames(0.2)
	check("casa bloqueia a visão", z.state == z.State.IDLE)
	z.position = Vector2(460, 405)  # mesmo terreno, ao lado, sem a casa no meio
	z.facing = z.global_position.direction_to(player.global_position)
	await frames(0.1)
	check("sem a casa no meio, vê", z.state == z.State.CHASE)
	z.queue_free()

	# 3. Som: tiro atrai zumbi de costas a 250 px; golpe não atrai a 100 px.
	player.position = Vector2(760, 592)
	z = await spawn(Vector2(860, 560), Vector2.RIGHT)
	player.melee()
	await frames(0.1)
	check("golpe não é ouvido a ~100 px", z.state == z.State.IDLE)
	z.position = Vector2(1010, 560)
	player._weapon_wait = 0.0
	player.shoot(Vector2.UP)
	await frames(0.1)
	check("tiro é ouvido a 250 px e o zumbi vai até o ruído", z.state == z.State.INVESTIGATE and z.target_pos == player.global_position)
	z.queue_free()
	await frames(1.0)

	# 4. Machete: 3 golpes matam; cada golpe custa stamina; sem fôlego não golpeia.
	player.stamina = player.max_stamina
	z = await spawn(player.position + Vector2(24, 0), Vector2.LEFT)
	player.facing = Vector2.RIGHT
	var hits := 0
	for i in 3:
		var s0: float = player.stamina
		if player.melee():
			hits += 1
		check("golpe %d custa 20 de stamina" % (i + 1), is_equal_approx(s0 - player.stamina, 20.0))
		await frames(0.55)
	check("3 golpes de machete matam", hits == 3 and dead(z))
	await frames(0.5)
	player.exhausted = true
	player._weapon_wait = 0.0
	check("sem fôlego o machete falha", not player.melee())
	player.exhausted = false

	# 5. Pistola: 2 tiros matam a 100 px; tiro alinhado ao cano; pente de 12; recarga usa a reserva.
	player.ammo = player.mag_size
	player.pistol_spread = 0.0
	player.facing = Vector2.RIGHT
	z = await spawn(player.position + Vector2(100, 0), Vector2.RIGHT)
	for i in 2:
		player._weapon_wait = 0.0
		player.shoot(Vector2.RIGHT)
		if i == 0:
			var pts: PackedVector2Array = player.get_node("Tracer").points
			check("tiro sai na linha exata do cano (y=%.1f -> %.1f)" % [pts[0].y, pts[1].y], is_equal_approx(pts[0].y, player.muzzle_position().y) and is_equal_approx(pts[0].y, pts[1].y))
		await physics_frame
	check("2 tiros matam", dead(z))
	await frames(0.5)
	var shots := 0
	for i in 15:
		player._weapon_wait = 0.0
		if player.shoot(Vector2.UP):
			shots += 1
	check("pente dá 12 tiros (deu %d)" % (shots + 2), shots + 2 == 12 and player.ammo == 0)
	var reserve0: int = player.reserve
	player.reload()
	await frames(0.2)
	check("recarga toca animação reload_*", player.reloading and player._action == "reload" and String(player.get_node("Sprite").animation).begins_with("reload"))
	await frames(player.reload_time)
	check("recarga enche o pente com a reserva e destrava ação", player.ammo == 12 and player.reserve == reserve0 - 12 and player._action == "")

	# 6. Zumbi ataca de perto, 15 por golpe, 1 por segundo; jogador mais rápido que ele.
	player.health = player.max_health
	z = await spawn(player.position + Vector2(40, 0), Vector2.LEFT)
	await frames(2.6)
	check("zumbi causou 45 de dano em ~2,6 s (vida %.0f)" % player.health, player.health == 55.0)
	check("zumbi persegue mais devagar que o jogador anda", z.chase_speed < player.walk_speed)
	z.queue_free()

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func spawn(pos: Vector2, facing: Vector2) -> CharacterBody2D:
	var z: CharacterBody2D = ZOMBIE.instantiate()
	z.position = pos
	z.facing = facing
	current_scene_root().add_child(z)
	await physics_frame
	return z


func current_scene_root() -> Node:
	return player.get_parent()


func frames(seconds: float) -> void:
	for i in int(seconds * HZ):
		await physics_frame


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok


func dead(z: Variant) -> bool:
	return not is_instance_valid(z) or not z.is_in_group("zombies")
