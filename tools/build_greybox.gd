# Gera scenes/world/neighborhood_greybox.tscn a partir do mapa ASCII abaixo.
# Rodar: godot --headless --path . --script res://tools/build_greybox.gd
# ponytail: greybox descartável; quando a arte final entrar (M5), o bairro passa a ser editado no editor.
extends SceneTree

const MAP := [
	"############################################################",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-CCCC-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,VV,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,V,,,,-....-,,,V,,,,,,,,,GGGGG,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,GGGGG,,,,,,,,#",
	"#,,,,FFFFFFFFFFF,,,,,,,,,,,-....-,,,,,,,,,,,,,GGGGG,,,,,,,,#",
	"#,,,,F,,,,,,,,,F,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,F,,,,,,,,,F,,,,,,,,,,,-.C..-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,F,,,HHH,,,F,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,F,,,HHH,,,F,,,,,,,V,,,-....-,,,,,,,,,,,P,,,P,,,P,,,,,,#",
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
	"#,,,,,,,,,WWWWWW,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,WWWWWW,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,WWWWWW,,,,,,,,,,,-..C.-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,WWWWWW,,,,,,,,,,,-....-,,,,,,,VV,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,V,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,V,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-....-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,-CCCC-,,,,,,,,,,,,,,,,,,,,,,,,,,#",
	"############################################################",
]

# símbolo: [cor (paleta_afterfall.gpl), sólido]
const TILES := {
	".": [Color8(43, 43, 51), false],     # asfalto
	"-": [Color8(110, 110, 118), false],  # calçada
	",": [Color8(74, 74, 82), false],     # terreno
	"#": [Color8(26, 26, 46), true],      # limite do bairro
	"F": [Color8(92, 70, 50), true],      # cerca
	"C": [Color8(107, 58, 31), true],     # carro destruído
	"V": [Color8(63, 107, 52), true],     # vegetação
	"H": [Color8(200, 200, 196), true],   # casa
	"D": [Color8(155, 122, 84), true],    # porta da casa (entrada no M5)
	"G": [Color8(208, 138, 74), true],    # posto
	"P": [Color8(122, 46, 46), true],     # bomba de combustível
	"W": [Color8(52, 73, 94), true],      # oficina
}

const LABELS := {"CASA": Vector2i(9, 8), "POSTO": Vector2i(46, 3), "OFICINA": Vector2i(10, 21)}
const SPAWN := Vector2i(10, 14)  # calçada em frente ao portão da casa
const T := 32


func _init() -> void:
	var keys: Array = TILES.keys()
	var img := Image.create(T * keys.size(), T, false, Image.FORMAT_RGBA8)
	for i in keys.size():
		var c: Color = TILES[keys[i]][0]
		img.fill_rect(Rect2i(i * T, 0, T, T), c)
		if TILES[keys[i]][1]:  # contorno de 1 px nos sólidos, para ler o bloco
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
	var h := T / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for i in keys.size():
		src.create_tile(Vector2i(i, 0))
		if TILES[keys[i]][1]:
			var td := src.get_tile_data(Vector2i(i, 0), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)

	var scene := Node2D.new()
	scene.name = "Neighborhood"
	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = ts
	scene.add_child(layer)
	layer.owner = scene
	for y in MAP.size():
		for x in MAP[y].length():
			layer.set_cell(Vector2i(x, y), 0, Vector2i(keys.find(MAP[y][x]), 0))

	for text in LABELS:
		var l := Label.new()
		l.name = "Label" + text.capitalize()
		l.text = text
		l.position = Vector2(LABELS[text] * T) + Vector2(2, 4)
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", Color8(232, 197, 71))
		scene.add_child(l)
		l.owner = scene

	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector2(SPAWN * T) + Vector2(h, h)
	scene.add_child(spawn)
	spawn.owner = scene

	var packed := PackedScene.new()
	packed.pack(scene)
	DirAccess.make_dir_recursive_absolute("res://scenes/world")
	print("save: ", ResourceSaver.save(packed, "res://scenes/world/neighborhood_greybox.tscn"))
	print("map: ", MAP[0].length(), "x", MAP.size(), " tiles = ", MAP[0].length() * T, "x", MAP.size() * T, " px")
	scene.free()
	quit()
