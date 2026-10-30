# Checagem do M3: stamina limita corrida e ações; morte detectada.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_movement.gd
extends SceneTree

const HZ := 60.0
var player: CharacterBody2D
var hud: CanvasLayer
var failed := false
var deaths := 0


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	hud = main.get_node("HUD")
	player.died.connect(func(): deaths += 1)
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	# Faixa livre da rua principal, de oeste para leste.
	player.position = Vector2(112, 592)

	# 1. Corrida: mais rápida que andar, gasta stamina, esgota em ~4 s.
	Input.action_press("move_right")
	Input.action_press("sprint")
	var x0 := player.position.x
	var t := 0
	while not player.stamina.exhausted and t < 10 * HZ:
		await physics_frame
		t += 1
	print("fôlego cheio durou %.2f s, %.0f px" % [t / HZ, player.position.x - x0])
	check("esgota em ~4 s", absf(t / HZ - 4.0) < 0.1)
	check("correu a ~130 px/s", absf((player.position.x - x0) / (t / HZ) - 130.0) < 3.0)

	# 2. Sem fôlego: Shift ainda apertado, mas volta à velocidade de andar.
	x0 = player.position.x
	await frames(1.0)
	check("sem fôlego anda a ~80 px/s", absf(player.position.x - x0 - 80.0) < 3.0)
	check("golpe recusado sem fôlego", not player.stamina.spend(10.0))
	Input.action_release("sprint")
	Input.action_release("move_right")

	# 3. Recupera: 0,8 s de espera + 25/15 s regenerando ≈ 2,47 s desde que esgotou
	# (1 s já passou no passo 2).
	t = 0
	while player.stamina.exhausted and t < 10 * HZ:
		await physics_frame
		t += 1
	print("recuperou o fôlego %.2f s após esgotar" % (1.0 + t / HZ))
	check("recupera em ~2,5 s", absf(1.0 + t / HZ - 2.47) < 0.1)
	check("golpe aceito com fôlego", player.stamina.spend(10.0))

	# 4. HUD acompanha.
	await physics_frame
	var bar: float = hud.get_node("Stamina/Fill").size.x
	check("barra de stamina no HUD (%.0f px)" % bar, bar == roundf(60.0 * player.stamina.current / player.stamina.maximum))

	# 5. Vida e morte.
	player.health.damage(60.0)
	check("vida 40 após 60 de dano", player.health.current == 40.0 and not player.is_dead())
	player.health.damage(60.0)
	player.health.damage(10.0)
	check("morte detectada uma vez", player.is_dead() and deaths == 1)
	check("aviso de morte visível", hud.get_node("Result").visible)
	x0 = player.position.x
	Input.action_press("move_left")
	await frames(0.5)
	Input.action_release("move_left")
	check("morto não anda", player.position.x == x0)

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func frames(seconds: float) -> void:
	for i in int(seconds * HZ):
		await physics_frame


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
