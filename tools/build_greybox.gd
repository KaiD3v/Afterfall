# Gera o bairro e o interior da casa a partir dos mapas ASCII abaixo:
#   scenes/world/neighborhood_greybox.tscn e scenes/world/house_interior.tscn
# Rodar: godot --headless --path . --script res://tools/build_greybox.gd
# ponytail: greybox descartável; quando a arte final cobrir tudo, os mapas passam a ser editados no editor.
extends SceneTree

const NEIGHBORHOOD := [
	"############################################################",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-CCCC-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,VV,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,V,,,,-....-,,,V,,,,,,,,,GGGG,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,GGGG,,,,,,,,,#",
	"#,,,,FFFFFFFFFFF,,,,,,,,,,,-....-,,,,,,,,,,,,,GGGG,,,,,,,,,#",
	"#,,,,F,,,,,,,,,F,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,F,,,,,,,,,F,,,,,,,,,,,-.C..-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,F,,,HHH,,,F,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,F,,,HHH,,,F,,,,,,,V,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,F,,,HDH,,,F,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,F,,,,,,,,,F,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,V,,,#",
	"#,,,,FFFFF,FFFFF,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#---------------------------....---------------------------#",
	"#C.........................-....-.........................C#",
	"#C..................CC.....-....-.........................C#",
	"#C.........................-....-.....C...................C#",
	"#C.........................-....-.........................C#",
	"#---------------------------....---------------------------#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,WWWW,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,WWWW,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,WWWW,,,,,,,,,,,,,-..C.-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,VV,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,V,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,V,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-CCCC-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"############################################################",
]

# Casa por dentro: cozinha à esquerda, sala/quarto à direita, porta de saída embaixo.
const INTERIOR := [
	"###############",
	"#_____#_______#",
	"#_____#_______#",
	"#_____________#",
	"#_____#_______#",
	"#_____#_______#",
	"#_____#_______#",
	"#_____#_______#",
	"#########D#####",
]

# símbolo: [cor (paleta_afterfall.gpl), sólido]
const TILES := {
	".": [Color8(43, 43, 51), false],     # asfalto
	"-": [Color8(110, 110, 118), false],  # calçada
	",": [Color8(74, 74, 82), false],     # terreno
	"_": [Color8(110, 74, 50), false],    # piso de madeira
	"#": [Color8(26, 26, 46), true],      # limite / parede
	"F": [Color8(92, 70, 50), true],      # cerca
	"C": [Color8(107, 58, 31), true],     # carro destruído
	"V": [Color8(63, 107, 52), true],     # vegetação
	"H": [Color8(200, 200, 196), true],   # casa
	"D": [Color8(155, 122, 84), true],    # porta
	"G": [Color8(208, 138, 74), true],    # posto
	"W": [Color8(52, 73, 94), true],      # oficina
	"X": [Color8(74, 74, 82), true],      # sólido sob um sprite de prédio (sem contorno)
}

# Prédios: símbolo -> [sprite, canto superior esquerdo do bloco, rótulo]. Sem sprite, fica o bloco colorido.
const BUILDINGS := {
	"H": ["res://assets/sprites/m1/house.png", Vector2i(9, 9), "CASA"],
	"G": ["res://assets/sprites/m5/gas-station.png", Vector2i(46, 4), "POSTO"],
	"W": ["res://assets/sprites/m5/workshop.png", Vector2i(10, 22), "OFICINA"],
}

# Containers do interior: [id, rótulo, tabela, tile, cor greybox]
const CONTAINERS := [
	[&"geladeira", "Geladeira", "res://data/loot/geladeira.tres", Vector2i(1, 2), Color8(200, 200, 196)],
	[&"armario", "Armário", "res://data/loot/armario.tres", Vector2i(4, 2), Color8(155, 122, 84)],
	[&"mesa", "Mesa", "res://data/loot/mesa.tres", Vector2i(10, 4), Color8(92, 70, 50)],
	[&"comoda", "Cômoda", "res://data/loot/comoda.tres", Vector2i(13, 1), Color8(155, 122, 84)],
]

