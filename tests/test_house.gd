# Checagem do M5: porta e spawn, casa como ponto seguro, loot dos containers e inventário.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_house.gd
extends SceneTree

const BANDAGE := preload("res://data/items/bandage.tres")
const AMMO := preload("res://data/items/ammo_9mm.tres")

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
	z0.health.damage(10.0)
	check("zumbi da cena leva dano e persegue", z0.health.current == 50.0 and z0.state == z0.State.CHASE)
	z0.state = z0.State.IDLE
	z0.health.current = z0.health.maximum

	# 1. Porta: E na frente da casa entra; spawn do interior; bairro e zumbis fora da árvore.
	player.position = main.get_node("Neighborhood/HouseExit").position
	check("E na porta interage", player.interact())
	await frames(0.7)
	check("interior carregado", main.is_inside() and main.location.is_inside_tree() and main.location.name == "HouseInterior")
	var amb_out: AudioStreamPlayer = main.ambience_player(load("res://assets/audio/ambience/exterior.ogg"))
	var amb_in: AudioStreamPlayer = main.ambience_player(main.location.ambience)
	check("ambiente em loop no canal Ambience", amb_out.stream.loop and amb_in.stream.loop and amb_out.bus == &"Ambience" and amb_in.bus == &"Ambience")
	check("dentro: ouve-se o interior (fora %.2f, dentro %.2f)" % [amb_out.volume_linear, amb_in.volume_linear], is_zero_approx(amb_out.volume_linear) and is_equal_approx(amb_in.volume_linear, 1.0))
	check("jogador no spawn do interior", player.position == main.location.get_node("PlayerSpawn").position)
	check("bairro fora da árvore", not main.get_node_or_null("Neighborhood"))
	check("nenhum zumbi na casa (ponto seguro)", get_nodes_in_group("zombies").is_empty())
	var cam: Camera2D = player.get_node("Camera2D")
	check("câmera presa ao interior (%d×%d)" % [cam.limit_right, cam.limit_bottom], cam.limit_right == 480 and cam.limit_bottom == 288)

	# 2. F no móvel abre o menu com o conteúdo; pegar tudo leva para a mochila; munição vai para a reserva.
	var menu: Node = main.get_node("InventoryMenu")
	var box: Node = main.location.get_node("Armario")
	box.table = table([BANDAGE], 2)
	box.id = &"teste_bandagens"
	player.position = box.position + Vector2(0, 22)
	check("F no móvel abre o menu com o conteúdo dele", player.interact() and menu.is_open() and menu.looting == box and menu.loot_slots[0].item() == BANDAGE)
	menu.take_all()
	check("pegar tudo: 2 bandagens na mochila", rs.inventory.count(&"bandage") == 2 and box.is_looted())
	menu.close()
	player.interact()
	menu.take_all()
	check("móvel vazio na segunda vez", rs.inventory.size() == 2 and menu._name.text == "O móvel está vazio")
	menu.close()
	var ammo_box: Node = main.location.get_node("Mesa")
	ammo_box.table = table([AMMO], 1)
	ammo_box.id = &"teste_municao"
	var reserve0: int = player.firearm.reserve
	ammo_box.take_all(player)
	check("munição soma 6 na reserva", player.firearm.reserve == reserve0 + 6 and rs.inventory.size() == 2)

	# 3. Inventário cheio: o item fica no container e sai depois.
	for i in 7:
		rs.inventory.add(BANDAGE)
	var full: Node = main.location.get_node("Comoda")
	full.table = table([BANDAGE], 1)
	full.id = &"teste_cheio"
	check("9 blocos: não pega o 10º", full.take_all(player).full and rs.inventory.size() == 9)
	rs.inventory.take(&"bandage")
	full.take_all(player)
	check("liberou um slot: pega o que ficou", rs.inventory.size() == 9 and rs.loot.of(&"teste_cheio", full.table).is_empty())

	# 4. Bandagem cura 30 e é consumida; com vida cheia não gasta.
	player.health.current = 50.0
	check("bandagem cura", player.use_item(BANDAGE) and player.health.current == 80.0 and rs.inventory.size() == 8)
	player.health.current = player.health.maximum
	check("vida cheia não gasta bandagem", not player.use_item(BANDAGE) and rs.inventory.size() == 8)

	# 5. Loot fixo na run: o mesmo container não sorteia de novo; nova run sorteia.
	var real: LootTable = load("res://data/loot/armario.tres")
	var first: Array = rs.loot.of(&"armario_run", real).items
	check("mesma run, mesmo loot", rs.loot.of(&"armario_run", real).items == first)
	rs.new_run()
	check("nova run zera inventário", rs.inventory.is_empty())

	# 6. Tabelas reais só têm itens conhecidos.
	for t in ["armario", "geladeira", "mesa", "comoda"]:
		var lt: LootTable = load("res://data/loot/%s.tres" % t)
		var ok := lt.items.size() == lt.weights.size()
		for i in 50:
			for item in lt.roll():
				ok = ok and item is ItemData and item.display_name != ""
		check("tabela %s válida" % t, ok)

	# 7. Sair: porta do interior devolve ao bairro, na frente da casa; zumbis voltam.
	player.position = main.location.get_node("PlayerSpawn").position
	check("E na porta de saída interage", player.interact())
	await frames(0.7)
	check("interior descartado", not main.is_inside())
	check("fora: volta o ambiente da rua", is_equal_approx(amb_out.volume_linear, 1.0) and is_zero_approx(amb_in.volume_linear))
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


func table(items: Array, rolls: int) -> LootTable:
	var t := LootTable.new()
	t.items.assign(items)
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
