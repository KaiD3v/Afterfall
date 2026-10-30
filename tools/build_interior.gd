# Gera o interior da casa (scenes/world/house_interior.tscn) a partir de data/maps/house_interior.txt,
# com a arte de assets/sprites/d. O bairro não é gerado: é editado à mão no editor do Godot
# (scenes/world/neighborhood.tscn), decisão do autor de 2026-10-29.
# Rodar: godot --headless --path . --script res://tools/build_interior.gd
extends SceneTree

# Mapa ASCII, um caractere por tile: cozinha de azulejo à esquerda, sala/quarto à direita,
# porta de saída embaixo.
const INTERIOR_MAP := "res://data/maps/house_interior.txt"
const SOLIDS := "#+D"  # parede, janela, porta; o resto é chão
const FLOORS := {  # chão de cada símbolo e sorteio de variantes: [tile, peso]
	"_": [["wood_0", 60], ["wood_1", 25], ["wood_2", 15]],  # madeira
	"k": [["tile_0", 60], ["tile_1", 25], ["tile_2", 15]],  # azulejo
}

# Containers: [id, rótulo, tabela, tile, cor greybox, móvel na sheet de móveis]
const CONTAINERS := [
	[&"geladeira", "Geladeira", "res://data/loot/geladeira.tres", Vector2i(1, 2), Color8(184, 188, 194), "fridge"],
	[&"armario", "Armário", "res://data/loot/armario.tres", Vector2i(4, 2), Color8(133, 102, 74), "cabinet"],
	[&"mesa", "Mesa", "res://data/loot/mesa.tres", Vector2i(10, 4), Color8(89, 64, 46), "table"],
	[&"comoda", "Cômoda", "res://data/loot/comoda.tres", Vector2i(13, 1), Color8(133, 102, 74), "dresser"],
]
# Luzes: [nome, posição em tiles, cor, energia, escala]
const LIGHTS := [
	["KitchenLight", Vector2(2.5, 4.0), Color(0.85, 0.90, 0.96, 1.0), 0.55, 0.9],
	["RoomLight", Vector2(10.0, 4.5), Color(0.95, 0.72, 0.42, 1.0), 0.70, 1.2],
]

const TILES := "res://assets/sprites/d/interior-tiles.json"
const TILES_HD := "res://assets/sprites/d/interior-tiles-hd.json"
const FURNITURE := "res://assets/sprites/d/furniture.json"
const AMBIENCE := "res://assets/audio/ambience/interior.ogg"
const LIGHT := "res://assets/sprites/fx/point_light.png"
const OUT := "res://scenes/world/house_interior.tscn"
const T := World.TILE
const H := T / 2.0
const HD := 128   # tile da arte HD, reduzido por World.ART_SCALE
const SOLID := 1  # source do tile invisível com colisão (camada Walls)


# Linhas do mapa, sem linha vazia no fim. Os testes leem pelo mesmo caminho.
static func read_map(path: String) -> Array:
	var rows := []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		rows.append(line.strip_edges())
	return rows


