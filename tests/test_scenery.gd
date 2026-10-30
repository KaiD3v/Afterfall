# Checagem do cenário. Interior (gerado por tools/build_interior.gd): colisão vinda do mapa
# (camada Walls), parede com face, pisos e móveis como containers. Bairro (editado à mão no
# editor desde a R7): só regras que valem para qualquer edição: borda fechada, chão sem buraco,
# props na ordem de profundidade e portas com destino válido.
# Rodar: godot --headless --path . --fixed-fps 60 --script res://tests/test_scenery.gd
extends SceneTree

const BUILDER := "res://tools/build_interior.gd"
var failed := false


func _initialize() -> void:
	var hood: Node2D = load("res://scenes/world/neighborhood.tscn").instantiate()
	var house: Node2D = load("res://scenes/world/house_interior.tscn").instantiate()
	root.add_child(hood)
	root.add_child(house)
	_run.call_deferred(hood, house)


func _run(hood: Node2D, house: Node2D) -> void:
	await physics_frame
	var builder: GDScript = load(BUILDER)
	var inner: Array = builder.read_map(builder.INTERIOR_MAP)

	# 1. Casa: toda célula sólida do mapa tem o tile invisível de colisão; chão não.
	var walls: TileMapLayer = house.get_node("Walls")
	var bad := 0
	for y in inner.size():
		for x in inner[y].length():
			bad += int((walls.get_cell_source_id(Vector2i(x, y)) == 1) != (inner[y][x] in builder.SOLIDS))
	check("casa: colisão igual ao mapa (%d células erradas)" % bad, bad == 0)

	# 2. Casa: tiles de arte pelos vizinhos.
	var names := _names("res://assets/sprites/d/interior-tiles.json")
	var g: TileMapLayer = house.get_node("Ground")
	check("parede de cima com face", _tile(g, names, Vector2i(1, 0)) == "wall_face")
	check("janela na parede de cima", _tile(g, names, Vector2i(3, 0)) == "window")
	check("parede lateral só com topo", _tile(g, names, Vector2i(0, 4)) == "wall_cap")
	check("porta de saída", _tile(g, names, Vector2i(9, 8)) == "door")
	check("cozinha de azulejo, sala de madeira", _tile(g, names, Vector2i(2, 4)).begins_with("tile") and _tile(g, names, Vector2i(10, 6)).begins_with("wood"))
	check("casa: piso de madeira e ambiente próprio", house.surface == &"wood" and house.ambience != null)

	# 3. Bairro, regras que valem para qualquer edição no editor.
	var ground: TileMapLayer = hood.get_node("Ground")
	var ground_hd: TileMapLayer = hood.get_node("GroundHD")
	var hood_walls: TileMapLayer = hood.get_node("Walls")
	var rect := ground.get_used_rect()
	var open_edge := []
	var holes := []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var edge := x == rect.position.x or y == rect.position.y or x == rect.end.x - 1 or y == rect.end.y - 1
			if edge and hood_walls.get_cell_source_id(cell) != 1:
				open_edge.append(cell)
			if ground.get_cell_source_id(cell) == -1 or ground_hd.get_cell_source_id(cell) == -1:
				holes.append(cell)
	check("bairro: borda fechada (abertas: %s)" % [open_edge.slice(0, 5)], open_edge.is_empty())
	check("bairro: chão sem buraco, nas duas camadas (buracos: %s)" % [holes.slice(0, 5)], holes.is_empty())
	check("bairro: piso da rua e ambiente próprio", hood.surface == &"street" and hood.ambience != null)
	check("bairro: ponto de nascimento", hood.get_node_or_null("PlayerSpawn") is Marker2D)
	var props: Node2D = hood.get_node("Props")
	check("props ordenados por altura, todos com sprite", props.y_sort_enabled and props.get_children().all(func(p): return p is Sprite2D and p.texture != null))
	var doors := hood.find_children("*", "Node2D").filter(func(n): return n is Door)
	check("bairro: %d porta(s), todas com destino e volta" % doors.size(), not doors.is_empty() and doors.all(func(d): return d.target == "" or (ResourceLoader.exists(d.target) and d.exit_marker != null)))

	# 4. Móveis são os containers: sprite no lugar do bloco, foco em volta do móvel.
	for n in ["Geladeira", "Armario", "Mesa", "Comoda"]:
		var box: Node = house.get_node(n)
		var spr: Sprite2D = box.get_node("Sprite")
		var focus: Control = box.get_node("Focus")
		check("%s: móvel no lugar do bloco" % n, spr.texture != null and not box.get_node("Body").visible)
		check("%s: foco envolve o móvel (%s)" % [n, Rect2(focus.position, focus.size)], focus.size.y > 32 and focus.position.y + focus.size.y >= 16)

	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _names(json_path: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	var names := {}
	for f in data.frames:
		names[Vector2i(int(f.frame.x), int(f.frame.y)) / 32] = f.filename
	return names


func _tile(layer: TileMapLayer, names: Dictionary, cell: Vector2i) -> String:
	return names.get(layer.get_cell_atlas_coords(cell), "?")


func check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	failed = failed or not ok
