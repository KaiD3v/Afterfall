# Checagem do S3: sono e cansaço. A cama está no quarto da casa e F nela dorme. Bloqueia antes de
# 12 h acordado e quando a projeção de 8 h zeraria fome ou sede, com o motivo no aviso. Sono com
# folga avança o relógio 8 h, desconta 8 h de fome e sede e zera o cansaço; passar de 00:00 dormindo
# conta o dia. Acordado, o fôlego máximo só cai depois de 16 h e chega à metade em 24 h.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_sleep.gd
extends SceneTree

const HZ := 60
const HOUR := 75 * HZ  # quadros por hora de jogo
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
	var needs: Node = player.needs
	var toast: Label = main.get_node("HUD/Toast")
	for z in get_nodes_in_group("zombies"):
		z.queue_free()

	# Cansaço pelo laço real: nada até 16 h acordado; metade do fôlego em 24 h, e daí não passa.
	needs.awake = 15.0
	for i in HOUR:
		await process_frame
		needs.drink(100.0)  # sem morrer de sede no caminho
		needs.eat(100.0)
	check("16 h acordado: fôlego máximo inteiro (teto %.1f)" % player.stamina.cap, absf(player.stamina.cap - 100.0) < 0.1)
	for i in 4 * HOUR:
		await process_frame
		needs.drink(100.0)
		needs.eat(100.0)
	check("20 h acordado: fôlego máximo em 75 (teto %.1f)" % player.stamina.cap, absf(player.stamina.cap - 75.0) < 0.5)
	check("o fôlego atual não passa do teto", player.stamina.current <= player.stamina.cap)
	needs.awake = 30.0
	await process_frame
	check("30 h acordado: o teto para na metade (%.1f)" % player.stamina.cap, absf(player.stamina.cap - 50.0) < 0.1)

	# Entra na casa; a cama está no quarto.
	player.position = main.get_node("Neighborhood/HouseExit").position
	player.interact()
	await frames(0.7)
	var bed: Node = main.location.get_node_or_null("Bed")
	check("a cama está na casa, com arte", bed != null and bed.get_node("Sprite").texture != null)
	player.position = bed.position + Vector2(0, 24)
	await physics_frame
	await physics_frame
	check("perto da cama, o aviso é \"%s\"" % main.get_node("HUD/Prompt").text, player.focus == bed.get_node("Interactable") and main.get_node("HUD/Prompt").text == "%s · Dormir" % Keys.label(&"interact"))

	# Bloqueios, com o motivo no aviso; o relógio não anda.
	needs.awake = 5.0
	var t: float = rs.stats.time
	var slept: bool = await main.sleep()
	check("com 5 h acordado, não dorme", not slept and rs.stats.time == t)
	check("aviso: \"%s\"" % toast.text, toast.visible and toast.text.begins_with("Sem sono"))
	needs.awake = 14.0
	needs.hunger = 49.0  # 8 h de sono tiram 50
	needs.thirst = 100.0
	slept = await main.sleep()
	check("fome que zeraria dormindo bloqueia", not slept and rs.stats.time == t)
	check("aviso: \"%s\"" % toast.text, toast.text == "Fome demais: zeraria dormindo")
	needs.hunger = 100.0
	needs.thirst = 79.0  # 8 h de sono tiram 80
	slept = await main.sleep()
	check("sede que zeraria dormindo bloqueia", not slept)
	check("aviso: \"%s\"" % toast.text, toast.text == "Sede demais: zeraria dormindo")
	needs.hunger = 40.0
	check("as duas: \"%s\"" % needs.why_not_sleep(), needs.why_not_sleep() == "Fome e sede demais: zeraria dormindo")

	# Sono com folga, pelo F na cama: 8 h no relógio, fome -50, sede -80, cansaço zerado.
	needs.hunger = 90.0
	needs.thirst = 95.0
	needs.awake = 22.0
	player.stamina.current = 10.0
	var day: int = rs.stats.days()
	t = rs.stats.time
	var c: float = rs.stats.clock()
	player.interact()
	await frames(1.5)
	var hours: float = (rs.stats.clock() - c) / 3600.0
	check("dormir avança 8 h do relógio (%.2f h)" % hours, absf(hours - 8.0) < 0.1)
	check("fome %.1f (90 - 50) e sede %.1f (95 - 80)" % [needs.hunger, needs.thirst], absf(needs.hunger - 40.0) < 0.5 and absf(needs.thirst - 15.0) < 0.5)
	check("acorda descansado: cansaço zero, fôlego cheio", needs.awake < 0.1 and player.stamina.cap == 100.0 and player.stamina.current > 99.0)
	check("aviso: \"%s\"" % toast.text, toast.text == "Dormiu 8 h")
	check("logo depois de acordar, não dorme de novo", needs.why_not_sleep().begins_with("Sem sono"))

	# Dormir passando de 00:00 conta o dia.
	rs.stats.time = 1200.0 - 2.0 * 75.0  # 22:00 do dia 1 (a run começa às 08:00)
	day = rs.stats.days()
	needs.awake = 14.0
	needs.hunger = 100.0
	needs.thirst = 100.0
	check("22:00: ainda dia %d" % (day + 1), day == 0)
	await main.sleep()
	check("acorda às 06:00 do dia 2 (HUD: %s)" % main.get_node("HUD/Clock").text, rs.stats.days() == 1 and main.get_node("HUD/Clock").text.begins_with("Dia 2 · 06:0"))

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func frames(seconds: float) -> void:
	for i in int(seconds * HZ):
		await physics_frame


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