func _initialize() -> void:
	var map := read_map(INTERIOR_MAP)
	var tiles := _sheet(TILES)
	var tiles_hd := _sheet(TILES_HD)
	var furniture := _sheet(FURNITURE)

	var house: Location = load("res://scripts/world/location.gd").new()
	house.name = "HouseInterior"
	house.surface = &"wood"
	house.ambience = load(AMBIENCE)
	house.y_sort_enabled = true  # móveis ordenam pela base junto com o jogador

	var ground := _layer(house, "Ground", _tileset(tiles, T, true), -2)  # chão lógico por baixo
	var ground_hd := _layer(house, "GroundHD", _tileset(tiles_hd, HD, false), -1)  # arte HD por cima
	ground_hd.scale = Vector2.ONE * World.ART_SCALE
	var walls := _layer(house, "Walls", ground.tile_set, 0)
	for y in map.size():
		for x in map[y].length():
			var cell := Vector2i(x, y)
			if map[y][x] in SOLIDS:
				walls.set_cell(cell, SOLID, Vector2i.ZERO)
			var tile := _tile_of(map, cell)
			ground.set_cell(cell, tiles.source, Vector2i(tiles.rects[tile].position) / T)
			ground_hd.set_cell(cell, tiles_hd.source, Vector2i(tiles_hd.rects[tile].position) / HD)

	var mod := CanvasModulate.new()
	mod.name = "AtmosphereModulate"
	mod.color = Color(0.74, 0.77, 0.84, 1.0)
	_add(house, mod)
	for spec in LIGHTS:
		var pt := PointLight2D.new()
		pt.name = spec[0]
		pt.position = spec[1] * T
		pt.color = spec[2]
		pt.energy = spec[3]
		pt.texture = load(LIGHT)
		pt.texture_scale = spec[4]
		_add(house, pt)

	# Porta de saída acima do tile D; containers nos cômodos (o móvel é o container).
	var door_tile := _find(map, "D")
	var door: Node2D = load("res://scenes/props/door.tscn").instantiate()
	door.name = "ExitDoor"
	door.position = _center(door_tile) + Vector2(0, -28)
	_add(house, door)
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = _center(door_tile) + Vector2(0, -32)
	_add(house, spawn)
	var container: PackedScene = load("res://scenes/props/loot_container.tscn")
	for c in CONTAINERS:
		var box: StaticBody2D = container.instantiate()
		box.name = String(c[0]).capitalize()
		box.id = c[0]
		box.label = c[1]
		box.table = load(c[2])
		box.position = _center(c[3])
		box.color = c[4]
		box.sprite = _atlas(furniture, c[5])
		_add(house, box)

	var packed := PackedScene.new()
	packed.pack(house)
	print("save %s: %d" % [OUT, ResourceSaver.save(packed, OUT)])
	house.free()
	quit()


# Tile de arte da célula: parede de cima com face (chão logo abaixo), lateral só com o topo,
# janela, porta; no chão, uma variante sorteada pela posição.
func _tile_of(map: Array, cell: Vector2i) -> String:
	match map[cell.y][cell.x]:
		"D":
			return "door"
		"+":
			return "window"
		"#":
			var below := cell + Vector2i.DOWN
			var floor_below: bool = below.y < map.size() and not map[below.y][below.x] in SOLIDS
			return "wall_face" if floor_below else "wall_cap"
	return _variant(map[cell.y][cell.x], cell)


# Sorteio fixo por posição: o mapa sai igual a cada build.
func _variant(ch: String, cell: Vector2i) -> String:
	var r := absi(cell.x * 73856093 ^ cell.y * 19349663) % 100
	for v in FLOORS[ch]:
		r -= v[1]
		if r < 0:
			return v[0]
	return FLOORS[ch][0][0]


func _sheet(path: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var rects := {}
	for f in data.frames:
		rects[f.filename] = Rect2i(f.frame.x, f.frame.y, f.frame.w, f.frame.h)
	return {"texture": load(path.get_base_dir().path_join(data.meta.image)), "rects": rects, "source": -1}


func _atlas(sheet: Dictionary, frame: String) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = sheet.texture
	a.region = sheet.rects[frame]
	return a


# TileSet com a sheet; with_solid também põe o source 1, tile invisível com colisão para a
# camada Walls (a colisão vem do mapa, não da arte).
func _tileset(sheet: Dictionary, size: int, with_solid: bool) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(size, size)
	if with_solid:
		ts.add_physics_layer()
		var solid := TileSetAtlasSource.new()
		solid.texture = ImageTexture.create_from_image(Image.create(T, T, false, Image.FORMAT_RGBA8))
		solid.texture_region_size = Vector2i(T, T)
		ts.add_source(solid, SOLID)
		solid.create_tile(Vector2i.ZERO)
		var td := solid.get_tile_data(Vector2i.ZERO, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-H, -H), Vector2(H, -H), Vector2(H, H), Vector2(-H, H)]))
	var art := TileSetAtlasSource.new()
	art.texture = sheet.texture
	art.texture_region_size = Vector2i(size, size)
	sheet.source = ts.add_source(art)
	for r in sheet.rects.values():
		art.create_tile(Vector2i(r.position) / size)
	return ts


func _layer(scene: Node, layer_name: String, ts: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = ts
	layer.z_index = z
	_add(scene, layer)
	return layer


func _add(scene: Node, child: Node) -> void:
	scene.add_child(child)
	child.owner = scene  # dono é a raiz, para salvar


func _find(map: Array, ch: String) -> Vector2i:
	for y in map.size():
		var x: int = map[y].find(ch)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func _center(tile: Vector2i) -> Vector2:
	return Vector2(tile * T) + Vector2(H, H)
