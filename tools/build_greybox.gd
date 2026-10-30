# Gera o bairro e o interior da casa a partir dos mapas ASCII de data/maps/, com a arte da Fase D:
#   scenes/world/neighborhood_greybox.tscn e scenes/world/house_interior.tscn
# Rodar: godot --headless --path . --script res://tools/build_greybox.gd
# ponytail: greybox descartável; quando a arte final cobrir tudo, os mapas passam a ser editados no editor.
extends SceneTree

# Mapas ASCII em data/maps/, um caractere por tile (legenda em TILES). O interior é a casa:
# cozinha de azulejo à esquerda, sala/quarto à direita, porta de saída embaixo.
const NEIGHBORHOOD_MAP := "res://data/maps/neighborhood.txt"
const INTERIOR_MAP := "res://data/maps/house_interior.txt"


# Linhas do mapa, sem linha vazia no fim. Os testes leem pelo mesmo caminho.
static func read_map(path: String) -> Array:
	var rows := []
	for line in FileAccess.get_file_as_string(path).split("
", false):
		rows.append(line.strip_edges())
	return rows

# símbolo: [cor (paleta_afterfall.gpl), sólido]
const TILES := {
	".": [Color8(36, 42, 54), false],     # asfalto
	"z": [Color8(110, 117, 130), false],  # faixa de pedestre
	"k": [Color8(142, 148, 158), false],  # azulejo
	"+": [Color8(20, 24, 32), true],      # janela na parede
	"P": [Color8(89, 64, 46), true],      # poste caído
	"-": [Color8(110, 117, 130), false],  # calçada
	",": [Color8(54, 61, 74), false],     # terreno
	"_": [Color8(89, 64, 46), false],     # piso de madeira
	"#": [Color8(20, 24, 32), true],      # limite / parede
	"F": [Color8(89, 64, 46), true],      # cerca
	"C": [Color8(138, 66, 40), true],     # carro destruído
	"V": [Color8(66, 82, 58), true],      # vegetação
	"H": [Color8(184, 188, 194), true],   # casa
	"D": [Color8(133, 102, 74), true],    # porta
	"G": [Color8(184, 98, 52), true],     # posto
	"W": [Color8(46, 74, 107), true],     # oficina
	"X": [Color8(54, 61, 74), true],      # sólido sob um sprite de prédio (sem contorno)
}

# Prédios: símbolo -> [sprite, canto superior esquerdo do bloco, rótulo]. Sem sprite, fica o bloco colorido.
const BUILDINGS := {
	"H": ["res://assets/sprites/m1/house.png", Vector2i(9, 9), "CASA"],
	"G": ["res://assets/sprites/m5/gas-station.png", Vector2i(46, 4), "POSTO"],
	"W": ["res://assets/sprites/m5/workshop.png", Vector2i(10, 22), "OFICINA"],
}

# Containers do interior: [id, rótulo, tabela, tile, cor greybox]
const CONTAINERS := [
	[&"geladeira", "Geladeira", "res://data/loot/geladeira.tres", Vector2i(1, 2), Color8(184, 188, 194)],
	[&"armario", "Armário", "res://data/loot/armario.tres", Vector2i(4, 2), Color8(133, 102, 74)],
	[&"mesa", "Mesa", "res://data/loot/mesa.tres", Vector2i(10, 4), Color8(89, 64, 46)],
	[&"comoda", "Cômoda", "res://data/loot/comoda.tres", Vector2i(13, 1), Color8(133, 102, 74)],
]

# Arte da Fase D. Sheet que ainda não existe é pulada: o mapa fica no greybox colorido.
const STREET_TILES := "res://assets/sprites/d/street-tiles.json"
const STREET_TILES_HD := "res://assets/sprites/d/street-tiles-hd.json"
const STREET_PROPS := "res://assets/sprites/d/street-props.json"
const INTERIOR_TILES := "res://assets/sprites/d/interior-tiles.json"
const INTERIOR_TILES_HD := "res://assets/sprites/d/interior-tiles-hd.json"
const FURNITURE := "res://assets/sprites/d/furniture.json"
# Container -> móvel da sheet de móveis
const FURNITURE_OF := {&"geladeira": "fridge", &"armario": "cabinet", &"mesa": "table", &"comoda": "dresser"}
# Chão de cada símbolo e sorteio de variantes: [tile, peso]
const VARIANTS := {
	".": [["asphalt_0", 60], ["asphalt_1", 20], ["asphalt_2", 14], ["asphalt_veg", 6]],
	",": [["terrain_0", 60], ["terrain_1", 25], ["terrain_2", 15]],
	"_": [["wood_0", 60], ["wood_1", 25], ["wood_2", 15]],
	"k": [["tile_0", 60], ["tile_1", 25], ["tile_2", 15]],
}
const GROUND := ".z-,_k"  # símbolos de chão; o resto é sólido e herda o chão do vizinho
const GRASS_CHANCE := 5    # % dos tiles de terreno com grama alta (decoração, dá para passar)

var DOOR: PackedScene  # carregados em _initialize, depois dos autoloads (RunState)
var CONTAINER: PackedScene
const T := World.TILE
const H := T / 2.0
const SOLID := 1  # source do tile invisível com colisão (camada Walls)

var tileset: TileSet
var tileset_hd: TileSet
var keys: Array
var sheets := {}  # json -> {texture, rects: nome -> Rect2i, meta, source}


func _initialize() -> void:
	DOOR = load("res://scenes/props/door.tscn")
	CONTAINER = load("res://scenes/props/loot_container.tscn")
	keys = TILES.keys()
	for path in [STREET_TILES, STREET_TILES_HD, STREET_PROPS, INTERIOR_TILES, INTERIOR_TILES_HD, FURNITURE]:
		if FileAccess.file_exists(path):
			sheets[path] = _sheet(path)
	tileset = _tileset()
	tileset_hd = _tileset_hd()

	# Bairro: prédio com sprite vira sólido sem cor, menos a fileira de cima do bloco, que fica
	# livre para o jogador passar atrás do telhado (3/4). Porta da casa na frente do tile D.
	var hood_map := read_map(NEIGHBORHOOD_MAP)
	var inner_map := read_map(INTERIOR_MAP)
	var map := hood_map.duplicate()
	for ch in BUILDINGS:
		if not ResourceLoader.exists(BUILDINGS[ch][0]):
			continue
		var top: int = BUILDINGS[ch][1].y
		for y in map.size():
			map[y] = map[y].replace(ch, "," if y == top else "X")
			if ch == "H":
				map[y] = map[y].replace("D", "X")
	var hood := _scene("Neighborhood", map, false)
	for ch in BUILDINGS:
		var b: Array = BUILDINGS[ch]
		if ResourceLoader.exists(b[0]):
			var s := Sprite2D.new()
			s.name = b[2].capitalize() + "Sprite"
			s.texture = load(b[0])
			s.scale = Vector2.ONE * World.ART_SCALE
			s.centered = false
			s.offset = Vector2(0, -s.texture.get_height())  # origem na base: ordena com quem passa na frente
			var w_tiles := 3 if ch == "H" else 4
			var world_w := s.texture.get_width() * World.ART_SCALE
			var bx: float = b[1].x * T + (w_tiles * T - world_w) * 0.5
			var by: float = (b[1].y + 3) * T
			s.position = Vector2(bx, by)
			_add(hood, s)
		else:
			var l := Label.new()
			l.name = "Label" + b[2].capitalize()
			l.text = b[2]
			l.position = Vector2((b[1] - Vector2i(0, 1)) * T) + Vector2(2, 4)
			l.add_theme_font_size_override("font_size", 10)
			l.add_theme_color_override("font_color", Color8(227, 154, 59))
			_add(hood, l)
	if sheets.has(STREET_PROPS):
		_props(hood, map)
	_atmosphere(hood, false)
	var door_tile := _find(hood_map, "D")
	_door(hood, "HouseDoor", "enter_house", _center(door_tile) + Vector2(0, 28))
	_marker(hood, "HouseExit", _center(door_tile) + Vector2(0, 32))
	_marker(hood, "PlayerSpawn", _center(Vector2i(10, 14)))  # calçada em frente ao portão
	_save(hood, "res://scenes/world/neighborhood_greybox.tscn")

	# Interior: porta de saída acima do tile D; containers nos cômodos (o móvel é o container).
	var house := _scene("HouseInterior", inner_map, true)
	_atmosphere(house, true)
	door_tile = _find(inner_map, "D")
	_door(house, "ExitDoor", "exit_house", _center(door_tile) + Vector2(0, -28))
	_marker(house, "PlayerSpawn", _center(door_tile) + Vector2(0, -32))
	for c in CONTAINERS:
		var box: StaticBody2D = CONTAINER.instantiate()
		box.name = String(c[0]).capitalize()
		box.id = c[0]
		box.label = c[1]
		box.table = load(c[2])
		box.position = _center(c[3])
		box.color = c[4]
		if sheets.has(FURNITURE):
			box.sprite = _atlas(FURNITURE, FURNITURE_OF[c[0]])
		_add(house, box)
	_save(house, "res://scenes/world/house_interior.tscn")
	quit()


func _sheet(path: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var rects := {}
	for f in data.frames:
		rects[f.filename] = Rect2i(f.frame.x, f.frame.y, f.frame.w, f.frame.h)
	return {"texture": load(path.get_base_dir().path_join(data.meta.image)), "rects": rects, "meta": data.meta}


func _atlas(sheet: String, frame: String) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = sheets[sheet].texture
	a.region = sheets[sheet].rects[frame]
	return a


# Source 0: greybox colorido. Source 1: tile invisível com colisão, na camada Walls (a colisão
# vem do mapa, não da arte). Demais: uma por sheet de tiles, cada tile com as versões giradas.
func _tileset() -> TileSet:
	var img := Image.create(T * keys.size(), T, false, Image.FORMAT_RGBA8)
	for i in keys.size():
		var c: Color = TILES[keys[i]][0]
		img.fill_rect(Rect2i(i * T, 0, T, T), c)
		if TILES[keys[i]][1] and keys[i] != "X":  # contorno de 1 px nos sólidos, para ler o bloco
			var o := Color8(20, 24, 32) if c != Color8(20, 24, 32) else Color8(36, 42, 54)
			for k in T:
				for p in [Vector2i(i * T + k, 0), Vector2i(i * T + k, T - 1), Vector2i(i * T, k), Vector2i(i * T + T - 1, k)]:
					img.set_pixelv(p, o)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	for i in keys.size():
		src.create_tile(Vector2i(i, 0))

	var solid := TileSetAtlasSource.new()
	solid.texture = ImageTexture.create_from_image(Image.create(T, T, false, Image.FORMAT_RGBA8))
	solid.texture_region_size = Vector2i(T, T)
	ts.add_source(solid, SOLID)
	solid.create_tile(Vector2i.ZERO)
	var td := solid.get_tile_data(Vector2i.ZERO, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-H, -H), Vector2(H, -H), Vector2(H, H), Vector2(-H, H)]))

	for path in [STREET_TILES, INTERIOR_TILES]:
		if not sheets.has(path):
			continue
		var art := TileSetAtlasSource.new()
		art.texture = sheets[path].texture
		art.texture_region_size = Vector2i(T, T)
		sheets[path].source = ts.add_source(art)
		for r in sheets[path].rects.values():
			var at := Vector2i(r.position) / T
			art.create_tile(at)
			# alternativas: 1 espelho vertical, 2 transposto, 3 transposto + espelho horizontal.
			# O Godot transpõe antes de espelhar: borda de baixo -> 1 em cima, 2 à direita, 3 à esquerda.
			for flags in [[false, true, false], [false, false, true], [true, false, true]]:
				var alt := art.create_alternative_tile(at)
				var d := art.get_tile_data(at, alt)
				d.flip_h = flags[0]
				d.flip_v = flags[1]
				d.transpose = flags[2]
	return ts


