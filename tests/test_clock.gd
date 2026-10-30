# Checagem do S1: relógio de jogo e dias. Roda um dia e meio pelo laço real do main.gd e conta os
# quadros: de uma meia-noite à outra passam 1800 s reais (108000 quadros a 60 Hz); o dia conta ao virar 00:00 e a HUD
# acompanha; o relógio para com o jogo pausado; o resultado mostra os dias sobrevividos.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_clock.gd
extends SceneTree

const HZ := 60
var failed := false
var rs: Node  # autoload RunState; o script de teste compila antes dos autoloads


func _initialize() -> void:
	rs = root.get_node("RunState")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	var main: Node2D = current_scene
	var player: CharacterBody2D = main.get_node("Player")
	var clock: Label = main.get_node("HUD/Clock")
	for z in get_nodes_in_group("zombies"):
		z.queue_free()  # um dia inteiro parado: sem zumbi para matar o jogador
	check("começa no dia 1, 08:00 (HUD: %s)" % clock.text, rs.stats.days() == 0 and clock.text == "Dia 1 · 08:00")

	# Quadro a quadro pelo laço real: da largada à primeira meia-noite, e dela à seguinte.
	var flips: Array[int] = []  # quadro em que days() virou 1 e 2
	var n := 0
	var before := ""
	while flips.size() < 2:
		before = clock.text
		await process_frame
		n += 1
		if rs.stats.days() > flips.size():
			flips.append(n)
			var d := flips.size()
			check("o dia conta ao virar 00:00 (%s → %s)" % [before, clock.text], before == "Dia %d · 23:59" % d and clock.text == "Dia %d · 00:00" % (d + 1) and rs.stats.days() == d)
	check("primeira meia-noite 16 h depois das 08:00 = 1200 s reais (quadro %d)" % flips[0], absi(flips[0] - 1200 * HZ) <= 2)
	var day := flips[1] - flips[0]
	check("1 dia de jogo = 1800 s reais (%d quadros = %.2f s)" % [day, day / float(HZ)], absi(day - 1800 * HZ) <= 1)

	# Jogo pausado (menu que pausa): o relógio para.
	var t: float = rs.stats.time
	var shown := clock.text
	paused = true
	for i in 3 * HZ:
		await process_frame
	check("pausado, o relógio não anda", rs.stats.time == t and clock.text == shown)
	paused = false
	for i in 2 * HZ:
		await process_frame
	check("despausado, volta a andar", rs.stats.time > t and clock.text != shown)

	# Morte: o resultado mostra os dias sobrevividos.
	player.health.damage(150.0)
	for i in 2 * HZ:
		await physics_frame
	var text: String = main.get_node("HUD/Result/Text").text
	check("resultado mostra os dias sobrevividos (%s)" % text.c_escape(), main.get_node("HUD/Result").visible and "Dias sobrevividos: 2" in text)

	# Nova run: relógio de volta ao dia 1, 08:00.
	rs.new_run()
	check("nova run zera o relógio", rs.stats.days() == 0 and rs.stats.minute() == RunStats.START_HOUR * 60)

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
