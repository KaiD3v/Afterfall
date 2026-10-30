# Checagem do menu de inventário (v1): mochila de 9 blocos, equipamento de 4 slots, troca entre os
# dois (arrastar e soltar, botão direito), armas do equipamento na mão do jogador e menu que não
# pausa o mundo mas deixa o jogador parado.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_inventory.gd
extends SceneTree

const BANDAGE := preload("res://data/items/bandage.tres")
const HELMET := preload("res://data/items/helmet.tres")
const VEST := preload("res://data/items/vest.tres")
const AMMO := preload("res://data/items/ammo_9mm.tres")
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
	check("desequipa a pistola: sem tiro, HUD avisa", ItemTransfer.swap(gear, FIREARM, bag, bag.first_free()) and not player.shoot(Vector2.RIGHT) and not main.get_node("HUD/WeaponCard/Mag").visible and main.get_node("HUD/WeaponCard/FirearmIcon").texture == null)
	ItemTransfer.swap(bag, _index(bag, MACHETE), gear, MELEE)
	ItemTransfer.swap(bag, _index(bag, PISTOL), gear, FIREARM)
	check("reequipadas, voltam à mão (pente como estava)", player.melee() and player.firearm.data == PISTOL.weapon and player.firearm.ammo == ammo0)

	# 4. Menu: E abre, jogador parado, mundo segue, slots ligados.
	check("E é o inventário e F a interação", InputMap.event_is_action(_key(KEY_E), "inventory") and InputMap.event_is_action(_key(KEY_F), "interact") and not InputMap.event_is_action(_key(KEY_E), "interact"))
	check("os avisos mostram a tecla do mapa", Keys.label(&"interact") == "F" and Keys.label(&"inventory") == "E")
	menu._unhandled_input(_key(KEY_E))
	check("E abre o menu", menu.is_open() and player.input_locked)
	check("o mundo não pausa", not paused)
	check("a linha de inventário da HUD some por trás do menu", not main.get_node("HUD/Inventory").visible and not main.get_node("HUD/BottomPanel").visible)
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
	check("slots de equipamento com o nome do tipo", menu.gear_slots.map(func(s): return s.caption) == ["Capacete", "Colete", "Arma branca", "Arma de fogo"])
	player.health.current = 50.0
	menu.activate(bandage_slot)
	check("botão direito na bandagem cura", player.health.current == 80.0 and bag.count(&"bandage") == 0)
	menu.activate(head_slot)
	check("botão direito no capacete desequipa", gear.get_at(HEAD) == null and bag.count(&"helmet") == 1)
	menu.activate(menu.bag_slots[_index(bag, HELMET)])
	check("botão direito no capacete da mochila equipa", gear.get_at(HEAD) == HELMET)
	head_slot.hovered.emit(head_slot)
	check("passar o mouse mostra a ficha do item e a ação no rodapé", menu.sheet.visible and menu.sheet.item == HELMET and menu._name.text == HELMET.display_name and menu._desc.text == "· botão direito: desequipar")
	head_slot.unhovered.emit(head_slot)
	check("ao sair do item a ficha some e o rodapé volta à dica", not menu.sheet.visible and menu._name.text == "" and menu._desc.text.begins_with("Arraste"))
	check("slots compactos de 20 px com ícone de 16", menu.gear_slots.all(func(sl): return sl.size == ItemSlot.SIZE) and menu.bag_slots[0]._icon.size == Vector2(16, 16))
	check("4 abas: mochila, diário, status, crafting", menu.TABS.map(func(t): return t[0]) == [&"bag", &"journal", &"status", &"crafting"])
	menu.select_tab(1)
	check("aba Diário mostra a página futura e esconde a mochila", menu._tab_title.text == "DIÁRIO" and menu.pages[&"journal"].visible and not menu.pages[&"bag"].visible and not menu._bag_count.visible and menu._desc.text == "Missões e anotações da run")
	var tab_click := InputEventMouseButton.new()
	tab_click.button_index = MOUSE_BUTTON_LEFT
	tab_click.pressed = true
	menu._panel.get_children().filter(func(c): return c.has_meta("tab") and c.get_meta("tab") == 0)[0].gui_input.emit(tab_click)
	check("clicar na aba Mochila volta para ela", menu.tab == 0 and menu.pages[&"bag"].visible and menu._tab_title.text == "MOCHILA")

	# 4b. I2: resposta ao equipar (destinos acesos, recusa com motivo, duplo clique, som, trava).
	bag.add(BANDAGE)
	var b_slot: ItemSlot = menu.bag_slots[_index(bag, BANDAGE)]
	b_slot.force_drag({"slot": b_slot}, null)
	check("ao arrastar a bandagem, a cabeça recusa e a mochila aceita", head_slot.drop_state == ItemSlot.Drop.REJECT and menu.bag_slots[5].drop_state == ItemSlot.Drop.ACCEPT and b_slot.drop_state == ItemSlot.Drop.NONE)
	root.gui_cancel_drag()
	await process_frame
	check("ao soltar, os slots voltam ao normal", head_slot.drop_state == ItemSlot.Drop.NONE and head_slot.modulate == Color.WHITE)
	menu._reject(b_slot, head_slot)
	check("recusa explica o motivo (\"%s\") e toca o som" % menu._name.text, menu._name.text == "Bandagem não vai em capacete" and menu._audio.stream == menu.reject_sound)
	player.health.current = player.health.maximum
	menu.activate(b_slot)
	check("bandagem com a vida cheia avisa e não gasta", menu._name.text == "Vida cheia" and bag.count(&"bandage") == 1)
	for i in 8:
		bag.add(BANDAGE)
	menu.activate(head_slot)
	check("desequipar com a mochila cheia avisa", menu._name.text == "Mochila cheia" and gear.get_at(HEAD) == HELMET)
	bag.clear()
	var dbl := InputEventMouseButton.new()
	dbl.button_index = MOUSE_BUTTON_LEFT
	dbl.pressed = true
	dbl.double_click = true
	head_slot._gui_input(dbl)
	check("duplo clique desequipa como o botão direito", gear.get_at(HEAD) == null and bag.count(&"helmet") == 1)
	menu._transfer(menu.bag_slots[_index(bag, HELMET)], head_slot)
	check("equipar toca o som do item e o ícone pulsa", gear.get_at(HEAD) == HELMET and menu._audio.stream == HELMET.equip_sound and head_slot._icon.scale.x > 1.0)
	var gun_slot: ItemSlot = _gear_slot(menu, FIREARM)
	player.firearm.reloading = true
	check("na recarga a arma de fogo trava e avisa", gun_slot.locked and gun_slot._get_drag_data(Vector2.ZERO) == null and menu._name.text == "Recarregando: espere a arma")
	player.firearm.reloading = false
	check("e destrava depois", not gun_slot.locked)

	# 4c. I3: números do item, comparação com o equipado, munição no slot, mochila cheia.
	check("números do machete na ficha", _labels(MACHETE.stats()) == ["Dano 25", "Alcance 0,9 m", "Fôlego 20/golpe", "Espera 0,5 s", "Ruído 2 m"])
	check("números da pistola", _labels(PISTOL.stats()) == ["Dano 40", "Pente 12", "Alcance 10 m", "Recarga 1,5 s", "Ruído 10 m"])
	check("bandagem e capacete", _labels(BANDAGE.stats()) == ["Cura +30"] and HELMET.stats()[0].text.contains("sem efeito"))
	var axe := WeaponItem.new()
	axe.display_name = "Machado"
	axe.slot = MELEE
	var axe_data: MeleeData = MACHETE.weapon.duplicate()
	axe_data.damage = 45.0
	axe_data.cooldown = 0.8
	axe.weapon = axe_data
	bag.clear()
	bag.add(axe)
	var axe_slot: ItemSlot = menu.bag_slots[0]
	axe_slot.hovered.emit(axe_slot)
	var diffs: Dictionary = _diff_labels(menu.sheet)
	check("ficha compara com o machete equipado (%s)" % diffs, menu.sheet.compare_to == MACHETE and diffs.get("+20") == ItemSheet.BETTER and diffs.get("+0,3") == ItemSheet.WORSE)
	check("rodapé avisa a troca ao equipar", menu._desc.text == "· botão direito: trocar")
	check("ficha fica dentro da tela", menu.root.get_global_rect().encloses(menu.sheet.get_global_rect()))
	var gun_ammo: String = menu._ammo.text
	check("munição embaixo do slot da pistola (%s)" % gun_ammo, gun_ammo == "%d|%d" % [player.firearm.ammo, player.firearm.reserve])
	player.firearm.reloading = true
	check("e REC na recarga", menu._ammo.text == "REC")
	player.firearm.reloading = false
	for i in 8:
		bag.add(BANDAGE)
	check("mochila cheia muda a cor do contador", menu._bag_count.get_theme_color("font_color") == menu.WARN)
	bag.clear()
	check("e volta ao normal", menu._bag_count.get_theme_color("font_color") == menu.DIM)

	menu._unhandled_input(_key(KEY_ESCAPE))
	check("Esc fecha e devolve o controle", not menu.is_open() and not player.input_locked)
	check("e a linha da HUD volta", main.get_node("HUD/Inventory").visible)

	# 4d. I5: saque pela tela. O móvel abre ao lado da mochila; pega um a um, guarda, pega tudo.
	var crate: Node = load("res://scenes/props/loot_container.tscn").instantiate()
	crate.id = &"teste_saque"
	crate.label = "Armário"
	crate.table = LootTable.new()
	main.add_child(crate)
	var stash: Inventory = rs.loot.of(&"teste_saque", crate.table)
	stash.add(BANDAGE)
	stash.add(AMMO)
	stash.add(VEST)
	gear.put(BODY, null)
	bag.clear()
	var looted0: int = rs.stats.looted
	crate.interact(player)
	check("F no móvel abre o menu com o conteúdo ao lado", menu.is_open() and menu.looting == crate and menu._loot_box.visible and menu.loot_slots[0].item() == BANDAGE and menu._loot_title.text == "ARMÁRIO")
	check("o painel abre espaço para o móvel", menu._panel.position == menu.PANEL_LOOTING)
	menu.activate(menu.loot_slots[0])
	check("botão direito pega a bandagem", bag.count(&"bandage") == 1 and stash.get_at(0) == null and rs.stats.looted == looted0 + 1)
	check("o bloco do móvel se apaga na hora", menu.loot_slots[0]._icon.texture == null and menu.loot_slots[0]._shown == null)
	var reserve0: int = player.firearm.reserve
	menu._transfer(menu.loot_slots[1], menu.bag_slots[5])
	check("munição vai direto para a reserva, sem ocupar bloco", player.firearm.reserve == reserve0 + 6 and bag.get_at(5) == null and stash.get_at(1) == null)
	menu.loot_slots[2].hovered.emit(menu.loot_slots[2])
	check("ficha do colete no móvel e rodapé com pegar", menu.sheet.item == VEST and menu._desc.text == "· botão direito: pegar")
	menu._transfer(menu.bag_slots[_index(bag, BANDAGE)], menu.loot_slots[4])
	check("dá para guardar coisas no móvel", stash.get_at(4) == BANDAGE and bag.count(&"bandage") == 0)
	menu._unhandled_input(_key(KEY_F))
	check("F pega tudo o que sobrou", stash.is_empty() and bag.count(&"vest") == 1 and bag.count(&"bandage") == 1 and menu._name.text.begins_with("Pegou"))
	check("e os blocos do móvel ficam vazios na tela", menu.loot_slots.all(func(sl): return sl._shown == null))
	check("móvel vazio fica apagado", crate.is_looted() and crate.modulate.r < 1.0)
	menu.close()
	check("fechar volta o painel e esconde o móvel", not menu._loot_box.visible and menu._panel.position == menu.PANEL.position and menu.looting == null and not player.input_locked)
	crate.queue_free()

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


func _labels(stats: Array[Dictionary]) -> Array:
	return stats.map(func(s): return "%s %s" % [s.label, s.text])


# Textos de diferença na ficha ("+20") -> cor.
func _diff_labels(sheet: Control) -> Dictionary:
	var out := {}
	for c in sheet.get_children():
		if c is Label and not c.is_queued_for_deletion() and (c.text.begins_with("+") or c.text.begins_with("-")) and c.has_meta("diff"):
			out[c.text] = c.get_theme_color("font_color")
	return out


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