func _tileset_hd() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(128, 128)
	for path in [STREET_TILES_HD, INTERIOR_TILES_HD]:
		if not sheets.has(path):
			continue
		var art := TileSetAtlasSource.new()
		art.texture = sheets[path].texture
		art.texture_region_size = Vector2i(128, 128)
		sheets[path].source = ts.add_source(art)
		for r in sheets[path].rects.values():
			var at := Vector2i(r.position) / 128
			art.create_tile(at)
			for flags in [[false, true, false], [false, false, true], [true, false, true]]:
				var alt := art.create_alternative_tile(at)
				var d := art.get_tile_data(at, alt)
				d.flip_h = flags[0]
				d.flip_v = flags[1]
				d.transpose = flags[2]
	return ts


func _scene(scene_name: String, map: Array, interior: bool) -> Node2D:
	var scene := Node2D.new()
	scene.name = scene_name
	scene.y_sort_enabled = true  # prédios e props ordenam pela base junto com jogador e zumbis
	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = tileset
	layer.z_index = -2  # chão lógico por baixo
	_add(scene, layer)
	var layer_hd := TileMapLayer.new()
	layer_hd.name = "GroundHD"
	layer_hd.tile_set = tileset_hd
	layer_hd.scale = Vector2.ONE * World.ART_SCALE
	layer_hd.z_index = -1  # chão 4x HD por cima do Ground lógico
	_add(scene, layer_hd)
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = tileset
	_add(scene, walls)
	var under := _ground_under(map)
	var sheet := INTERIOR_TILES if interior else STREET_TILES
	var sheet_hd := INTERIOR_TILES_HD if interior else STREET_TILES_HD
	for y in map.size():
		for x in map[y].length():
			var ch: String = map[y][x]
			var cell := Vector2i(x, y)
			if TILES[ch][1]:
				walls.set_cell(cell, SOLID, Vector2i.ZERO)
			var pick := _art_cell(map, under, cell, interior) if sheets.has(sheet) else []
			if pick.is_empty():
				layer.set_cell(cell, 0, Vector2i(keys.find(ch), 0))
			else:
				layer.set_cell(cell, sheets[sheet].source, Vector2i(sheets[sheet].rects[pick[0]].position) / T, pick[1])
				if sheets.has(sheet_hd):
					layer_hd.set_cell(cell, sheets[sheet_hd].source, Vector2i(sheets[sheet_hd].rects[pick[0]].position) / 128, pick[1])
	return scene


