# Checagem do M5: porta e spawn, casa como ponto seguro, loot dos containers e inventário.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_house.gd
extends SceneTree

const HZ := 60.0
var main: Node2D
var player: CharacterBody2D
var failed := false
var rs: Node  # autoload RunState; o script de teste compila antes dos autoloads


func _initialize() -> void:
	rs = root.get_node("RunState")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	rs.new_run()

	# 0. Regressão do crash de 2026-10-29: zumbis do main.tscn vêm antes do Player na árvore
	# e precisam achar o jogador; levar tiro não pode dar erro.
	var zs := get_nodes_in_group("zombies")
	check("os 4 zumbis da cena acham o jogador", zs.size() == 4 and zs.all(func(z): return z.player == player))
	var z0: Node = zs[0]
	z0.take_damage(10.0)
	check("zumbi da cena leva dano e persegue", z0.health == 50.0 and z0.state == z0.State.CHASE)
	z0.state = z0.State.IDLE
	z0.health = z0.max_health

	# 1. Porta: E na frente da casa entra; spawn do interior; bairro e zumbis fora da árvore.
	player.position = main.get_node("Neighborhood/HouseExit").position
	check("E na porta interage", player.interact())
	await frames(0.7)
	check("interior carregado", main.interior != null and main.interior.is_inside_tree())
	check("jogador no spawn do interior", player.position == main.interior.get_node("PlayerSpawn").position)
	check("bairro fora da árvore", not main.get_node_or_null("Neighborhood"))
	check("nenhum zumbi na casa (ponto seguro)", get_nodes_in_group("zombies").is_empty())
	var cam: Camera2D = player.get_node("Camera2D")
	check("câmera presa ao interior (%d×%d)" % [cam.limit_right, cam.limit_bottom], cam.limit_right == 480 and cam.limit_bottom == 288)

	# 2. Loot entra no inventário; container esvazia; munição vai para a reserva.
	var box: Node = main.interior.get_node("Armario")
	box.table = table([&"bandage"], 2)
	box.id = &"teste_bandagens"
	player.position = box.position + Vector2(0, 22)
	check("E no container interage", player.interact())
	check("2 bandagens no inventário", rs.items.count(&"bandage") == 2)
	player.interact()
	check("container vazio na segunda vez", rs.items.size() == 2)
	var ammo_box: Node = main.interior.get_node("Mesa")
	ammo_box.table = table([&"ammo_9mm"], 1)
	ammo_box.id = &"teste_municao"
	var reserve0: int = player.reserve
	ammo_box.interact(player)
	check("munição soma 6 na reserva", player.reserve == reserve0 + 6 and rs.items.size() == 2)

	# 3. Inventário cheio: o item fica no container e sai depois.
	for i in 6:
		rs.add_item(&"bandage")
	var full: Node = main.interior.get_node("Comoda")
	full.table = table([&"bandage"], 1)
	full.id = &"teste_cheio"
	full.interact(player)
	check("8 slots: não pega o 9º", rs.items.size() == 8)
	rs.take_item(&"bandage")
	full.interact(player)
	check("liberou um slot: pega o que ficou", rs.items.size() == 8 and rs.loot_of(&"teste_cheio", full.table).is_empty())

	# 4. Bandagem cura 30 e é consumida; com vida cheia não gasta.
	player.health = 50.0
	check("bandagem cura", player.use_bandage() and player.health == 80.0 and rs.items.size() == 7)
	player.health = player.max_health
	check("vida cheia não gasta bandagem", not player.use_bandage() and rs.items.size() == 7)

	# 5. Loot fixo na run: o mesmo container não sorteia de novo; nova run sorteia.
	var real: LootTable = load("res://data/loot/armario.tres")
	var first: Array = rs.loot_of(&"armario_run", real).duplicate()
	check("mesma run, mesmo loot", rs.loot_of(&"armario_run", real) == first)
	rs.new_run()
	check("nova run zera inventário", rs.items.is_empty())

	# 6. Tabelas reais só têm itens conhecidos.
	for t in ["armario", "geladeira", "mesa", "comoda"]:
		var lt: LootTable = load("res://data/loot/%s.tres" % t)
		var ok := lt.items.size() == lt.weights.size()
		for i in 50:
			for item in lt.roll():
				ok = ok and rs.NAMES.has(item)
		check("tabela %s válida" % t, ok)

	# 7. Sair: porta do interior devolve ao bairro, na frente da casa; zumbis voltam.
	player.position = main.interior.get_node("PlayerSpawn").position
	check("E na porta de saída interage", player.interact())
	await frames(0.7)
	check("interior descartado", main.interior == null)
	check("bairro de volta", main.get_node_or_null("Neighborhood") != null)
	check("jogador na frente da casa", player.position == main.get_node("Neighborhood/HouseExit").position)
	check("4 zumbis de volta", get_nodes_in_group("zombies").size() == 4)
	check("câmera presa ao bairro", cam.limit_right == 1920 and cam.limit_bottom == 1088)
	await physics_frame
	var y0 := player.position.y
	await hold("move_down", 0.3)
	check("jogador anda depois da transição", player.position.y > y0)

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func table(items: Array[StringName], rolls: int) -> LootTable:
	var t := LootTable.new()
	t.items = items
	var w: Array[float] = []
	for i in items:
		w.append(1.0)
	t.weights = w
	t.rolls = rolls
	return t


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await frames(seconds)
	Input.action_release(action)


func frames(seconds: float) -> void:
	for i in int(seconds * HZ):
		await physics_frame


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
