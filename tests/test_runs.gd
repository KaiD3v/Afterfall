# Checagem do M6: três runs seguidas sem vazar estado de uma para a outra.
# Cada run: estado inicial limpo → mata zumbi, saqueia a casa, toma dano → morre →
# tela de resultado → E (depois do atraso) → nova run pelo caminho real (reload da cena).
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_runs.gd
extends SceneTree

const BANDAGE := preload("res://data/items/bandage.tres")

const HZ := 60.0
var failed := false
var rs: Node  # autoload RunState; o script de teste compila antes dos autoloads


func _initialize() -> void:
	rs = root.get_node("RunState")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main  # reload_current_scene() precisa de uma cena atual
	_run.call_deferred()


func _run() -> void:
	for run in range(1, 4):
		await physics_frame
		var main: Node2D = current_scene
		var player: CharacterBody2D = main.get_node("Player")
		print("--- run %d" % run)

		# Estado inicial limpo.
		check("vida, stamina e munição cheias", player.health.current == 100.0 and player.stamina.current == 100.0 and player.firearm.ammo == 12 and player.firearm.reserve == 24)
		check("inventário vazio e loot não sorteado", rs.inventory.is_empty() and [&"geladeira", &"armario", &"mesa", &"comoda"].all(func(id): return not rs.has_rolled(id)))
		check("números da run zerados", rs.kills == 0 and rs.looted == 0 and rs.run_time < 0.5)
		check("4 zumbis vivos, cheios", get_nodes_in_group("zombies").size() == 4 and get_nodes_in_group("zombies").all(func(z): return z.health.current == z.health.maximum))
		check("no bairro, no ponto de nascimento", main.interior == null and player.position == Vector2(336, 464))
		check("resultado escondido", not main.get_node("HUD/Result").visible)
		check("mortes acumuladas = %d" % (run - 1), rs.deaths == run - 1)

		# Joga: mata um zumbi, saqueia a casa, sai.
		get_nodes_in_group("zombies")[0].health.damage(60.0)
		check("zumbi morto conta", rs.kills == 1)
		player.position = main.get_node("Neighborhood/HouseExit").position
		player.interact()
		await frames(0.7)
		var box: Node = main.interior.get_node("Armario")
		box.table = LootTable.new()
		box.table.items.assign([BANDAGE])
		box.table.weights = [1.0] as Array[float]
		box.table.rolls = 2
		box.interact(player)
		check("saque entra no inventário", rs.inventory.size() == 2 and rs.looted == 2)
		player.position = main.interior.get_node("PlayerSpawn").position
		player.interact()
		await frames(0.7)
		check("saiu da casa", main.interior == null)

		# Morre: resultado na tela com os números da run.
		player.health.damage(150.0)
		await physics_frame
		var text: String = main.get_node("HUD/Result/Text").text
		check("resultado visível", main.get_node("HUD/Result").visible)
		check("resultado mostra zumbis, itens e mortes", "1 zumbis" in text and "2 itens" in text and ("Mortes: %d" % run) in text)
		var t: float = rs.run_time
		await frames(0.3)
		check("tempo para de contar morto", rs.run_time == t)

		# E antes do atraso não recomeça; depois recomeça.
		await press("interact")
		check("E logo após morrer não recomeça", current_scene == main)
		await frames(1.0)
		await press("interact")
		for i in 30:
			if current_scene != main and current_scene and current_scene.is_node_ready():
				break
			await process_frame
		check("E recomeça: cena nova", current_scene != main and is_instance_valid(current_scene))

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func press(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await process_frame
	Input.action_release(action)
	await process_frame


func frames(seconds: float) -> void:
	for i in int(seconds * HZ):
		await physics_frame


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
