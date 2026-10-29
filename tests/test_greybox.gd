# Checagem do M2: colisão do bairro e tempos de travessia a pé.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_greybox.gd
extends SceneTree

const HZ := 60.0
var player: CharacterBody2D
var failed := false


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	var spawn := player.position

	# 1. Rua principal de ponta a ponta (faixa da linha 18, sem carros no caminho).
	player.position = Vector2(112, 592)
	var t := await walk_to(Vector2(1820, 592))
	report("rua principal oeste→leste (1708 px)", t)

	# 2. Saída leste bloqueada pelos carros.
	await hold("move_right", 2.0)
	check("limite leste segura", player.position.x < 1856 - 5)

	# 3. Casa → posto e casa → oficina, pelas calçadas e ruas.
	player.position = spawn
	t = await walk_to(Vector2(336, 592))
	t += await walk_to(Vector2(1488, 592))
	t += await walk_to(Vector2(1488, 240))
	report("casa → posto", t)
	await hold("move_up", 1.0)
	check("posto é sólido", player.position.y > 224)

	player.position = spawn
	t = await walk_to(Vector2(336, 690))
	report("casa → oficina", t)
	await hold("move_down", 1.0)
	check("oficina é sólida", player.position.y < 704)

	# 4. Portão da cerca aberto, porta da casa sólida (entrada só no M5).
	player.position = spawn
	await hold("move_up", 3.0)
	check("passa pelo portão", player.position.y < 13 * 32)
	check("para na porta da casa", player.position.y > 12 * 32)

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


# Anda em L (primeiro x, depois y). Retorna segundos de jogo; falha se travar.
func walk_to(target: Vector2) -> float:
	var frames := 0
	for axis in [0, 1]:
		var neg := "move_left" if axis == 0 else "move_up"
		var pos := "move_right" if axis == 0 else "move_down"
		var stuck := 0
		while absf(player.position[axis] - target[axis]) > 1.5:
			var action := pos if target[axis] > player.position[axis] else neg
			Input.action_press(action)
			var before := player.position[axis]
			await physics_frame
			Input.action_release(action)
			frames += 1
			stuck = stuck + 1 if absf(player.position[axis] - before) < 0.1 else 0
			if stuck > 10:
				check("caminho livre até %s (travou em %s)" % [target, player.position], false)
				return frames / HZ
	return frames / HZ


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	for i in int(seconds * HZ):
		await physics_frame
	Input.action_release(action)


func report(label: String, seconds: float) -> void:
	print("%s: %.1f s" % [label, seconds])


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
