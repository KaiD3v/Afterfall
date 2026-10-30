# Checagem do S2: fome e sede. Pelo laço real do main.gd, quadro a quadro: a sede zera em 10 h de
# jogo (750 s) e a fome em 16 h (1200 s); comer e beber (teclas 1 e 2) repõem e gastam o item;
# zerada, uma necessidade tira 100 de vida em 2 h de jogo (150 s); a morte registra a causa certa
# na tela de resultado (fome, sede, zumbi), em três runs pelo caminho real (reload da cena).
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_needs.gd
extends SceneTree

const FOOD := preload("res://data/items/food_can.tres")
const WATER := preload("res://data/items/water_bottle.tres")

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
	# --- run 1: taxas, comer e beber, morte de fome
	var main := await _fresh()
	var player: CharacterBody2D = main.get_node("Player")
	var needs: Node = player.needs
	var hud: Node = main.get_node("HUD")
	needs.sheltered = true  # sem frio (S5) na noite que este teste atravessa
	check("começa com fome e sede cheias, barras cheias", needs.hunger > 99.9 and needs.thirst > 99.9 and hud.hunger_fill.size.x == hud._needs_w.x and hud.thirst_fill.size.x == hud._needs_w.y)

	# Quadro a quadro: a sede zera (anota e bebe de novo) até a fome zerar.
	var n := 0
	var thirst_at := -1
	while needs.hunger > 0.0:
		await process_frame
		n += 1
		if thirst_at < 0 and needs.thirst == 0.0:
			thirst_at = n
			check("vida intacta até a sede zerar (%.2f)" % player.health.current, player.health.current > 99.0)
			needs.drink(100.0)
	check("sede zera em 10 h de jogo = 750 s (quadro %d)" % thirst_at, absi(thirst_at - 10 * HOUR) <= 2)
	check("fome zera em 16 h de jogo = 1200 s (quadro %d)" % n, absi(n - 16 * HOUR) <= 2)
	check("barra de fome vazia na HUD", hud.hunger_fill.size.x == 0.0)

	# Fome zerada: 1 h de jogo tira 50 de vida.
	var hp: float = player.health.current
	for i in HOUR:
		await process_frame
	check("fome zerada tira 50 de vida por hora de jogo (%.2f)" % (hp - player.health.current), absf(hp - player.health.current - 50.0) < 0.5)

	# Pausado, nada cai.
	var before := [needs.hunger, needs.thirst, player.health.current]
	paused = true
	for i in 2 * HZ:
		await process_frame
	check("pausado, fome, sede e vida não mudam", [needs.hunger, needs.thirst, player.health.current] == before)
	paused = false

	# Comer e beber pelas teclas 1 e 2.
	rs.inventory.add(FOOD)
	rs.inventory.add(WATER)
	needs.thirst = 30.0
	await press("eat")
	check("tecla 1 come: fome +50 e a lata some (fome %.1f)" % needs.hunger, absf(needs.hunger - 50.0) < 0.5 and rs.inventory.count(&"food_can") == 0)
	await press("drink")
	check("tecla 2 bebe: sede +50 e a garrafa some (sede %.1f)" % needs.thirst, absf(needs.thirst - 80.0) < 0.5 and rs.inventory.count(&"water_bottle") == 0)
	needs.drink(100.0)
	rs.inventory.add(WATER)
	await press("drink")
	check("com a sede cheia, não bebe nem gasta", rs.inventory.count(&"water_bottle") == 1)
	check("menu explica: \"%s\"" % main.get_node("InventoryMenu")._why_not_use(WATER), main.get_node("InventoryMenu")._why_not_use(WATER) == "Sem sede")

	# Morre de fome: a causa aparece no resultado.
	needs.hunger = 0.0
	needs.drink(100.0)
	await _until_result(main)
	check("resultado: causa fome", "Causa: fome ·" in _result(main))

	# --- run 2: morte por zumbi
	main = await _new_run(main)
	player = main.get_node("Player")
	check("nova run: fome e sede cheias", player.needs.hunger > 99.9 and player.needs.thirst > 99.9)
	player.health.damage(500.0, get_nodes_in_group("zombies")[0])
	await _until_result(main)
	check("resultado: causa zumbi", "Causa: zumbi ·" in _result(main))

	# --- run 3: morte de sede
	main = await _new_run(main)
	player = main.get_node("Player")
	_clear_zombies()
	player.needs.thirst = 0.0
	await _until_result(main)
	check("resultado: causa sede", "Causa: sede ·" in _result(main))

	# Saque: geladeira e armário dão comida e água; mesa e cômoda não.
	var per_run := {&"food_can": 0, &"water_bottle": 0}
	var runs_without := {&"food_can": 0, &"water_bottle": 0}
	var tables := {}
	for t in ["geladeira", "armario", "mesa", "comoda"]:
		tables[t] = load("res://data/loot/%s.tres" % t)
	check("mesa e cômoda sem comida nem água", ["mesa", "comoda"].all(func(t): return not tables[t].items.has(FOOD) and not tables[t].items.has(WATER)))
	const RUNS := 2000
	for r in RUNS:
		var got: Array = tables["geladeira"].roll() + tables["armario"].roll()
		for id in per_run:
			var c := got.filter(func(it): return it.id == id).size()
			per_run[id] += c
			if c == 0:
				runs_without[id] += 1
	for id in per_run:
		var avg: float = per_run[id] / float(RUNS)
		var none: float = runs_without[id] / float(RUNS)
		check("%s: %.2f por casa, %.0f%% das runs sem" % [id, avg, none * 100.0], avg > 1.3 and avg < 1.9 and none < 0.2)

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


# Cena atual depois do primeiro quadro, sem zumbis (para não morrer de outra coisa).
func _fresh() -> Node2D:
	await physics_frame
	_clear_zombies()
	return current_scene


func _clear_zombies() -> void:
	for z in get_nodes_in_group("zombies"):
		z.queue_free()


func _until_result(main: Node) -> void:
	for i in 300 * HZ:
		if main.get_node("HUD/Result").visible:
			return
		await process_frame


func _result(main: Node) -> String:
	return main.get_node("HUD/Result/Text").text


# F depois do atraso: nova run pela cena recarregada.
func _new_run(main: Node) -> Node2D:
	for i in 70:
		await physics_frame
	await press("interact")
	for i in 30:
		if current_scene != main and current_scene and current_scene.is_node_ready():
			break
		await process_frame
	await physics_frame
	return current_scene


func press(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await process_frame
	Input.action_release(action)
	await process_frame


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