# Tile de arte [nome, alternativa] para a célula; [] deixa o greybox. Sólido sem arte própria
# (carro, cerca, borda do mapa, base de prédio) mostra o chão em volta, e o prop vai por cima.
func _art_cell(map: Array, under: Dictionary, cell: Vector2i, interior: bool) -> Array:
	var ch: String = map[cell.y][cell.x]
	if interior and ch in "#+D":
		if ch == "D":
			return ["door", 0]
		if ch == "+":
			return ["window", 0]
		var below := cell + Vector2i.DOWN
		var floor_below: bool = below.y < map.size() and map[below.y][below.x] in GROUND
		return ["wall_face" if floor_below else "wall_cap", 0]
	if not TILES[ch][1]:
		pass
	elif ch == "X" or ch == "#" or sheets.has(STREET_PROPS):
		ch = under[cell]
	else:
		return []  # prop sem sheet ainda: bloco colorido
	match ch:
		"z":  # listras na direção da rua: asfalto puro à esquerda é rua horizontal, transposto
			return ["crosswalk", 2 if _ground(map, under, cell + Vector2i.LEFT) == "." else 0]
		"-":
			for side in [[Vector2i.DOWN, 0], [Vector2i.UP, 1], [Vector2i.RIGHT, 2], [Vector2i.LEFT, 3]]:
				if _ground(map, under, cell + side[0]) in ".z":
					return ["sidewalk_curb", side[1]]
			return ["sidewalk", 0]
	return [_variant(ch, cell), 0]


