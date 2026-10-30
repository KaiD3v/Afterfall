# Checagem da R1 a R3: Health e Stamina como componentes. Um objeto qualquer com um nó Health
# (aqui, uma barricada sem script) leva tiro sem código novo; ação nova cancela o golpe pendente;
# arma nova é só um Resource de dados num nó MeleeWeapon, o mesmo da mordida do zumbi;
# tipo novo de zumbi é só um ZombieData.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_components.gd
extends SceneTree

var failed := false


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	for z in main.get_node("Zombies").get_children():
		z.free()
	root.add_child(main)
	_run.call_deferred(main)


func _run(main: Node) -> void:
	await physics_frame
	var player = main.get_node("Player")  # sem tipo: player.gd usa o autoload, que o teste ainda não tem ao compilar
	player.position = Vector2(760, 592)  # rua principal, livre entre x 700 e 860

	# 1. Health: sinais, cura limitada ao máximo, morte uma vez só.
	var h := Health.new()
	h.maximum = 50.0
	root.add_child(h)
	var log := []
	h.damaged.connect(func(a, s): log.append([a, s]))
	h.died.connect(func(): log.append("died"))
	h.damage(20.0, player)
	h.heal(100.0)
	check("cura não passa do máximo", h.current == 50.0 and h.is_full())
	h.damage(60.0)
	h.damage(10.0)
	check("dano com a fonte, morte uma vez, nada depois de morto (%s)" % [log], log.size() == 3 and log[0] == [20.0, player] and log[2] == "died" and h.current == 0.0)

	# 2. Stamina: gasto, esgotamento e recuperação depois da espera.
	var st := Stamina.new()
	root.add_child(st)
	check("gasto aceito com fôlego", st.spend(30.0) and st.current == 70.0)
	st.drain(100.0)
	check("esgota e recusa gasto", st.exhausted and not st.spend(1.0))
	for i in 60:
		st.recover(1.0 / 60.0)
	check("parado 1 s: ainda sem fôlego (0,8 s de espera)", st.exhausted and st.current < st.recover_at)
	for i in 120:
		st.recover(1.0 / 60.0)
	check("recupera acima de recover_at", not st.exhausted)

	# 3. Destrutível só com Health: StaticBody2D + colisão + nó Health, sem script.
	var box := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(16, 48)
	box.add_child(shape)
	var box_health := Health.new()
	box_health.name = "Health"
	box_health.maximum = 100.0
	box.add_child(box_health)
	box.position = player.position + Vector2(100, -12)
	main.add_child(box)
	await physics_frame
	await physics_frame
	player.firearm.gun().spread = 0.0
	player.shoot(Vector2.RIGHT)
	check("tiro acha o Health da barricada (vida %.0f)" % box_health.current, box_health.current == 100.0 - player.firearm.gun().damage)

	# 4. Ação nova cancela o golpe pendente: recarregar no meio do golpe não acerta depois.
	await frames(0.6)
	var z: Actor = load("res://scenes/zombie/zombie.tscn").instantiate()
	z.position = player.position + Vector2(-24, 0)
	z.facing = Vector2.LEFT  # de costas: não persegue nem morde durante o teste
	main.add_child(z)
	await physics_frame
	player.facing = Vector2.LEFT
	player.firearm.ammo = 0
	player.melee()
	player.reload()
	await frames(0.5)
	check("golpe cancelado pela recarga (vida %.0f)" % z.health.current, z.health.current == z.health.maximum)

	# 5. Arma nova só por dado: um pé de cabra (MeleeData criado aqui) num nó MeleeWeapon.
	await frames(1.6)  # a recarga termina e o machete esfria
	var crowbar := MeleeData.new()
	crowbar.damage = 50.0
	crowbar.reach = 30.0
	crowbar.half_angle = 60.0
	crowbar.target_group = Groups.ZOMBIES
	crowbar.anim = "sem_animacao"  # sem a ação na sheet, o golpe sai na hora
	var weapon := MeleeWeapon.new()
	weapon.data = crowbar
	player.add_child(weapon)
	await physics_frame
	var swung: bool = weapon.attack()
	check("pé de cabra acerta sem código novo (vida %.0f)" % z.health.current, swung and z.health.current == z.health.maximum - 50.0)
	check("e respeita a própria espera", not weapon.attack())
	check("mordida do zumbi é o mesmo MeleeWeapon do machete", z.get_node("Attack") is MeleeWeapon and player.get_node("Machete") is MeleeWeapon)
	z.queue_free()

	# 6. Variante só por dado (R3): ZombieData de teste com outra vida, velocidade e audição.
	var brute: ZombieData = load("res://data/zombies/walker.tres").duplicate()
	brute.max_health = 200.0
	brute.chase_speed = 90.0
	brute.hearing = 3.0
	var zb: Actor = load("res://scenes/zombie/zombie.tscn").instantiate()
	zb.data = brute
	zb.position = player.position + Vector2(100, 0)
	zb.facing = Vector2.RIGHT  # de costas para o jogador
	main.add_child(zb)
	await physics_frame
	check("vida do tipo (%.0f/%.0f)" % [zb.health.current, zb.health.maximum], zb.health.maximum == 200.0 and zb.health.current == 200.0)
	zb.hear(zb.position + Vector2(150, 0), 64.0)  # o andarilho não ouve: 64 < 150; com audição 3, 192
	check("audição do tipo ouve mais longe", zb.state == zb.State.INVESTIGATE)
	zb.health.damage(10.0, player)
	await frames(0.6)  # o tranco termina e ele corre para quem bateu
	check("persegue quem bateu na velocidade do tipo (%.0f px/s)" % zb.velocity.length(), zb.state == zb.State.CHASE and zb.target == player and is_equal_approx(zb.velocity.length(), 90.0))
	check("o andarilho segue com os números de antes", load("res://data/zombies/walker.tres").chase_speed == 60.0)

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func frames(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
