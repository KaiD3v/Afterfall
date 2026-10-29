# Checagem da Fase D: colisão vinda do mapa (camada Walls), tiles de arte escolhidos pelos
# vizinhos (meio-fio, faixa, parede com face), props por cima dos sólidos e móveis como containers.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_scenery.gd
extends SceneTree

const BUILDER := "res://tools/build_greybox.gd"
var failed := false


func _initialize() -> void:
	var hood: Node2D = load("res://scenes/world/neighborhood_greybox.tscn").instantiate()
	var house: Node2D = load("res://scenes/world/house_interior.tscn").instantiate()
	root.add_child(hood)
	root.add_child(house)
	_run.call_deferred(hood, house)


func _run(hood: Node2D, house: Node2D) -> void:
	await physics_frame
	var src: String = load(BUILDER).source_code
	var map := _map(src, "NEIGHBORHOOD")
	var inner := _map(src, "INTERIOR")

	# 1. Colisão: toda célula sólida do mapa tem o tile invisível; chão não.
	for scene in [[hood, map, "bairro"], [house, inner, "casa"]]:
		var walls: TileMapLayer = scene[0].get_node("Walls")
		var bad := 0
		for y in scene[1].size():
			for x in scene[1][y].length():
				var ch: String = scene[1][y][x]
				var solid: bool = ch in "#FCVHDGWXP+"
				if ch in "HGW" and (y == 0 or scene[1][y - 1][x] != ch):
					solid = false  # fileira de cima do prédio: livre, atrás do telhado
				bad += int((walls.get_cell_source_id(Vector2i(x, y)) == 1) != solid)
		check("%s: colisão igual ao mapa (%d células erradas)" % [scene[2], bad], bad == 0)

	# 2. Tiles de arte escolhidos pelos vizinhos (só quando a sheet existe).
	var ground: TileMapLayer = hood.get_node("Ground")
	if FileAccess.file_exists("res://assets/sprites/d/street-tiles.json"):
		var names := _names("res://assets/sprites/d/street-tiles.json")
		check("calçada com rua embaixo: meio-fio", _tile(ground, names, Vector2i(10, 13 + 1)) == ["sidewalk_curb", 0])
		check("calçada com rua em cima: meio-fio espelhado", _tile(ground, names, Vector2i(10, 19)) == ["sidewalk_curb", 1])
		check("calçada da rua vertical: meio-fio de lado", _tile(ground, names, Vector2i(27, 5)) == ["sidewalk_curb", 2] and _tile(ground, names, Vector2i(32, 5)) == ["sidewalk_curb", 3])
		check("faixa na rua vertical", _tile(ground, names, Vector2i(29, 14)) == ["crosswalk", 0])
		check("faixa na rua horizontal, girada", _tile(ground, names, Vector2i(27, 16)) == ["crosswalk", 2])
		check("borda do mapa mostra o chão vizinho", _tile(ground, names, Vector2i(0, 5))[0].begins_with("terrain"))
	else:
		print("skip tiles da rua: sem street-tiles.json")
	if FileAccess.file_exists("res://assets/sprites/d/interior-tiles.json"):
		var names := _names("res://assets/sprites/d/interior-tiles.json")
		var g: TileMapLayer = house.get_node("Ground")
		check("parede de cima com face", _tile(g, names, Vector2i(1, 0))[0] == "wall_face")
		check("janela na parede de cima", _tile(g, names, Vector2i(3, 0))[0] == "window")
		check("parede lateral só com topo", _tile(g, names, Vector2i(0, 4))[0] == "wall_cap")
		check("porta de saída", _tile(g, names, Vector2i(9, 8))[0] == "door")
		check("cozinha de azulejo, sala de madeira", _tile(g, names, Vector2i(2, 4))[0].begins_with("tile") and _tile(g, names, Vector2i(10, 6))[0].begins_with("wood"))
	else:
		print("skip tiles do interior: sem interior-tiles.json")

	# 3. Props: cada sólido de rua coberto por um sprite, na ordem de profundidade.
	if FileAccess.file_exists("res://assets/sprites/d/street-props.json"):
		var props: Node2D = hood.get_node("Props")
		var count := {}
		for p in props.get_children():
			var kind: String = String(p.name).rsplit("_", true, 2)[0]
			count[kind] = count.get(kind, 0) + 1
		check("props ordenados por altura", props.y_sort_enabled)
		if FileAccess.file_exists("res://assets/sprites/d/street-tiles.json"):
			var names := _names("res://assets/sprites/d/street-tiles.json")
			check("carro no asfalto mostra asfalto embaixo", _tile(hood.get_node("Ground"), names, Vector2i(20, 16))[0].begins_with("asphalt"))
		check("2 carros na horizontal e 2 na vertical (%s)" % count, count.get("car_h", 0) == 2 and count.get("car_v", 0) == 2)
		check("barricadas fecham as 4 pontas de rua", count.get("barricade", 0) == 16)
		check("cerca inteira", count.get("fence_h", 0) + count.get("fence_v", 0) + count.get("fence_post", 0) == _count(map, "F"))
		check("arbustos e poste caído", count.get("bush", 0) == _count(map, "V") and count.get("fallen_pole", 0) == 1)
		check("grama alta espalhada", count.get("tall_grass", 0) > 20)
		var car: Sprite2D = props.get_node("car_h_20_16")
		check("carro com origem no meio da base da pegada", car.position == Vector2(21 * 32, 17 * 32))
	else:
		print("skip props: sem street-props.json")

	# 4. Móveis são os containers: sprite no lugar do bloco, foco em volta do móvel.
	if FileAccess.file_exists("res://assets/sprites/d/furniture.json"):
		for n in ["Geladeira", "Armario", "Mesa", "Comoda"]:
			var box: Node = house.get_node(n)
			var spr: Sprite2D = box.get_node("Sprite")
			var focus: Control = box.get_node("Focus")
			check("%s: móvel no lugar do bloco" % n, spr.texture != null and not box.get_node("Body").visible)
			check("%s: foco envolve o móvel (%s)" % [n, Rect2(focus.position, focus.size)], focus.size.y > 32 and focus.position.y + focus.size.y >= 16)
	else:
		print("skip móveis: sem furniture.json")

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _map(src: String, name: String) -> Array:
	var block := src.substr(src.find("const %s := [" % name))
	block = block.substr(0, block.find("]\n"))
	var rows := []
	for line in block.split("\n"):
		if line.strip_edges().begins_with("\""):
			rows.append(line.strip_edges().trim_prefix("\"").trim_suffix("\","))
	return rows


func _names(json_path: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	var names := {}
	for f in data.frames:
		names[Vector2i(int(f.frame.x), int(f.frame.y)) / 32] = f.filename
	return names


func _tile(layer: TileMapLayer, names: Dictionary, cell: Vector2i) -> Array:
	return [names.get(layer.get_cell_atlas_coords(cell), "?"), layer.get_cell_alternative_tile(cell)]


func _count(map: Array, ch: String) -> int:
	var n := 0
	for row in map:
		n += row.count(ch)
	return n


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
