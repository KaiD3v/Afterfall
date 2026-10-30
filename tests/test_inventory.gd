# Checagem do menu de inventário (v1): mochila de 9 blocos, equipamento de 4 slots, troca entre os
# dois (arrastar e soltar, botão direito), armas do equipamento na mão do jogador e menu que não
# pausa o mundo mas deixa o jogador parado.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_inventory.gd
extends SceneTree

const BANDAGE := preload("res://data/items/bandage.tres")
const HELMET := preload("res://data/items/helmet.tres")
const VEST := preload("res://data/items/vest.tres")
const MACHETE := preload("res://data/items/machete.tres")
const PISTOL := preload("res://data/items/pistol_9mm.tres")
const MELEE := EquipmentItem.Slot.MELEE
const FIREARM := EquipmentItem.Slot.FIREARM
const HEAD := EquipmentItem.Slot.HEAD
const BODY := EquipmentItem.Slot.BODY

var failed := false


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	for z in main.get_node("Neighborhood/Zombies").get_children():  # aqui só interessa o inventário
		z.free()
	root.add_child(main)
	_run.call_deferred(main)


func _run(main: Node) -> void:
	await physics_frame
	var rs: Node = root.get_node("RunState")
	var player = main.get_node("Player")  # sem tipo: player.gd usa o autoload, que o teste ainda não tem ao compilar
	var menu = main.get_node("InventoryMenu")
	var bag: Inventory = rs.inventory
	var gear: Equipment = rs.equipment

	# 1. Começo da run: mochila vazia, machete e pistola equipados e na mão.
	check("mochila de 9 blocos vazia", bag.capacity == 9 and bag.is_empty() and bag.free_slots() == 9)
	check("machete e pistola equipados, cabeça e corpo vazios", gear.get_at(MELEE) == MACHETE and gear.get_at(FIREARM) == PISTOL and gear.get_at(HEAD) == null and gear.get_at(BODY) == null)
	check("as armas da mão são as do equipamento, pente cheio", player.melee_weapon.data == MACHETE.weapon and player.firearm.data == PISTOL.weapon and player.firearm.ammo == 12)

	# 2. Recipientes e transferência: cada item só vai onde cabe.
	bag.add(BANDAGE)  # bloco 0
	bag.add(HELMET)   # bloco 1
	check("bandagem não vai na cabeça", not ItemTransfer.swap(bag, 0, gear, HEAD))
	check("capacete vai na cabeça", ItemTransfer.swap(bag, 1, gear, HEAD) and gear.get_at(HEAD) == HELMET and bag.get_at(1) == null)
	check("move dentro da mochila", ItemTransfer.swap(bag, 0, bag, 5) and bag.get_at(5) == BANDAGE and bag.get_at(0) == null)
	bag.put(0, VEST)
	check("troca dois itens de lugar na mochila", ItemTransfer.swap(bag, 0, bag, 5) and bag.get_at(0) == BANDAGE and bag.get_at(5) == VEST)
	check("colete não vai na arma de fogo", not ItemTransfer.swap(bag, 5, gear, FIREARM))
	check("machete não troca com bandagem (ela não cabe na arma branca)", not ItemTransfer.swap(gear, MELEE, bag, 0) and gear.get_at(MELEE) == MACHETE)

	# 3. Arma desequipada sai da mão de verdade; reequipada, volta.
	var ammo0: int = player.firearm.ammo
	check("desequipa o machete para a mochila", ItemTransfer.swap(gear, MELEE, bag, bag.first_free()) and bag.count(&"machete") == 1)
	check("sem machete o golpe não sai", player.melee_weapon.data == null and not player.melee())
	check("desequipa a pistola: sem tiro, HUD avisa", ItemTransfer.swap(gear, FIREARM, bag, bag.first_free()) and not player.shoot(Vector2.RIGHT) and main.get_node("HUD/Ammo").text == "SEM ARMA")
	ItemTransfer.swap(bag, _index(bag, MACHETE), gear, MELEE)
	ItemTransfer.swap(bag, _index(bag, PISTOL), gear, FIREARM)
	check("reequipadas, voltam à mão (pente como estava)", player.melee() and player.firearm.data == PISTOL.weapon and player.firearm.ammo == ammo0)

	# 4. Menu: E abre, jogador parado, mundo segue, slots ligados.
	check("E é o inventário e F a interação", InputMap.event_is_action(_key(KEY_E), "inventory") and InputMap.event_is_action(_key(KEY_F), "interact") and not InputMap.event_is_action(_key(KEY_E), "interact"))
	check("os avisos mostram a tecla do mapa", Keys.label(&"interact") == "F" and Keys.label(&"inventory") == "E")
	menu._unhandled_input(_key(KEY_E))
	check("E abre o menu", menu.is_open() and player.input_locked)
	check("o mundo não pausa", not paused)
	check("4 slots de equipamento e 9 blocos de mochila", menu.gear_slots.size() == 4 and menu.bag_slots.size() == 9)
	var x0: float = player.position.x
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	Input.action_release("move_right")
	check("com o menu aberto o jogador não anda", player.position.x == x0)
	var body_slot: ItemSlot = _gear_slot(menu, BODY)
	var head_slot: ItemSlot = _gear_slot(menu, HEAD)
	var vest_slot: ItemSlot = menu.bag_slots[_index(bag, VEST)]
	var bandage_slot: ItemSlot = menu.bag_slots[_index(bag, BANDAGE)]
	check("arrastar bandagem para a cabeça é recusado", not head_slot._can_drop_data(Vector2.ZERO, {"slot": bandage_slot}))
	check("arrastar colete para o corpo é aceito", body_slot._can_drop_data(Vector2.ZERO, {"slot": vest_slot}))
	body_slot._drop_data(Vector2.ZERO, {"slot": vest_slot})
	check("soltar equipa o colete", gear.get_at(BODY) == VEST and vest_slot.item() == null)
	check("slots de equipamento com o nome do tipo", menu.gear_slots.map(func(s): return s.caption) == ["Capacete", "Arma branca", "Arma de fogo", "Colete"])
	player.health.current = 50.0
	menu.activate(bandage_slot)
	check("botão direito na bandagem cura", player.health.current == 80.0 and bag.count(&"bandage") == 0)
	menu.activate(head_slot)
	check("botão direito no capacete desequipa", gear.get_at(HEAD) == null and bag.count(&"helmet") == 1)
	menu.activate(menu.bag_slots[_index(bag, HELMET)])
	check("botão direito no capacete da mochila equipa", gear.get_at(HEAD) == HELMET)
	head_slot.hovered.emit(head_slot)
	check("passar o mouse mostra nome e descrição", menu._name.text == HELMET.display_name and menu._desc.text == HELMET.description)
	head_slot.unhovered.emit(head_slot)
	check("ao sair do item o rodapé volta à dica", menu._name.text == "" and menu._desc.text.begins_with("Arraste"))
	check("armas em slots de 48 px, cabeça e corpo em 32", _gear_slot(menu, MELEE).size == ItemSlot.LARGE and _gear_slot(menu, FIREARM).size == ItemSlot.LARGE and head_slot.size == ItemSlot.SMALL and body_slot.size == ItemSlot.SMALL)
	check("slots vazios com rótulo curto", menu.gear_slots.map(func(s): return s.short_caption) == ["CABEÇA", "BRANCA", "FOGO", "CORPO"])
	menu._unhandled_input(_key(KEY_ESCAPE))
	check("Esc fecha e devolve o controle", not menu.is_open() and not player.input_locked)

	# 5. Nova run: mochila vazia e só o equipamento inicial, já na mão.
	rs.new_run()
	check("nova run: só machete e pistola, mochila vazia", gear.get_at(MELEE) == MACHETE and gear.get_at(FIREARM) == PISTOL and gear.get_at(HEAD) == null and gear.get_at(BODY) == null and bag.is_empty())
	check("e as armas na mão", player.melee_weapon.data == MACHETE.weapon and player.firearm.data == PISTOL.weapon)

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _index(bag: Inventory, item: ItemData) -> int:
	for i in bag.capacity:
		if bag.get_at(i) == item:
			return i
	return -1


func _gear_slot(menu: Node, slot: int) -> ItemSlot:
	for s: ItemSlot in menu.gear_slots:
		if s.key == slot:
			return s
	return null


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code  # ui_cancel casa por keycode; as teclas do projeto, por physical_keycode
	e.physical_keycode = code
	e.pressed = true
	return e


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