func _ground(map: Array, under: Dictionary, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= map.size() or cell.x < 0 or cell.x >= map[cell.y].length():
		return ""
	var ch: String = map[cell.y][cell.x]
	return ch if ch in GROUND else under.get(cell, ",")


# Chão debaixo de cada célula sólida: o mais comum entre os vizinhos, espalhando a partir do
# chão de verdade. Sem vizinho de chão (canto do mapa), terreno.
func _ground_under(map: Array) -> Dictionary:
	var under := {}
	var todo := []
	for y in map.size():
		for x in map[y].length():
			if not map[y][x] in GROUND:
				todo.append(Vector2i(x, y))
	while not todo.is_empty():
		var found := {}
		for cell in todo:
			var count := {}
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = cell + d
				if n.y < 0 or n.y >= map.size() or n.x < 0 or n.x >= map[n.y].length():
					continue
				var g: String = map[n.y][n.x] if map[n.y][n.x] in GROUND else under.get(n, "")
				if g == "z":
					g = "."
				if g != "":
					count[g] = count.get(g, 0) + 1
			if not count.is_empty():
				var best: String = count.keys()[0]
				for g in count:
					if count[g] > count[best]:
						best = g
				found[cell] = best
		if found.is_empty():
			for cell in todo:
				found[cell] = ","
		under.merge(found)
		todo = todo.filter(func(c): return not found.has(c))
	return under


# Sorteio fixo por posição: o mapa sai igual a cada build.
func _roll(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663) % 100


func _variant(ch: String, cell: Vector2i) -> String:
	var r := _roll(cell)
	for v in VARIANTS[ch]:
		r -= v[1]
		if r < 0:
			return v[0]
	return VARIANTS[ch][0][0]


# Props da rua por cima do chão, na ordem de profundidade. A colisão continua na camada Walls.
# Carros: 2 C seguidos; 3 ou mais em linha é barricada fechando a rua.
func _props(hood: Node2D, map: Array) -> void:
	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	_add(hood, props)
	var at := func(c: Vector2i) -> String:
		return map[c.y][c.x] if c.y >= 0 and c.y < map.size() and c.x >= 0 and c.x < map[c.y].length() else ""
	for y in map.size():
		for x in map[y].length():
			var c := Vector2i(x, y)
			match map[y][x]:
				"C":
					var h := _run(map, c, Vector2i.RIGHT)
					var v := _run(map, c, Vector2i.DOWN)
					if h == 2 and at.call(c + Vector2i.LEFT) != "C":
						_prop(props, "car_h", c)
					elif v == 2 and at.call(c + Vector2i.UP) != "C":
						_prop(props, "car_v", c)
					elif h != 2 and v != 2:
						_prop(props, "barricade", c)
				"P":
					if at.call(c + Vector2i.LEFT) != "P":
						_prop(props, "fallen_pole", c)
				"V":
					_prop(props, "bush", c)
				"F":
					var fh: bool = at.call(c + Vector2i.LEFT) == "F" or at.call(c + Vector2i.RIGHT) == "F"
					var fv: bool = at.call(c + Vector2i.UP) == "F" or at.call(c + Vector2i.DOWN) == "F"
					_prop(props, "fence_h" if fh and not fv else ("fence_v" if fv and not fh else "fence_post"), c)
				",":
					if _roll(c + Vector2i(7, 3)) < GRASS_CHANCE:
						_prop(props, "tall_grass", c)


# Tamanho da fileira de símbolos iguais que passa pela célula, na direção dada.
func _run(map: Array, cell: Vector2i, dir: Vector2i) -> int:
	var ch: String = map[cell.y][cell.x]
	var n := 1
	for s in [dir, -dir]:
		var p: Vector2i = cell + s
		while p.y >= 0 and p.y < map.size() and p.x >= 0 and p.x < map[p.y].length() and map[p.y][p.x] == ch:
			n += 1
			p += s
	return n


# Quadro de 256×256 (escala 0.25 = 64×64 unidades) com a pegada centralizada e a base na linha 250.
func _prop(parent: Node, frame: String, cell: Vector2i) -> void:
	var fp: Array = sheets[STREET_PROPS].meta.footprint[frame]
	var s := Sprite2D.new()
	s.name = "%s_%d_%d" % [frame, cell.x, cell.y]
	s.texture = _atlas(STREET_PROPS, frame)
	s.scale = Vector2.ONE * World.ART_SCALE
	s.centered = false
	s.offset = Vector2(-128, -251)
	s.position = Vector2((cell.x + fp[0] / 2.0) * T, (cell.y + fp[1]) * T)
	_add(parent, s)


func _atmosphere(scene: Node2D, interior: bool) -> void:
	var mod := CanvasModulate.new()
	mod.name = "AtmosphereModulate"
	mod.color = Color(0.74, 0.77, 0.84, 1.0) if interior else Color(0.62, 0.68, 0.78, 1.0)
	_add(scene, mod)
	if not ResourceLoader.exists("res://assets/sprites/fx/point_light.png"):
		return
	var ltex: Texture2D = load("res://assets/sprites/fx/point_light.png")
	var lights := [
		["KitchenLight", Vector2(2.5 * T, 4.0 * T), Color(0.85, 0.90, 0.96, 1.0), 0.55, 0.9],
		["RoomLight", Vector2(10.0 * T, 4.5 * T), Color(0.95, 0.72, 0.42, 1.0), 0.70, 1.2],
	] if interior else [
		["HousePorchLight", Vector2(10.5 * T, 12.2 * T), Color(0.96, 0.68, 0.32, 1.0), 0.85, 1.1],
		["GasStationLight", Vector2(48.0 * T, 6.8 * T), Color(0.98, 0.66, 0.28, 1.0), 1.15, 1.5],
		["WorkshopLight", Vector2(12.0 * T, 24.8 * T), Color(0.95, 0.65, 0.30, 1.0), 0.85, 1.2],
		["CrossingGlow", Vector2(29.5 * T, 16.5 * T), Color(0.65, 0.76, 0.92, 1.0), 0.45, 1.8],
	]
	for spec in lights:
		var pt := PointLight2D.new()
		pt.name = spec[0]
		pt.position = spec[1]
		pt.color = spec[2]
		pt.energy = spec[3]
		pt.texture = ltex
		pt.texture_scale = spec[4]
		_add(scene, pt)


func _add(scene: Node, child: Node) -> void:
	scene.add_child(child)
	child.owner = scene if scene.owner == null else scene.owner  # dono é a raiz, para salvar


func _door(scene: Node, door_name: String, action: String, pos: Vector2) -> void:
	var d: Node2D = DOOR.instantiate()
	d.name = door_name
	d.action = action
	d.position = pos
	_add(scene, d)


func _marker(scene: Node, marker_name: String, pos: Vector2) -> void:
	var m := Marker2D.new()
	m.name = marker_name
	m.position = pos
	_add(scene, m)


func _find(map: Array, ch: String) -> Vector2i:
	for y in map.size():
		var x: int = map[y].find(ch)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func _center(tile: Vector2i) -> Vector2:
	return Vector2(tile * T) + Vector2(H, H)


func _save(scene: Node, path: String) -> void:
	var packed := PackedScene.new()
	packed.pack(scene)
	print("save %s: %d" % [path, ResourceSaver.save(packed, path)])
	scene.free()