var DOOR: PackedScene  # carregados em _initialize, depois dos autoloads (RunState)
var CONTAINER: PackedScene
const T := 32
const H := T / 2.0

var tileset: TileSet
var keys: Array


func _initialize() -> void:
	DOOR = load("res://scenes/props/door.tscn")
	CONTAINER = load("res://scenes/props/loot_container.tscn")
	keys = TILES.keys()
	tileset = _tileset()

	# Bairro: prédios com sprite viram sólido sem cor; porta da casa na frente do tile D.
	var map := NEIGHBORHOOD.duplicate()
	var with_sprite := ""
	for ch in BUILDINGS:
		if ResourceLoader.exists(BUILDINGS[ch][0]):
			with_sprite += ch + ("D" if ch == "H" else "")
	for y in map.size():
		for ch in with_sprite:
			map[y] = map[y].replace(ch, "X")
	var hood := _scene("Neighborhood", map)
	for ch in BUILDINGS:
		var b: Array = BUILDINGS[ch]
		if ResourceLoader.exists(b[0]):
			var s := Sprite2D.new()
			s.name = b[2].capitalize() + "Sprite"
			s.texture = load(b[0])
			s.centered = false
			s.position = Vector2(b[1] * T)
			_add(hood, s)
		else:
			var l := Label.new()
			l.name = "Label" + b[2].capitalize()
			l.text = b[2]
			l.position = Vector2((b[1] - Vector2i(0, 1)) * T) + Vector2(2, 4)
			l.add_theme_font_size_override("font_size", 10)
			l.add_theme_color_override("font_color", Color8(232, 197, 71))
			_add(hood, l)
	var door_tile := _find(NEIGHBORHOOD, "D")
	_door(hood, "HouseDoor", "enter_house", _center(door_tile) + Vector2(0, 28))
	_marker(hood, "HouseExit", _center(door_tile) + Vector2(0, 32))
	_marker(hood, "PlayerSpawn", _center(Vector2i(10, 14)))  # calçada em frente ao portão
	_save(hood, "res://scenes/world/neighborhood_greybox.tscn")

	# Interior: porta de saída acima do tile D; containers nos cômodos.
	var house := _scene("HouseInterior", INTERIOR)
	door_tile = _find(INTERIOR, "D")
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
		_add(house, box)
	_save(house, "res://scenes/world/house_interior.tscn")
	quit()


func _tileset() -> TileSet:
	var img := Image.create(T * keys.size(), T, false, Image.FORMAT_RGBA8)
	for i in keys.size():
		var c: Color = TILES[keys[i]][0]
		img.fill_rect(Rect2i(i * T, 0, T, T), c)
		if TILES[keys[i]][1] and keys[i] != "X":  # contorno de 1 px nos sólidos, para ler o bloco
			var o := Color8(26, 26, 46) if c != Color8(26, 26, 46) else Color8(43, 43, 51)
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
	var square := PackedVector2Array([Vector2(-H, -H), Vector2(H, -H), Vector2(H, H), Vector2(-H, H)])
	for i in keys.size():
		src.create_tile(Vector2i(i, 0))
		if TILES[keys[i]][1]:
			var td := src.get_tile_data(Vector2i(i, 0), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)
	return ts


func _scene(scene_name: String, map: Array) -> Node2D:
	var scene := Node2D.new()
	scene.name = scene_name
	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = tileset
	_add(scene, layer)
	for y in map.size():
		for x in map[y].length():
			layer.set_cell(Vector2i(x, y), 0, Vector2i(keys.find(map[y][x]), 0))
	return scene


func _add(scene: Node, child: Node) -> void:
	scene.add_child(child)
	child.owner = scene


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
